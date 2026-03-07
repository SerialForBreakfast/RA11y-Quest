import SwiftUI
import UIKit
import RA11yCore

// MARK: - iOSDungeonDescentView

/// The Dungeon Descent (Scroll Hunt) M7 starter implementation.
///
/// This view ships the first implementation slice from the locked M7 workflow:
/// - L0 prologue with a required practice scroll area.
/// - L1 first-attempt descent with 4 rooms and a guarded target activation.
/// - Scroll observability gate using `onScrollGeometryChange` + target-frame intersection.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSDungeonDescentView: View {

    // MARK: - State

    @State private var phase: DungeonPhase = .prologue
    @State private var practiceScrollObserved = false
    @State private var rooms: [DungeonRoom] = DungeonRoom.l1Rooms
    @State private var targetFrame: CGRect = .null
    @State private var visibleRect: CGRect = .zero
    @State private var targetIsReachable = false
    @State private var scrollSignalObserved = false
    @State private var statusMessage: String?
    @State private var mistakes = 0
    @State private var isCompleting = false
    @State private var session: GameSession?
    @State private var storage: any StorageComponent

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router

    // MARK: - Init

    /// Creates the Dungeon Descent view with a storage backend for session persistence.
    ///
    /// - Parameter storage: Persistence layer shared by the app flow.
    init(storage: any StorageComponent) {
        _storage = State(initialValue: storage)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DungeonBackgroundView()
                .ignoresSafeArea()

            switch phase {
            case .prologue:
                prologueView
                    .accessibilityIdentifier("dungeon.prologue")
                    .navigationTitle(String(localized: "dungeon.prologue.navTitle", defaultValue: "The Dungeon Descent"))
            case .firstAttempt:
                firstAttemptView
                    .accessibilityIdentifier("dungeon.play")
                    .navigationTitle(String(localized: "dungeon.l1.navTitle", defaultValue: "The Dungeon Descent"))
            }
        }
    }

    // MARK: - L0 Prologue

    private var prologueView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RA11ySpacing.base) {
                VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
                    Label(String(localized: "dm.label"), systemImage: "scroll.fill")
                        .font(.ra11ySubheadline)
                        .foregroundStyle(Color.ra11yAccent)

                    Text(String(localized: "dungeon.prologue.lessonTitle", defaultValue: "Descending the Dungeon"))
                        .font(.ra11yTitle)
                        .bold()

                    Text(
                        String(
                            localized: "dungeon.prologue.lessonBody",
                            defaultValue: "Swiping moves between items, not the page. Use three fingers to scroll."
                        )
                    )
                    .font(.ra11yBody)
                    .foregroundStyle(Color.ra11yCardSecondaryText)
                }
                .padding(RA11ySpacing.base)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))

                practiceZone

                Button(String(localized: "dungeon.prologue.begin", defaultValue: "Begin Descent")) {
                    beginFirstAttempt()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ra11yAccent)
                .disabled(!practiceScrollObserved)
                .accessibilityHint(
                    String(
                        localized: "dungeon.prologue.begin.hint",
                        defaultValue: "Enabled after you perform a practice scroll."
                    )
                )
                .accessibilityIdentifier("dungeon.beginDescent")
            }
            .padding(.horizontal, RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var practiceZone: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "dungeon.prologue.practiceTitle", defaultValue: "Practice Scroll Area"))
                .font(.ra11yHeadline)

            ScrollView {
                VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
                    ForEach(0..<12, id: \.self) { index in
                        Text("Practice step \(index + 1): keep descending.")
                        .font(.ra11yBody)
                        .foregroundStyle(Color.ra11yCardSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                }
                .padding(RA11ySpacing.base)
            }
            .frame(height: 220)
            .background(Color.black.opacity(0.35), in: .rect(cornerRadius: RA11yRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .stroke(Color.ra11yAccent.opacity(0.65), lineWidth: 1)
            )
            .accessibilityLabel(String(localized: "dungeon.prologue.practice.a11yLabel", defaultValue: "Practice scroll area"))
            .accessibilityHint(
                String(
                    localized: "dungeon.prologue.practice.a11yHint",
                    defaultValue: "Use three fingers to scroll and unlock Begin Descent."
                )
            )
            .accessibilityIdentifier("dungeon.practiceZone")
            .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
                geometry.contentOffset.y
            }, action: { _, offsetY in
                if abs(offsetY) > 2 {
                    practiceScrollObserved = true
                }
            })

            if practiceScrollObserved {
                Text(String(localized: "dungeon.prologue.practice.ready", defaultValue: "Practice detected. You may begin."))
                    .font(.ra11yCaption)
                    .foregroundStyle(Color.ra11yCardTertiaryText)
            }
        }
        .padding(RA11ySpacing.base)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
    }

    // MARK: - L1 First Attempt

    private var firstAttemptView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RA11ySpacing.base) {
                attemptHeader
                roomList
                statusPanel
            }
            .padding(.horizontal, RA11ySpacing.base)
            .padding(.vertical, RA11ySpacing.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .coordinateSpace(name: DungeonRoomCoordinateSpace.name)
        .onPreferenceChange(TargetRoomFramePreferenceKey.self) { frame in
            targetFrame = frame
            targetIsReachable = targetIsReachable(visibleRect: visibleRect, targetFrame: frame)
        }
        .onScrollGeometryChange(for: CGRect.self, of: { geometry in
            geometry.visibleRect
        }, action: { _, newVisibleRect in
            visibleRect = newVisibleRect
            targetIsReachable = targetIsReachable(visibleRect: newVisibleRect, targetFrame: targetFrame)
        })
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.y
        }, action: { _, offsetY in
            if abs(offsetY) > 2 {
                scrollSignalObserved = true
            }
        })
    }

    private var attemptHeader: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "dungeon.l1.title", defaultValue: "L1 - First Attempt"))
                .font(.ra11yTitle)
                .bold()

            Text(
                String(
                    localized: "dungeon.l1.instructions",
                    defaultValue: "Scroll to reveal the Guard Room, then double-tap to claim it."
                )
            )
            .font(.ra11yBody)
            .foregroundStyle(Color.ra11yCardSecondaryText)

            HStack {
                Label(
                    String(localized: "dungeon.l1.mistakes", defaultValue: "Mistakes: \(mistakes)"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.ra11ySubheadline)

                Spacer()

                Label(
                    scrollSignalObserved
                        ? String(localized: "dungeon.l1.scrollSignalYes", defaultValue: "Scroll signal detected")
                        : String(localized: "dungeon.l1.scrollSignalNo", defaultValue: "Awaiting scroll signal"),
                    systemImage: scrollSignalObserved ? "checkmark.circle" : "waveform.path.ecg"
                )
                .font(.ra11yCaption)
            }
            .foregroundStyle(Color.ra11yCardTertiaryText)
        }
        .padding(RA11ySpacing.base)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
    }

    private var roomList: some View {
        VStack(spacing: RA11ySpacing.sm) {
            ForEach(rooms) { room in
                DungeonRoomRow(
                    room: room,
                    isTargetReachable: targetIsReachable,
                    onActivateTarget: { Task { await activateTarget(room) } },
                    onActivateNonTarget: { Task { await activateNonTarget(room) } }
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TargetRoomFramePreferenceKey.self,
                            value: room.isTarget
                                ? proxy.frame(in: .named(DungeonRoomCoordinateSpace.name))
                                : .null
                        )
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var statusPanel: some View {
        if let statusMessage {
            Text(statusMessage)
                .font(.ra11ySubheadline)
                .foregroundStyle(Color.ra11yCardSecondaryText)
                .padding(RA11ySpacing.base)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        }
    }

    // MARK: - Actions

    private func beginFirstAttempt() {
        phase = .firstAttempt
        statusMessage = nil
        mistakes = 0
        targetIsReachable = false
        scrollSignalObserved = false

        let gameSession = GameSession(
            gameID: "scroll-hunt",
            thresholds: .scrollHunt,
            storage: storage
        )
        session = gameSession

        Task {
            do {
                try await gameSession.start()
            } catch {
                statusMessage = String(localized: "dungeon.error.start", defaultValue: "Could not start the descent session.")
            }
        }
    }

    private func activateTarget(_ room: DungeonRoom) async {
        guard room.isTarget else { return }
        guard targetIsReachable else {
            statusMessage = String(
                localized: "dungeon.target.notReachable",
                defaultValue: "The objective is still too deep. Keep scrolling down."
            )
            return
        }
        guard !isCompleting else { return }
        guard let session else { return }

        isCompleting = true
        defer { isCompleting = false }

        do {
            try await session.complete()
            if case .completed(let result) = await session.state {
                router.push(.gameResult(result, gameSpecificAnnouncement: gameSpecificAnnouncement(for: result)))
            }
        } catch {
            statusMessage = String(localized: "dungeon.error.complete", defaultValue: "Could not complete the descent.")
        }
    }

    private func activateNonTarget(_ room: DungeonRoom) async {
        guard !room.isTarget else { return }
        mistakes += 1
        statusMessage = String(localized: "dungeon.nonTarget.feedback", defaultValue: "Nothing useful here. Keep descending.")

        guard let session else { return }
        do {
            try await session.recordMistake()
        } catch {
            statusMessage = String(localized: "dungeon.error.mistake", defaultValue: "Could not record that misstep.")
        }
    }

    private func gameSpecificAnnouncement(for result: GameResult) -> String {
        switch result.rank {
        case .perfect:
            return String(localized: "dungeon.results.legendary", defaultValue: "Legendary descent. No misstep. The dungeon bows.")
        case .good:
            return String(localized: "dungeon.results.skilled", defaultValue: "Skilled explorer. The vault yielded to you.")
        case .ok:
            return String(localized: "dungeon.results.novice", defaultValue: "You found the vault. The dungeon was not kind.")
        case .failed:
            return String(localized: "dungeon.results.defeated", defaultValue: "The dungeon sealed. Rest. Then try again.")
        }
    }

    private func targetIsReachable(visibleRect: CGRect, targetFrame: CGRect) -> Bool {
        guard !targetFrame.isNull else { return false }
        return visibleRect.intersects(targetFrame)
    }
}

// MARK: - Supporting Models

/// High-level phase for the Dungeon Descent starter flow.
private enum DungeonPhase {
    case prologue
    case firstAttempt
}

/// A single room row used in the Dungeon Descent first attempt.
private struct DungeonRoom: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let assetName: String
    let isTarget: Bool

    static let l1Rooms: [DungeonRoom] = [
        DungeonRoom(
            id: "entry_hall",
            title: "Entry Hall",
            subtitle: "Torchlit. Safe.",
            assetName: "dungeon_room_entry_hall",
            isTarget: false
        ),
        DungeonRoom(
            id: "armory",
            title: "Armory",
            subtitle: "Empty racks.",
            assetName: "dungeon_room_armory",
            isTarget: false
        ),
        DungeonRoom(
            id: "guard_room",
            title: "Guard Room",
            subtitle: "Empty. The objective.",
            assetName: "dungeon_room_guard_post",
            isTarget: true
        ),
        DungeonRoom(
            id: "well_chamber",
            title: "Well Chamber",
            subtitle: "The water is still.",
            assetName: "dungeon_room_well_chamber",
            isTarget: false
        )
    ]
}

// MARK: - Row View

/// Row card representing one dungeon room.
private struct DungeonRoomRow: View {
    let room: DungeonRoom
    let isTargetReachable: Bool
    let onActivateTarget: () -> Void
    let onActivateNonTarget: () -> Void

    @ViewBuilder
    var body: some View {
        if room.isTarget {
            baseRow
                .accessibilityIdentifier("dungeon.room.\(room.id)")
                .onTapGesture { onActivateTarget() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(room.title). The objective.")
                .accessibilityHint("Double-tap to claim this room.")
                .accessibilityAction { onActivateTarget() }
                .accessibilityAddTraits(.isButton)
        } else {
            baseRow
                .accessibilityIdentifier("dungeon.room.\(room.id)")
                .onTapGesture { onActivateNonTarget() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(room.title). \(room.subtitle)")
                .accessibilityHint("Double-tap to inspect this room.")
                .accessibilityAction { onActivateNonTarget() }
        }
    }

    private var baseRow: some View {
        HStack(spacing: RA11ySpacing.base) {
            DungeonRoomIcon(assetName: room.assetName)

            VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
                Text(room.title)
                    .font(.ra11yHeadline)
                    .foregroundStyle(Color.ra11yCardSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(room.subtitle)
                    .font(.ra11ySubheadline)
                    .foregroundStyle(Color.ra11yCardTertiaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if room.isTarget {
                Image(systemName: isTargetReachable ? "checkmark.seal" : "lock.fill")
                    .foregroundStyle(isTargetReachable ? Color.green : Color.ra11yAccent)
            }
        }
        .padding(RA11ySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3), in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .stroke(Color.ra11yAccent.opacity(room.isTarget ? 0.8 : 0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Icon View

/// Asset-backed room icon with SF Symbol fallback.
private struct DungeonRoomIcon: View {
    let assetName: String

    var body: some View {
        if let image = UIImage(named: assetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.ra11yAccent)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Background View

/// The shared dungeon background image with contrast-preserving overlay.
private struct DungeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black
            if let image = UIImage(named: "dungeon_descent_bg") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.4))
            }
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.15), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Scroll Geometry Support

/// Preference key carrying the target room frame in the named scroll coordinate space.
private struct TargetRoomFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isNull {
            value = next
        }
    }
}

/// Names the coordinate space used to compare `ScrollGeometry.visibleRect` and target frames.
private enum DungeonRoomCoordinateSpace {
    static let name = "dungeonScroll"
}

#Preview("Dungeon Prologue") {
    NavigationStack {
        iOSDungeonDescentView(storage: UserDefaultsStorageComponent())
            .environment(iOSAppRouter())
    }
}
