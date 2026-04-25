import os
import SwiftUI
import UIKit
import RA11yCore

// MARK: - UIScrollView subclass

/// Hosts the accessibility element VoiceOver treats as the **sole** scroll surface for the lane.
/// Invokes a one-shot callback after first valid layout so programmatic focus can target this view.
private final class ResonanceVoiceOverProxyScrollView: UIScrollView {

    var onFirstReadyForAccessibilityLayout: (() -> Void)?

    private var didFireFirstLayout = false
    private var lastLoggedBoundsHeight: CGFloat = -1

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(bounds.height - lastLoggedBoundsHeight) > 0.5 {
            lastLoggedBoundsHeight = bounds.height
            RA11yLogger.scrollInteraction.debug(
                "UIKit proxy: layoutSubviews bounds.height=\(self.bounds.height) contentSize.height=\(self.contentSize.height)"
            )
            #if DEBUG
            print(
                "[RA11yScroll] UIKit proxy: layoutSubviews bounds.height \(String(format: "%.1f", self.bounds.height)) contentSize.height \(String(format: "%.1f", self.contentSize.height))"
            )
            #endif
        }
        guard !didFireFirstLayout,
              bounds.width > 0.5,
              bounds.height > 0.5,
              window != nil
        else { return }
        didFireFirstLayout = true
        onFirstReadyForAccessibilityLayout?()
    }

    override func accessibilityElementDidBecomeFocused() {
        super.accessibilityElementDidBecomeFocused()
        RA11yLogger.scrollInteraction.debug(
            "UIKit proxy: accessibilityElementDidBecomeFocused contentOffset.y=\(self.contentOffset.y) contentSize.height=\(self.contentSize.height) bounds.height=\(self.bounds.height)"
        )
        #if DEBUG
        print(
            "[RA11yScroll] UIKit proxy: accessibilityElementDidBecomeFocused contentOffset.y \(String(format: "%.1f", self.contentOffset.y)) contentSize.height \(String(format: "%.1f", self.contentSize.height)) bounds.height \(String(format: "%.1f", self.bounds.height))"
        )
        #endif
    }

    override func accessibilityElementDidLoseFocus() {
        super.accessibilityElementDidLoseFocus()
        RA11yLogger.scrollInteraction.debug("UIKit proxy: accessibilityElementDidLoseFocus")
        #if DEBUG
        print("[RA11yScroll] UIKit proxy: accessibilityElementDidLoseFocus")
        #endif
    }
}

// MARK: - Coordinator

/// Bridges `UIScrollView` offset updates to SwiftUI and schedules initial VoiceOver focus on the UIKit scroll view.
///
/// ## Concurrency
/// `scrollViewDidScroll` and layout callbacks run on the main thread; `UIAccessibility.post` and `Task`
/// for focus scheduling use `@MainActor`.
final class iOSResonanceVoiceOverScrollProxyCoordinator: NSObject, UIScrollViewAccessibilityDelegate {

    var onContentOffsetYChanged: (CGFloat) -> Void = { _ in }
    var accessibilityScrollStatusText: () -> String? = { nil }

    private weak var scrollView: UIScrollView?
    private weak var contentView: UIView?
    private var contentHeightConstraint: NSLayoutConstraint?

    /// When true, ``scrollViewDidScroll`` ignores callbacks — ``setContentOffset`` from SwiftUI must not
    /// mutate ``@State`` during ``UIViewRepresentable/updateUIView`` (undefined behavior + bad VoiceOver landing).
    private var isApplyingProgrammaticContentOffset = false

    private var didScheduleVoiceOverLanding = false
    private var lastLoggedScrollRange: CGFloat = -10_000

    /// One-shot DEBUG warning if scroll range is too small for reliable VoiceOver lane travel.
    private var didLogInsufficientScrollRange = false

