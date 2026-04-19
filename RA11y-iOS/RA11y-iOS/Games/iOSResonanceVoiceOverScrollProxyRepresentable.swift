import os
import SwiftUI
import UIKit
import RA11yCore

// MARK: - UIScrollView subclass

/// Hosts the accessibility element VoiceOver should treat as the **sole** scroll surface for the lane.
/// Invokes a one-shot callback after first valid layout so programmatic focus can target this view.
private final class ResonanceVoiceOverProxyScrollView: UIScrollView {

    var onFirstReadyForAccessibilityLayout: (() -> Void)?

    private var didFireFirstLayout = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didFireFirstLayout,
              bounds.width > 0.5,
              bounds.height > 0.5,
              window != nil
        else { return }
        didFireFirstLayout = true
        onFirstReadyForAccessibilityLayout?()
    }
}

// MARK: - Coordinator

/// Bridges `UIScrollView` offset updates to SwiftUI and schedules initial VoiceOver focus on the UIKit view.
///
/// ## Concurrency
/// `scrollViewDidScroll` and layout callbacks run on the main thread; `UIAccessibility.post` and `Task`
/// for focus scheduling use `@MainActor`.
final class iOSResonanceVoiceOverScrollProxyCoordinator: NSObject, UIScrollViewDelegate {

    var onContentOffsetYChanged: (CGFloat) -> Void = { _ in }

    private weak var scrollView: UIScrollView?
    private weak var contentView: UIView?
    private var contentHeightConstraint: NSLayoutConstraint?

    private var didScheduleVoiceOverLanding = false

    func attach(scrollView: UIScrollView, contentView: UIView, heightConstraint: NSLayoutConstraint) {
        self.scrollView = scrollView
        self.contentView = contentView
        self.contentHeightConstraint = heightConstraint
    }

    func updateContentHeight(totalHeight: CGFloat, scrollView: UIScrollView) {
        guard let constraint = contentHeightConstraint else { return }
        if abs(constraint.constant - totalHeight) > 0.5 {
            constraint.constant = totalHeight
        }
        scrollView.layoutIfNeeded()
    }

    /// Called once after the scroll view has a non-empty frame in a window. Posts the same sequence as
    /// the former SwiftUI path (`screenChanged` → delay → move focus via `layoutChanged` → announcement).
    @MainActor
    func scheduleVoiceOverLandingIfNeeded() {
        guard !didScheduleVoiceOverLanding else { return }
        didScheduleVoiceOverLanding = true

        guard UIAccessibility.isVoiceOverRunning else {
            RA11yLogger.scrollInteraction.debug("UIKit proxy: skip programmatic VO focus — VoiceOver off")
            #if DEBUG
            print("[RA11yScroll] UIKit proxy: skip programmatic VO focus — VoiceOver off")
            #endif
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            UIAccessibility.post(notification: .screenChanged, argument: nil)
            RA11yLogger.scrollInteraction.debug("UIKit proxy: posted UIAccessibility.Notification.screenChanged")
            #if DEBUG
            print("[RA11yScroll] UIKit proxy: posted UIAccessibility.Notification.screenChanged")
            #endif
            try? await Task.sleep(for: .milliseconds(300))
            guard let sv = scrollView else { return }
            UIAccessibility.post(notification: .layoutChanged, argument: sv)
            RA11yLogger.scrollInteraction.debug("UIKit proxy: posted layoutChanged with UIScrollView")
            #if DEBUG
            print("[RA11yScroll] UIKit proxy: posted layoutChanged with UIScrollView")
            #endif
            let focusLine = String(localized: "dungeon.a11y.scroll.vo.focusAnnouncement")
            UIAccessibility.post(notification: .announcement, argument: focusLine)
            RA11yLogger.scrollInteraction.debug("UIKit proxy: posted VO focus announcement (length=\(focusLine.count))")
            #if DEBUG
            print("[RA11yScroll] UIKit proxy: posted VO focus announcement (length=\(focusLine.count))")
            #endif
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onContentOffsetYChanged(scrollView.contentOffset.y)
    }
}

// MARK: - UIViewRepresentable

/// Transparent `UIScrollView` VoiceOver proxy for Crystal Resonance: one accessibility element with a
/// large content size so three-finger scrolling moves `contentOffset` and drives the mirrored lane offset.
///
/// SwiftUI’s `ScrollView` delegated accessibility through the SwiftUI runtime inconsistently in swipe
/// tests; hosting UIKit preserves a first-class scroll view in the platform accessibility tree.
///
/// ## Concurrency
/// `UIViewRepresentable` updates occur on the main thread; offset callbacks are main-thread.
struct iOSResonanceVoiceOverScrollProxyRepresentable: UIViewRepresentable {

    /// Total height of scrollable content **excluding** vertical padding (matches SwiftUI `minHeight` block).
    var contentBlockHeight: CGFloat

    /// Vertical padding applied inside the scroll content (matches `padding(.vertical, RA11ySpacing.xl)`).
    var verticalPadding: CGFloat

    var accessibilityLabelText: String
    var accessibilityHintText: String

    var onContentOffsetYChanged: (CGFloat) -> Void

    func makeCoordinator() -> iOSResonanceVoiceOverScrollProxyCoordinator {
        iOSResonanceVoiceOverScrollProxyCoordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = ResonanceVoiceOverProxyScrollView()
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = context.coordinator
        scrollView.contentInsetAdjustmentBehavior = .never

        let contentView = UIView()
        contentView.backgroundColor = .clear
        contentView.isAccessibilityElement = false

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        context.coordinator.onContentOffsetYChanged = onContentOffsetYChanged

        let totalHeight = computeTotalContentHeight()
        let heightConstraint = contentView.heightAnchor.constraint(equalToConstant: totalHeight)
        context.coordinator.attach(scrollView: scrollView, contentView: contentView, heightConstraint: heightConstraint)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            heightConstraint,
        ])

        configureAccessibility(on: scrollView)

        scrollView.onFirstReadyForAccessibilityLayout = { [weak coordinator = context.coordinator] in
            coordinator?.scheduleVoiceOverLandingIfNeeded()
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onContentOffsetYChanged = onContentOffsetYChanged
        context.coordinator.updateContentHeight(totalHeight: computeTotalContentHeight(), scrollView: scrollView)
        configureAccessibility(on: scrollView)
    }

    private func computeTotalContentHeight() -> CGFloat {
        contentBlockHeight + verticalPadding * 2
    }

    private func configureAccessibility(on scrollView: UIScrollView) {
        scrollView.isAccessibilityElement = true
        scrollView.accessibilityIdentifier = "dungeon.resonance.scrollLane"
        scrollView.accessibilityLabel = accessibilityLabelText
        scrollView.accessibilityHint = accessibilityHintText
    }
}