    /// Coalesces ``updateUIView`` layout work — SwiftUI can emit many updates per frame; without this,
    /// queued `DispatchQueue.main.async` blocks apply stale `bounds`/`contentSize` pairs.
    private var deferredScrollLayoutWorkItem: DispatchWorkItem?

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
        let boundsH = scrollView.bounds.height
        let contentH = scrollView.contentSize.height
        let scrollRange = contentH - boundsH
        if abs(scrollRange - lastLoggedScrollRange) > 0.5 {
            lastLoggedScrollRange = scrollRange
            RA11yLogger.scrollInteraction.debug(
                "UIKit proxy: updateContentHeight totalHeight=\(totalHeight) contentSize.height=\(contentH) bounds.height=\(boundsH) scrollRange=\(scrollRange)"
            )
            #if DEBUG
            print(
                "[RA11yScroll] UIKit proxy: updateContentHeight totalHeight \(String(format: "%.1f", totalHeight)) contentSize.height \(String(format: "%.1f", contentH)) bounds.height \(String(format: "%.1f", boundsH)) scrollRange \(String(format: "%.1f", scrollRange))"
            )
            #endif
        }
        #if DEBUG
        if !didLogInsufficientScrollRange {
            if boundsH > 10, contentH > 0, scrollRange <= 96 {
                didLogInsufficientScrollRange = true
                RA11yLogger.scrollInteraction.warning(
                    "Resonance scroll proxy: scroll range (\(scrollRange)) is too small for reliable three-finger VoiceOver travel; contentSize.height=\(contentH), bounds.height=\(boundsH)"
                )
            }
        }
        #endif
    }

    /// Keeps the UIKit proxy aligned with the snapped SwiftUI slot selection instead of free-running on
    /// inertial scroll physics. This makes VoiceOver page scroll behave like a discrete room selector.
    func updateDesiredContentOffsetY(_ desiredOffsetY: CGFloat, scrollView: UIScrollView) {
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let clampedOffsetY = max(0, min(desiredOffsetY, maxY))
        guard abs(clampedOffsetY - scrollView.contentOffset.y) > 0.5 else { return }
        isApplyingProgrammaticContentOffset = true
        scrollView.setContentOffset(CGPoint(x: 0, y: clampedOffsetY), animated: false)
        isApplyingProgrammaticContentOffset = false
    }

    /// Called once after the scroll view has a non-empty frame in a window. Restores the original
    /// VoiceOver landing sequence so the lane is immediately ready for three-finger scroll.
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
            try? await Task.sleep(for: .milliseconds(650))
            guard let sv = scrollView else { return }
            UIAccessibility.post(notification: .screenChanged, argument: sv)
            RA11yLogger.scrollInteraction.debug("UIKit proxy: posted UIAccessibility.Notification.screenChanged with UIScrollView")
            #if DEBUG
            print("[RA11yScroll] UIKit proxy: posted UIAccessibility.Notification.screenChanged with UIScrollView")
            #endif

            try? await Task.sleep(for: .milliseconds(250))
            UIAccessibility.post(notification: .layoutChanged, argument: sv)
            RA11yLogger.scrollInteraction.debug("UIKit proxy: posted layoutChanged with UIScrollView")
            #if DEBUG
            print("[RA11yScroll] UIKit proxy: posted layoutChanged with UIScrollView")
            #endif

            /// Second `layoutChanged` after SwiftUI + UIKit finish settling—**without** this, focus often stays on
            /// chrome on iPad; users can still swipe to the lane, but auto-landing regresses. We intentionally
            /// **do not** re-add `.announcement`: that duplicated the scroll view’s label/hint and sounded like
            /// the same instruction twice.
            try? await Task.sleep(for: .milliseconds(320))
            UIAccessibility.post(notification: .layoutChanged, argument: sv)
            RA11yLogger.scrollInteraction.debug("UIKit proxy: posted follow-up layoutChanged with UIScrollView")
            #if DEBUG
            print("[RA11yScroll] UIKit proxy: posted follow-up layoutChanged with UIScrollView")
            #endif
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isApplyingProgrammaticContentOffset else { return }
        let y = scrollView.contentOffset.y
        DispatchQueue.main.async { [onContentOffsetYChanged] in
            onContentOffsetYChanged(y)
        }
    }

    func accessibilityScrollStatus(for scrollView: UIScrollView) -> String? {
        accessibilityScrollStatusText()
    }

    /// Applies scroll content height and snapped offset on the next main-queue turn with a stable `bounds` rect.
    func scheduleDeferredContentLayout(totalHeight: CGFloat, desiredOffsetY: CGFloat, scrollView: UIScrollView) {
        deferredScrollLayoutWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self, weak scrollView] in
            guard let self, let scrollView else { return }
            self.updateContentHeight(totalHeight: totalHeight, scrollView: scrollView)
            self.updateDesiredContentOffsetY(desiredOffsetY, scrollView: scrollView)
        }
        deferredScrollLayoutWorkItem = work
        DispatchQueue.main.async(execute: work)
    }
}

// MARK: - UIViewRepresentable

/// Transparent `UIScrollView` VoiceOver proxy for Crystal Resonance: **one** accessibility element (the lane)
/// with a large content size so three-finger scrolling moves `contentOffset` and drives the mirrored lane offset.
///
/// **VoiceOver three-finger scroll** is implemented by the system for focused `UIScrollView` instances; it does **not**
/// surface as a normal `UIGestureRecognizer` you can log from `UIResponder`/`touches`. Verify behavior with
/// ``scrollViewDidScroll`` / `contentOffset` (and the `[RA11yScroll]` logs from the SwiftUI bridge).
///
/// Chamber labels in ``DungeonRoom`` are not exposed here—they are decorative narrative tied to decoys and the
/// objective string in the HUD, not separate VoiceOver destinations.
///
/// SwiftUI’s `ScrollView` delegated accessibility through the SwiftUI runtime inconsistently in swipe tests;
/// hosting UIKit preserves a first-class scroll view in the platform accessibility tree.
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
    /// Spoken with the label when this scroll view is focused, and updated as the stream moves (glyph + band).
    /// Matches ``accessibilityScrollStatusText`` so linear VoiceOver navigation hears “Moonstone” / decoy names, not
    /// only during three-finger scroll status callbacks.
    var accessibilityValueText: String
    var accessibilityScrollStatusText: String?
    var desiredContentOffsetY: CGFloat

    var onContentOffsetYChanged: (CGFloat) -> Void

    func makeCoordinator() -> iOSResonanceVoiceOverScrollProxyCoordinator {
        iOSResonanceVoiceOverScrollProxyCoordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = ResonanceVoiceOverProxyScrollView()
        scrollView.backgroundColor = .clear
        scrollView.isScrollEnabled = true
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.accessibilityRespondsToUserInteraction = true
        scrollView.delegate = context.coordinator
        scrollView.contentInsetAdjustmentBehavior = .never

        let contentView = UIView()
        contentView.backgroundColor = .clear
        contentView.isAccessibilityElement = false

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        context.coordinator.onContentOffsetYChanged = onContentOffsetYChanged
        context.coordinator.accessibilityScrollStatusText = { accessibilityScrollStatusText }

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
        context.coordinator.accessibilityScrollStatusText = { accessibilityScrollStatusText }
        let totalHeight = computeTotalContentHeight()
        let desiredY = desiredContentOffsetY
        configureAccessibility(on: scrollView)
        context.coordinator.scheduleDeferredContentLayout(
            totalHeight: totalHeight,
            desiredOffsetY: desiredY,
            scrollView: scrollView
        )
    }

    private func computeTotalContentHeight() -> CGFloat {
        contentBlockHeight + verticalPadding * 2
    }

    private func configureAccessibility(on scrollView: UIScrollView) {
        scrollView.isAccessibilityElement = true
        scrollView.accessibilityIdentifier = "dungeon.resonance.scrollLane"
        scrollView.accessibilityLabel = accessibilityLabelText
        scrollView.accessibilityHint = accessibilityHintText
        scrollView.accessibilityValue = accessibilityValueText
        scrollView.accessibilityRespondsToUserInteraction = true
    }
}
