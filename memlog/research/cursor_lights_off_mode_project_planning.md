# Lights off mode project planning
_Exported on 4/20/2026 at 08:56:28 PDT from Cursor (3.1.17)_

---

**User**

You can highlight the vertical view for voiceover but the 3 finger scrolling doesn't work.  I'm not sure we're on the right track
[2026-04-19T21:34:26.037Z uptime=220885.982s] Cold start — RA11y_iOSApp.init
[2026-04-19T21:34:33.181Z uptime=220893.125s] rootView.body — first render; awaiting route resolution
[2026-04-19T21:34:33.257Z uptime=220893.201s] routeResolution — async entry (before storage reads)
[2026-04-19T21:34:33.259Z uptime=220893.203s] routeResolution complete — 1.4 ms — initial route: hub
HubViewModel.init
hubResultsLoad started — 3 games
hubResultsLoad complete — 1 stored result(s)
App is being debugged, do not track this hang
Hang detected: 4.03s (debugger attached, not reporting)
Unknown client: RA11y-iOS
Game start gating passed for scroll-hunt
Push → dungeonDescent
HubViewModel.init
alignment sample targetMidY=27.5 aimMidY=86.5 delta=59.0 reachable=false vo=true
[RA11yScroll] alignment sample targetMidY=27.5 aimMidY=86.5 delta=59.0 reachable=false vo=true
Haptic cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.warm), family: softTick
Audio cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.warm), family: resonance
ViewModel alignment band→warm reachable=false vo=true
[RA11yScroll] ViewModel band→warm reachable=false
playSurface.onAppear vo=true reducedMotion=false
[RA11yScroll] playSurface.onAppear vo=true reducedMotion=false
Failed to create 0x88 image slot (alpha=1 wide=0) (client=0xdf5569c5) [0x5 (os/kern) failure]
alignment sample targetMidY=637.5 aimMidY=661.5 delta=24.0 reachable=true vo=true
[RA11yScroll] alignment sample targetMidY=637.5 aimMidY=661.5 delta=24.0 reachable=true vo=true
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
lane scroll contentOffset.y 0.0 → -197.0 vo=true
[RA11yScroll] lane scroll contentOffset.y 0.0 → -197.0 vo=true
lane scroll contentOffset.y -197.0 → -267.0 vo=true
[RA11yScroll] lane scroll contentOffset.y -197.0 → -267.0 vo=true
App is being debugged, do not track this hang
Hang detected: 3.66s (debugger attached, not reporting)
accessibilityFocus set to scrollLane (dungeon.resonance.scrollLane)
[RA11yScroll] accessibilityFocus set to scrollLane (dungeon.resonance.scrollLane)
posted VO focus announcement (length=91)
[RA11yScroll] posted VO focus announcement (length=91)
App is being debugged, do not track this hang
Hang detected: 0.94s (debugger attached, not reporting)
App is being debugged, do not track this hang
Hang detected: 4.08s (debugger attached, not reporting)

---

**Cursor**

Investigating: logs show `contentOffset` changing with `vo=true`, so scrolling can occur—but SwiftUI's `ScrollView` often doesn't forward VoiceOver's three-finger scroll reliably. Exploring ScrollViewReader and a VoiceOver fallback (adjustable actions or nudge controls) so scrolling doesn't depend solely on three-finger gestures.



Confirming logs: `contentOffset` changes while VoiceOver is on — scrolling works, but SwiftUI’s `ScrollView` often doesn’t reliably map VoiceOver’s three-finger scroll to the underlying scroll view. Adding a first-class VoiceOver fallback: `accessibilityAdjustableAction` (one-finger swipe up/down) plus named `accessibilityAction`s that call `ScrollViewReader.scrollTo` to advance the lane by chamber.



Fixing mismatched braces and correcting `onAppear` structure.



Here is what your log line means, and what we changed.

## What the log already showed

These lines:

```text
lane scroll contentOffset.y 0.0 → -197.0 vo=true
```

mean the **lane really did scroll** (the `ScrollView`’s offset changed) while VoiceOver was on. So the failure is not “nothing scrolls,” it’s that **VoiceOver’s three-finger scroll often does not map cleanly onto SwiftUI’s `ScrollView`** in the accessibility bridge—on simulator and device—so it *feels* broken even when other code paths move the content.

Chasing “perfect” three-finger scroll on a SwiftUI `ScrollView` alone is the wrong bet for an a11y-first game.

## Direction we took: supported VoiceOver controls

We treated **`ScrollViewReader` + programmatic jumps** as the **supported** way to move the shaft with VoiceOver:

1. **`accessibilityAdjustableAction`** — With focus on **Crystal shaft scroll list**, use **one-finger swipe up / down** the way VoiceOver uses an *adjustable* control. That calls `scrollTo(_:anchor:)` to move **one chamber** toward deeper or shallower (aligned with `increment` / `decrement`).

2. **Named Actions** (VoiceOver rotor → **Actions**) — **“Scroll one chamber deeper”** and **“Scroll one chamber shallower”** — same behavior, easier if someone prefers Actions over adjustable.

3. **Stable IDs** — Each lane row has `.id(room.id)` so `scrollTo` matches the same ids as `DungeonRoom` (`entry_hall`, `guard_room`, …).

4. **Copy** — Hints and the post-focus announcement now say to use **one-finger adjust** / **Actions**, and that **three-finger may not work** on this SwiftUI surface so expectations match behavior.

You should see `[RA11yScroll]` lines like `programmatic VO shaft nudge → index …` when using adjust or Actions.

## Files touched

- `iOSDungeonResonancePlayView.swift` — `ScrollViewReader`, `nudgeCrystalShaftForVoiceOver`, adjustable + custom actions, `.id(room.id)`, brace/layout fix for `GeometryReader` / `ZStack`.
- `Localizable.xcstrings` — new action names + updated hint / focus announcement.

**Build:** `RA11y-iOS` builds successfully.

If you want to go further later, a **UIKit `UIScrollView`** wrapper for the lane is the nuclear option for OS three-finger scroll—but for RA11y, **adjustable + Actions** is the dependable, standards-aligned path.

---

**User**

I don't want to introduce rotor actions yet this early into the flow.  

---

**Cursor**

Removing VoiceOver custom Actions (rotor) while keeping the one-finger adjustable control and updating copy that references the Actions menu.



---

**User**

1 So swiftUI is the limiting agent right now?  
2 we are seeing the accessibillity feature work right with that console output right?  
3 Why not use the UIKit solution is that not a good idea for some reason?
4 What about this consideration? 
"# Crystal Resonance: VoiceOver Focus & Copy Fix

## Context

The player reports: "The 3-finger swiping isn't doing anything. When you tap it says First Attempt. You aren't in the scroll area for the 3-finger swipe to work."

Three-finger scroll only works in VoiceOver when a `ScrollView` has focus. The current implementation tries to route focus to the scroll lane with a 1.3 s `Task.sleep` hack in `iOSDungeonResonancePlayView.onAppear`. This fails because:

1. **Navigation title wins.** The NavigationStack title "First Attempt" is the first accessible element VoiceOver lands on after the push transition. The 1.3 s delay expires while VoiceOver is still on the nav bar (or mid-announcement from `announceObjectivePrompt()`), so the `@AccessibilityFocusState` assignment is silently dropped.
2. **Copy is misaligned.** All localization strings still reference the old Scroll Hunt room-list metaphor ("Crystal shaft scroll list", "Guard Room", "Descend to…"). The Crystal Resonance mechanic is about *aligning the Moonstone with the orb*, not descending through chambers.

The **design approach** (fixed orb + scrollable lane + VoiceOver focus on a `ScrollView` → three-finger scroll) is **architecturally correct** and must be preserved. Only the focus routing and copy need to change.

---

## Critical Files

| File | Role |
|------|------|
| `RA11y-iOS/RA11y-iOS/Games/iOSDungeonResonancePlayView.swift` | Fix focus routing; add `.accessibilitySortPriority(10)` to ScrollView; replace 1.3 s hack |
| `RA11y-iOS/RA11y-iOS/Localizable.xcstrings` | Update scroll container label/hint + all `dungeon.a11y.*` strings to Crystal Resonance language |

`iOSDungeonDescentView.swift` and the ViewModel do **not** need structural changes.

---

## Implementation Plan

### Step 1 — Give the ScrollView natural priority in VoiceOver order

Add `.accessibilitySortPriority(10)` to the `ScrollView` in `iOSDungeonResonancePlayView`. SwiftUI's default sort priority is `0`; a positive value makes this element come before the `safeAreaInset` chrome elements (objective card, gesture tips, timer) in the VoiceOver swipe order.

```swift
ScrollView(.vertical) {
    resonanceLaneColumn
        .padding(.vertical, RA11ySpacing.xl)
}
.scrollIndicators(.visible)
// ... existing modifiers …
.accessibilitySortPriority(10)   // ← ADD: surfaces scroll lane before top chrome
```

After this change, a player swiping right from the navigation title will land directly on the scroll lane — no programmatic intervention needed.

### Step 2 — Replace the 1.3 s timing hack with `.screenChanged`

Remove the `onAppear` `Task` that sleeps 1 300 ms and then assigns `accessibilityFocusScrollLane`.
Replace it with a two-phase approach that:
1. Posts `.screenChanged` (resets VoiceOver traversal to the first accessible element — now the scroll lane due to Step 1)
2. Assigns the `@AccessibilityFocusState` binding 300 ms later as a fallback for the case where the sort priority alone doesn't win

```swift
.onAppear {
    logResonanceScroll("playSurface.onAppear vo=\(UIAccessibility.isVoiceOverRunning) reducedMotion=\(UIAccessibility.isReduceMotionEnabled)")
    guard UIAccessibility.isVoiceOverRunning else {
        logResonanceScroll("skip programmatic VO focus — VoiceOver off")
        return
    }
    Task { @MainActor in
        // Allow the NavigationStack push animation to settle, then
        // tell VoiceOver the screen has changed so it refocuses from
        // the top (which is now the scroll lane due to sort priority).
        try? await Task.sleep(for: .milliseconds(500))
        UIAccessibility.post(notification: .screenChanged, argument: nil)
        logResonanceScroll("posted .screenChanged to reset VO traversal")
        // Bind as backup in case screenChanged alone doesn't move focus.
        try? await Task.sleep(for: .milliseconds(300))
        accessibilityFocusScrollLane = .scrollLane
        logResonanceScroll("accessibilityFocus set to scrollLane (backup binding)")
        UIAccessibility.post(
            notification: .announcement,
            argument: String(localized: "dungeon.a11y.scroll.vo.focusAnnouncement")
        )
    }
}
```

> **Note:** Remove the `guard UIAccessibility.isVoiceOverRunning else { return }` that was *inside* the old Task (it was in the right place but the structure is now cleaner by guarding at the top of `onAppear`).

### Step 3 — Update localization strings to Crystal Resonance language

All of the strings below are in `RA11y-iOS/RA11y-iOS/Localizable.xcstrings`. Update only the `"value"` field of the `"en"` entry for each key.

| Key | Current (Scroll Hunt language) | New (Crystal Resonance language) |
|-----|-------------------------------|----------------------------------|
| `dungeon.a11y.scroll.container` | "Crystal shaft scroll list" | "Moonstone alignment lane" |
| `dungeon.a11y.scroll.container.hint` | "Main scrolling area for this ascent. Three-finger swipes move the lane only while VoiceOver is focused here—not on the navigation title or buttons." | "Scroll lane for this chamber. Three-finger swipes move the lane only while VoiceOver is focused here. Scroll to align the Moonstone with the orb at the center of the screen." |
| `dungeon.a11y.scroll.vo.focusAnnouncement` | "Crystal shaft scroll list is focused. Swipe with three fingers up or down to move the lane." | "Moonstone alignment lane is focused. Swipe with three fingers up or down to scroll the Moonstone toward the orb." |
| `dungeon.a11y.l1.objective.format` | "Objective: Descend to %@. Move VoiceOver to Crystal shaft scroll list (below the heading). Three-finger swipes work only while that item has focus." | "Objective: Align the %@ with the orb. VoiceOver is focused on the Moonstone alignment lane. Use three fingers to scroll up or down until you feel the lock." |
| `dungeon.a11y.l1.objective.hint` | "One-finger swipes move VoiceOver focus only. Focus Crystal shaft scroll list, then three-finger swipe up or down on it." | "Three-finger swipes move the lane. If focus moves away, swipe back to Moonstone alignment lane, then try again." |
| `dungeon.a11y.l2.objective.format` | "Objective: Descend to %@. Three-finger swipes work when Crystal shaft scroll list is focused." | "Objective: Align the %@ with the orb. Keep VoiceOver on Moonstone alignment lane and three-finger scroll to align." |
| `dungeon.a11y.l3.objective.format` | "Objective: Descend to %@. Act quickly. Keep VoiceOver on Crystal shaft scroll list to scroll with three fingers." | "Objective: Align the %@ with the orb. Act quickly. Keep VoiceOver on Moonstone alignment lane and three-finger scroll." |
| `dungeon.explain.gesture.swipe3` | "Three-finger swipe up — descend (scroll down)" | "Three-finger swipe — scroll the lane (move Moonstone)" |
| `dungeon.explain.gesture.swipe3u` | "Three-finger swipe down — ascend (scroll up)" | "Seal button appears when Moonstone aligns with the orb" |

> `dungeon.explain.gesture.swipe1` ("One-finger swipe — move between chamber markers") is **not shown** in Crystal Resonance (`firstLevelGestureTipCard` only renders `swipe3` and `swipe3u`), so no change needed there. The old `dungeon.a11y.l1.objective` (non-format variant) appears stale — leave as-is unless it causes a compile warning.

---

## What Stays the Same

- **Design approach**: `ScrollView` + `@AccessibilityFocusState` + `accessibilityRespondsToUserInteraction(true)` — all correct, keep as-is
- **Lane accessibility structure**: `resonanceLaneColumn` with `.accessibilityElement(children: .ignore)` — correct, prevents lane objects from stealing focus
- **Orb/reticle**: `accessibilityHidden(true)` — correct, decorative only
- **Seal button** appearance logic: `targetIsReachable` drive — no change
- **`announceObjectivePrompt()`** in `iOSDungeonDescentView` — keep; fires at 500 ms and is compatible with the new 500 ms `screenChanged` post (they may overlap slightly but both announcements are additive)
- All ViewModel logic, haptics, geometry tracking — no change

---

## Verification

1. **VoiceOver on, navigate into Crystal Resonance (L1):** After the push transition, VoiceOver should announce "Moonstone alignment lane" within ~1 s without the player swiping at all.
2. **Three-finger swipe immediately after:** Should move the lane. Verify in the Xcode console that `[RA11yScroll]` logs show `contentOffset.y` changing and `vo=true`.
3. **Player swipes right from nav title:** First stop should be "Moonstone alignment lane" (due to sort priority), not the objective card.
4. **Player swipes right from scroll lane:** Should reach the Seal button (when visible) or Hint button in bottom chrome.
5. **VoiceOver off:** `onAppear` guard exits early — no announcements, no focus assignment — no regression for non-VO play.
6. **Seal button appears:** When Moonstone aligns with orb, Seal button appears at bottom; player can swipe to it and double-tap to activate."

---

**Cursor**

Answering your four points briefly, then implementing the spec: `accessibilitySortPriority`, replacing the timing hack with `screenChanged` + short fallback delay, and updating localization strings.



Implementing the plan: answering 1–3 in prose, then applying code and localization updates.



## 1. Is SwiftUI the limiting piece?

**Mostly, yes** — for **VoiceOver + three-finger scroll**, the weak link is usually how **SwiftUI’s `ScrollView`** is bridged to the accessibility/scroll system, not your game logic. Your logs already showed **`contentOffset` changing** (`lane scroll contentOffset.y …`), so layout and tracking are fine; the problem is whether **VO’s three-finger gesture** is consistently bound to that scroll view.

## 2. Does the console output mean accessibility is “working”?

**Partly.** Lines like **`alignment sample … vo=true`**, **`lane scroll contentOffset.y …`**, and **`ViewModel band→…`** mean:

- VoiceOver is **on**
- Geometry / reachability / feedback are **updating**
- The **scroll view’s offset can change** (from any scroll path: finger, focus, etc.)

So **something** in the a11y + scroll pipeline is alive. It does **not** prove three-finger scroll always maps correctly — only that **scroll + VO state** can be observed together.

## 3. Why not UIKit (`UIScrollView`)?

**It’s a reasonable trade**, not a mistake:

- **Pros:** Often **more predictable** VoiceOver + scroll behavior; closer to what Apple documents for scrollable regions.
- **Cons:** **`UIViewRepresentable`**, syncing content with SwiftUI state, safe area / materials / blackout overlays, and **ongoing maintenance** between two UI idioms.

So: **good idea if three-finger on SwiftUI stays unacceptable in testing**; **not required** if sort priority + `screenChanged` + focus + your **adjustable fallback** are enough.

---

## 4. Your design note — implemented

Your spec is **applied** as follows:

| Piece | Change |
|--------|--------|
| **Swipe order** | `.accessibilitySortPriority(10)` on the lane **`ScrollView`** (chrome stays default ~0). |
| **Focus hack** | Replaced **1.3 s sleep-only** with **500 ms** → **`UIAccessibility.post(.screenChanged, …)`** → **300 ms** → **`accessibilityFocusScrollLane = .scrollLane`** → **announcement** string. |
| **`onAppear`** | **`guard UIAccessibility.isVoiceOverRunning`** at **start** of `onAppear` (after initializing `voiceOverLaneRoomIndex`); Task only runs when VO is on. |
| **Copy** | Updated **`dungeon.a11y.*`** scroll + L1/L2/L3 objective strings and **`dungeon.explain.gesture.swipe3` / `swipe3u`** per your table; **`dungeon.a11y.l1.objective`** (announce) aligned to the same **Moonstone / orb** framing. |

**Still there (per earlier product decision):** `accessibilityAdjustableAction` + **`ScrollViewReader`** nudges as a **fallback** when SwiftUI still doesn’t take three-finger scroll — noted in the type’s doc comment.

Build **RA11y-iOS** succeeds after these edits.

**Caveat:** `accessibilitySortPriority` affects **sorting among sibling elements**; with **`safeAreaInset`**, the real VO order can still vary by OS. Treat **sort priority + `screenChanged` + backup focus** as **best-effort**; validate on a **device** with VoiceOver.

**Note:** The second L1 tip line (`swipe3u`) is now **about the Seal button** per your spec — it’s accurate but **no longer a paired “opposite direction”** gesture to the first line; if that feels odd in UI, we can split into a third line later.

---

**User**

It still isn't working.  3 finger swiping was working in the practice area we had previously.  Why doesn't that translate to our Game?

---

**Cursor**

Comparing the prologue practice scroll implementation with the Crystal Resonance play view to identify structural differences.



Tracing differences: the prologue practice zone uses a plain, nested `ScrollView` with minimal accessibility modifiers. The game attaches `accessibilityAdjustableAction` to the same `ScrollView`, which can make VoiceOver treat it as an adjustable control (one-finger increment/decrement) and conflict with three-finger scrolling. Removing the adjustable action from the scroll surface and simplifying the scroll view’s accessibility profile to match the practice zone; keeping `ScrollViewReader` only if we add a non-rotor fallback (e.g. small optional controls). Checking the file and applying the fix.



Removing `accessibilityAdjustableAction` from the gameplay `ScrollView` — it makes VoiceOver treat the view as an adjustable control, which hijacks vertical gestures and conflicts with three-finger scrolling. The prologue practice zone is a plain `ScrollView` with only label/hint and geometry observation. Removing the adjustable action, `ScrollViewReader`, and nudge plumbing so the game scroll surface matches that simpler profile.



## Why practice “worked” but the game didn’t

**L0 practice** (`DungeonPrologueView` → `practiceZone`) uses a **very small, simple `ScrollView`**: text lines, fixed height, `.accessibilityLabel` / `.accessibilityHint`, and **`onScrollGeometryChange`** only. No `ScrollViewReader`, no `accessibilityAdjustableAction`, no focus tricks beyond whatever the system does.

**Crystal Resonance gameplay** added **`accessibilityAdjustableAction`** on the **same** `ScrollView` you want to three-finger scroll. On that control, VoiceOver treats the element as **adjustable**: vertical one-finger swipes are meant to **increment/decrement**, not to scroll. That **fights** the scroll trait and is the main reason it **doesn’t behave like the practice box**—practice never marked the scroll surface as adjustable.

Other differences (full-screen **ZStack**, center orb overlay, `safeAreaInset` chrome, flattened lane with **`accessibilityElement(children: .ignore)`**, programmatic **focus** / **`screenChanged`**) can change feel and focus, but the **adjustable-vs-scroll conflict** on one element is the big behavioral mismatch with L0.

## What we changed in code

We **removed** from the lane `ScrollView`:

- **`accessibilityAdjustableAction`** (and the **`ScrollViewReader`** / chamber nudge path that only existed to support it)
- **`accessibilityRespondsToUserInteraction`** (practice doesn’t use it; keeps parity with the working pattern)

So the lane scroll surface is **much closer to the practice `ScrollView` profile** while keeping **sort priority**, **focus**, and **`screenChanged`** as-is.

Build **succeeds**.

---

**If three-finger is still weak after this:** the next lever is **UIKit `UIScrollView`** for the lane (same UX, more reliable VO scroll), or a **dedicated** small nudge control that does **not** share the scroll view’s accessibility element (so we never attach adjustable to the scroller again).

---

**User**

It still didn't work.  What if we had a simple invisible view that the accesibility system can interact with that we know works from the practice attempts, and use those scrolls to influence the more complex UI elements hidden beneath it?

---

**Cursor**

Implementing a VoiceOver-only proxy `ScrollView` (practice-style, minimal accessibility) that drives the lane via clipped offset, and keeping the normal `ScrollView` for non–VoiceOver users.



Implementing a VoiceOver-only, practice-style transparent `ScrollView` overlay that receives three-finger scrolling, while the visible lane is offset to match. Using `@Environment(\.accessibilityVoiceOverEnabled)` so layout switches when VoiceOver is on.



Here’s what we implemented and why it addresses the “practice works, game doesn’t” gap.

## Idea

**L0 practice** is a **small, plain `ScrollView`** with simple content and almost no extra accessibility API — that’s the pattern VoiceOver’s **three-finger scroll** attaches to reliably.

**Crystal Resonance** was one **heavy `ScrollView`** (ZStack, orb, flattened lane, focus, sort priority, etc.), which doesn’t behave the same in the accessibility tree.

So we **split**:

1. **VoiceOver on** (`@Environment(\.accessibilityVoiceOverEnabled)`):
   - **Underneath:** the real lane (moonstone + decoys) is **not** scrolled by UIKit/SwiftUI; it only **moves** with `.offset(y: -proxyOffset)`. It uses **`allowsHitTesting(false)`** and **`accessibilityHidden(true)`** so VO never tries to scroll “the art,” only the proxy.
   - **On top:** a **full-screen, clear, practice-style `ScrollView`** (stack of `Color.clear` rows, same idea as the prologue practice list). Only this view gets **`dungeon.resonance.scrollLane`** + label/hint + focus.
   - **`onScrollGeometryChange`** on the proxy sets `voiceOverProxyScrollOffsetY`, which drives the offset of the visual lane so alignment math stays consistent.

2. **VoiceOver off:** unchanged — a normal **`ScrollView`** for the lane (no proxy, no offset state).

## What you should see in logs

When VO is on and you three-finger scroll, look for:

`VO proxy scroll contentOffset.y …`

That confirms the **proxy** is scrolling; the lane should move with it. If that appears but the art doesn’t line up, we’d tune **proxy content height** vs. real lane height (they’re approximated from `rooms` today).

## Tradeoffs

- **Synchronization:** Proxy scroll extent is an **estimate** (`max(rooms.count * 2, 18)` × 44pt + padding). If it feels “short” or “long” vs. the visible lane, we should tie this to the **same** layout metrics as `resonanceLaneColumn`.
- **`accessibilityVoiceOverEnabled`:** Matches **`iOSHubView`**. If you need the proxy whenever `UIAccessibility.isVoiceOverRunning` is true and the environment lags, we can align the branch with runtime VO as a follow-up.

Build **RA11y-iOS** succeeds with this change.

---

**User**

You can never enter a quest without VO enabled.  There is no point.  I want this explicitly disabled from occuring.  We don't need to maintain two flows either for simplicity.

---

**Cursor**

Searching for quest entry points and existing VoiceOver gating so we can enforce VO-only entry and remove the dual gameplay path.



Adding centralized `pushGame(kind:)` on the router (using `GameStartDecision` + `UIAccessibility`), wiring all entry/restart paths through it, and collapsing `iOSDungeonResonancePlayView` to the VoiceOver proxy path only.



Here is what changed.

## 1. Single gate: `iOSAppRouter.pushGame(kind:provider:)`

All normal paths into the three MVP games now go through **`GameStartDecision`** and **`VoiceOverStateProvider`** (default **`iOSLiveVoiceOverStateProvider`**, i.e. **`UIAccessibility.isVoiceOverRunning`**):

- If VoiceOver **is** running → push **`.enchantersTrial` / `.roguesGauntlet` / `.dungeonDescent`**
- If **not** → push **`.voiceOverInterstitial(kind:)`** (same as before from the hub, but enforced everywhere)

**Wired to `pushGame`:**

- **`iOSHubView.startGame`** — removed the duplicate `voiceOverEnabled` branch; only unlock + `router.pushGame(kind:)`.
- **`iOSBasicsSequenceView.launchCurrentGame`** — `router.pushGame(kind: steps[currentIndex])` (removed `gameRoute(for:)`).
- **`iOSRootView`** — **`restartGame(for:)`** maps **`GameResult.gameID`** → **`GameKind`** and calls **`pushGame`** (no more direct game pushes after “Try again”).
- **DEBUG UI-testing** screenshot shortcuts (`-screenshotDirectTo*`) — use **`pushGame`** so they follow the same rule (with VO off you’ll get the interstitial unless the simulator session has VoiceOver on).

**Manual `push(.enchantersTrial)` etc. should not be used for entering quests** — only **`pushGame`** or **`push(.voiceOverInterstitial)`** as documented on the router.

## 2. Crystal Resonance: one lane implementation

**`iOSDungeonResonancePlayView`** no longer branches on **`accessibilityVoiceOverEnabled`**. It always uses the **visual lane + offset** and the **practice-style proxy `ScrollView`**. **`@Environment(\.accessibilityVoiceOverEnabled)`** and the **`onChange` that cleared offset** were removed.

Quest entry is already gated, so this surface is only reached with VoiceOver on in normal play; **`onAppear`** still guards focus work when VO is off (e.g. SwiftUI previews).

## Build

**`xcodebuild` for RA11y-iOS completed successfully** after these edits.

**Note:** Fastlane / `-screenshotDirectToDungeon` (and similar) now need **VoiceOver enabled** in that run if you want the game screen instead of the VO interstitial.

---

**User**

The UI tests need to be able to run without VO Enabled.  These rules are for user interactions, where we are requireming the user to learn to use VO.  This shouldn't impact UI Testing.

---

**Cursor**

Allowing game routes during UI tests by bypassing VoiceOver gating when the UI-testing launch argument is present. Searching the codebase for how UI testing is detected:



Bypassing VoiceOver gating in `pushGame` when `-uiTesting` is present (matching the project's existing UI-test/snapshot conventions).



Here’s where things stand:

### Done
- **`pushGame` in `iOSAppRouter`** treats **`ProcessInfo.processInfo.arguments` containing `-uiTesting`** as automation: it **does not** show the VoiceOver interstitial and goes straight to the playable route via `pushPlayableRoute(for:)`. Real launches keep **`GameStartDecision`** + interstitial when VO is off.
- **RA11y-iOS build** (`xcodebuild` for `RA11y-iOS`, generic iOS Simulator) **completed with exit code 0**.
- **No linter issues** on `iOSAppRouter.swift`.

### For your UITests
- `RA11y_iOSUITests.swift` and screenshot tests already use **`-uiTesting`** in `launchArguments`, so they align with this bypass.

If you add a new test that **navigates to a game from the hub (or any path that calls `pushGame`)** without launching with `-uiTesting`, it would still hit the interstitial — add **`-uiTesting`** there too.

---

**User**

The 3 finger swipe still doesn't work.  Are the missing instructions to find the correct proxy view?

---

**Cursor**

Tracing how the three-finger swipe and proxy scroll views are implemented and documented in the app.



Identifying the issue: VoiceOver's three-finger scroll scrolls the scrollable region associated with the focused element—if focus is on the objective/timer (top chrome), three-finger swipes won't move the lane. Checking chrome vs. playfield ordering and strengthening on-screen + hint copy.



Confirming: iOS only scrolls the scrollable view whose accessibility element has focus (or contains the focused element). The container hint already says three-finger swipes work "only while VoiceOver is focused here," but the visible gesture lines don't—and ADR-0003's "focus on tutorial" conflicts with that. Adding explicit visible copy and lowering chrome accessibility sort priority so the lane surfaces earlier in swipe order.



Updating the L1 tip, clarifying the gesture line, strengthening the scroll container hint, and applying negative `accessibilitySortPriority` to chrome so the proxy lane is easier to reach in swipe order.



Restoring the shorter `dungeon.explain.gesture.swipe3` for the L0 prologue gesture rows; resonance-specific guidance lives in the new tip line.



Here is what was going wrong and what we changed.

### Why it felt “broken”
On iOS, **three-finger scroll is tied to VoiceOver focus**. It scrolls the **scrollable control that owns the focused accessibility element** (or the focused element itself when it is that control). Your **proxy** is the full-screen `ScrollView` labeled **Moonstone alignment lane** (`dungeon.resonance.scrollLane`). If focus is on the **objective / timer / status** in the top inset, a three-finger swipe usually **does not** move that invisible lane.

So it was not mainly “missing code”—it was **missing or easy-to-miss guidance** that players must be on **that** element, not on chrome. The **hint** on the scroll container already said that; the **visible** L1 tip did not spell out how to recover.

### What we changed
1. **`dungeon.a11y.scroll.container.hint`** — Clarifies that this is the invisible layer behind the lane, that chrome is different, and that you should **swipe until you hear “Moonstone alignment lane”** before three-finger scrolling.
2. **New `dungeon.resonance.tip.voFocusOnLane`** — Shown on the L1 gesture tip card: if nothing moves, **move VO until it reads Moonstone alignment lane**, then try three fingers again.
3. **`iOSDungeonResonancePlayView`** — Doc comment explaining focus vs. three-finger scroll, and **`.accessibilitySortPriority(-5)`** on top and bottom chrome so the **lane proxy (`10`)** is less likely to lose swipe order to inset content when the system merges trees.
4. Build **succeeds** for `RA11y-iOS`.

### Quick check when testing
- **Device:** Three fingers, decisive motion; VO should announce **Moonstone alignment lane** (or your focus announcement) before you rely on scrolling.
- **Simulator:** Three-finger simulation is often awkward; if the proxy works on device but not in Sim, it may be the environment, not your layout.

If you want, we can next add a **one-line rotor hint** (e.g. “Containers”) only in the help sheet or as a short second string—kept separate so we do not overload the lane hint.

---

**User**

This still doesn't work.  There isn't any moonstone aligment lane when swiping from view to view.  After the instructions swiping right finds a small rectancle view in the middle of the bottom of the screen, but doesn't announce anything or respond to 3 finger scrolls.  

hubResultsLoad started — 3 games
App is being debugged, do not track this hang
Hang detected: 3.43s (debugger attached, not reporting)
hubResultsLoad complete — 1 stored result(s)
Unknown client: RA11y-iOS
Game start gating passed for scrollHunt
Push → dungeonDescent
HubViewModel.init
alignment sample targetMidY=109.1 aimMidY=127.3 delta=18.2 reachable=true vo=true
[RA11yScroll] alignment sample targetMidY=109.1 aimMidY=127.3 delta=18.2 reachable=true vo=true
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
playSurface.onAppear vo=true reducedMotion=false
[RA11yScroll] playSurface.onAppear vo=true reducedMotion=false
Failed to create 0x88 image slot (alpha=1 wide=0) (client=0xff4f0f37) [0x5 (os/kern) failure]
alignment sample targetMidY=719.1 aimMidY=673.5 delta=45.5 reachable=false vo=true
[RA11yScroll] alignment sample targetMidY=719.1 aimMidY=673.5 delta=45.5 reachable=false vo=true
Haptic cue rendered — intent: lockLost, family: softTick
Audio cue rendered — intent: lockLost, family: warningPulse
Haptic cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.near), family: proximityPulse
Audio cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.near), family: resonance
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
VO proxy scroll contentOffset.y 0.0 → -278.5
[RA11yScroll] VO proxy scroll contentOffset.y 0.0 → -278.5
ViewModel alignment band→far reachable=false vo=true
[RA11yScroll] ViewModel band→far reachable=false
VO proxy scroll contentOffset.y -278.5 → -348.5
[RA11yScroll] VO proxy scroll contentOffset.y -278.5 → -348.5
App is being debugged, do not track this hang
Hang detected: 3.14s (debugger attached, not reporting)
posted UIAccessibility.Notification.screenChanged to reset VO traversal
[RA11yScroll] posted UIAccessibility.Notification.screenChanged to reset VO traversal
accessibilityFocus set to scrollLane (dungeon.resonance.scrollLane) backup binding
[RA11yScroll] accessibilityFocus set to scrollLane (dungeon.resonance.scrollLane) backup binding
posted VO focus announcement (length=112)
[RA11yScroll] posted VO focus announcement (length=112

---

**Cursor**

Tracing the dungeon gameplay view hierarchy and VoiceOver attributes to find the silent bottom rectangle and why the scroll lane isn't in the rotor.



Identifying the issue: when the seal button isn't shown and there's no hint, `sealOrProgressControls` still builds an empty `VStack`, which can produce an unnamed, focusable accessibility element (matches a small silent rectangle at the bottom). Removing the outer `GeometryReader` that can introduce extra accessibility nodes, and collapsing the ScrollView's accessibility representation.



Fixing an empty `VStack` in the bottom chrome (common when the seal isn't available and there's no hint on L1) that can create a nameless VoiceOver focus target, and removing the root `GeometryReader` that can register as an extra accessibility node. Applying the overlay + preference pattern for the aim line and tightening ScrollView accessibility.



Recomputing alignment when either the aim line or target preference updates (target may fire before aim on first layout).



Here’s what was going wrong and what we changed.

### Root causes (not “missing instructions” only)

1. **Unnamed bottom rectangle**  
   On L1, when the moonstone is **not** aligned, **`onHint` is nil**, so there is **no seal** and **no hint**.  
   `sealOrProgressControls` still built an **`VStack { }` with no children**, and `bottomChrome` always wrapped that in padded material. VoiceOver can focus that as a **blank, non-labeled control** — consistent with “small rectangle at the bottom middle” that **does not speak** and **does not scroll**.

2. **Root `GeometryReader`**  
   Wrapping the whole playfield in `GeometryReader { … ZStack }` is a known SwiftUI pattern that often adds an **extra accessibility frame** in the swipe order. That can sit between chrome and the scroll proxy and behave like a mystery target.

3. **Scroll proxy not a single AX element**  
   Extra `.accessibilityElement(children: .ignore)` on the scroll content (and the `ScrollView`) reduces the chance that inner placeholders show up as separate focus targets.

### Code fixes (in `iOSDungeonResonancePlayView.swift`)

- **`hasPlayfieldBottomControls`**: only add the bottom safe-area inset when there is something to show (continue, seal, or hint). **No empty bottom bar** during most of L1.  
- **`ResonanceAimLineGlobalMidYPreferenceKey` + overlay `GeometryReader`**: measure aim-line `midY` from a **hit-invisible, `accessibilityHidden` overlay** instead of a root `GeometryReader`.  
- **`applyResonanceAlignmentFromLastFrames()`**: preferences can arrive in **either** order; alignment updates when **either** aim or target updates.  
- **ScrollView**: `.accessibilityElement(children: .ignore)` on the scroll view and inner `VStack` so the **Moonstone alignment lane** stays **one** VoiceOver element with your label/hint.

Your logs already showed **`VO proxy scroll contentOffset`** changing and the **focus announcement posting** — the scroll machinery was fine; focus was likely landing on the **bogus bottom inset** or the **reader frame** instead of `dungeon.resonance.scrollLane`.

Build **succeeds** after these edits.

**Note:** `Failed to create 0x88 image slot … wide=0` is a separate Core Animation / asset sizing warning (often a **zero-width** layer). If it persists, we can trace which view still reports zero width; it’s probably not the main VO issue.

After a rebuild, run through L1 again: when the seal row is empty, the **bottom material bar should disappear**, and swiping should reach **Moonstone alignment lane** with the usual label. If anything still mis-focuses, say whether you’re on **device or Simulator** (Simulator’s 3-finger simulation is unreliable compared to device).

---

**User**

right swiping from the instructions you can't get to the moonstone alignment lane.  This is getting worse.  Lets capture what we know about what we've tried into a document for posterity. Then we will just implement the UI kit version.

---

**Cursor**

Creating a posterity document summarizing the VoiceOver scroll-proxy investigation and attempted fixes. Checking the repo's memlog conventions and the current implementation for accuracy.



Here’s what was added for posterity.

### New document
**[`memlog/research/CrystalResonance-VoiceOverScrollProxy-Investigation.md`](memlog/research/CrystalResonance-VoiceOverScrollProxy-Investigation.md)**

It captures:

- **Problem:** VO swipe order never reliably reaches **Moonstone alignment lane** after instructions; unnamed rects; three-finger scroll depends on focus.
- **Current SwiftUI design:** Transparent full-screen proxy `ScrollView`, mirrored lane offset, `safeAreaInset` chrome, aim line via overlay preference key (no root `GeometryReader`).
- **What we tried:** Copy/hints, `accessibilitySortPriority`, `@AccessibilityFocusState` + `screenChanged` + announcement, collapsing the scroll AX tree, overlay aim measurement + preference ordering, removing empty bottom inset, `-uiTesting` on `pushGame` (automation only).
- **Evidence:** Logs where proxy offset changes vs. focus still wrong; optional note on `wide=0` image warnings.
- **Hypothesis:** SwiftUI + insets + navigation makes linear VO traversal unreliable for this scroll proxy.
- **Next step:** **`UIScrollView` via UIKit interop** with explicit accessibility on the scroll view.
- **Pointers:** Main source file, router, relevant `Localizable` keys.

### Also updated
- **`memlog/DirectoryTree.txt`** — lists the new file under `memlog/research/`.
- **`memlog/research/ADR-0003-Dungeon-Resonance-Scroll-Interaction.md`** — short **Related engineering notes** section linking to this investigation.

When you implement the UIKit scroll surface, add a short “Revision history” row and file names to that investigation doc so the story stays complete.

---

**User**

Proceeed with the UI kit interop version of this game, otherwise we need to come up with another approach.

---

**Cursor**

Implementing a `UIScrollView`-based VoiceOver scroll proxy via `UIViewRepresentable` and integrating it into `iOSDungeonResonancePlayView`.



Creating the UIKit scroll proxy representable and wiring it into the play view. Updating the investigation doc and DirectoryTree.



Fixing the coordinator: replacing incorrect static storage with instance properties and correcting the VoiceOver scheduling guard.



Fixing content height: `voiceOverProxyScrollableContentHeight` is the inner block (rows + 2·xl); representable adds vertical padding again.



Making the coordinator internal (not `private`) so `UIViewRepresentable` can satisfy the protocol.



Here is what was implemented.

### UIKit scroll proxy
New file: [`RA11y-iOS/RA11y-iOS/Games/iOSResonanceVoiceOverScrollProxyRepresentable.swift`](RA11y-iOS/RA11y-iOS/Games/iOSResonanceVoiceOverScrollProxyRepresentable.swift)

- **`ResonanceVoiceOverProxyScrollView`** (`UIScrollView`) — fires a **one-time** callback after first layout in a window so VO setup can run when the view has a real size.
- **`iOSResonanceVoiceOverScrollProxyCoordinator`** — `UIScrollViewDelegate` forwards **`contentOffset.y`** to SwiftUI; runs the **initial VO sequence** when VoiceOver is on:  
  `500 ms` delay → **`.screenChanged`** → `300 ms` → **`.layoutChanged`** with the **`UIScrollView`** (replaces the old `AccessibilityFocusState` + SwiftUI focus) → **announcement** using `dungeon.a11y.scroll.vo.focusAnnouncement`.
- **Content** — clear `UIView` pinned to `contentLayoutGuide` with a **height constraint** = `contentBlockHeight + 2 × verticalPadding` (aligned with the old SwiftUI `minHeight` + vertical padding).
- **Accessibility** — `isAccessibilityElement = true`, `dungeon.resonance.scrollLane`, label/hint from the caller (same strings as before).

### Play surface
[`iOSDungeonResonancePlayView.swift`](RA11y-iOS/RA11y-iOS/Games/iOSDungeonResonancePlayView.swift) — SwiftUI **`ScrollView` + `onScrollGeometryChange` + `@AccessibilityFocusState`** removed; replaced by the representable above. **`playSurface.onAppear`** only logs environment; focus is owned by the UIKit coordinator.

### Docs / tree
- [`memlog/research/CrystalResonance-VoiceOverScrollProxy-Investigation.md`](memlog/research/CrystalResonance-VoiceOverScrollProxy-Investigation.md) — revision row describing the shipped interop.  
- [`memlog/DirectoryTree.txt`](memlog/DirectoryTree.txt) — includes the new file under `Games/`.

### Build
`xcodebuild` for **RA11y-iOS** (**generic iOS Simulator**) **succeeds**.

`./utility/build_and_test.sh --only-ios` was started; it reached the **Testing** phase and was still running in the environment after several minutes (simulator tests can be slow). Re-run that locally if you want a full green test run.

**Next step for you:** On a **device** with VoiceOver, confirm swipe order reaches the scroll view and **three-finger** scroll moves the lane; if focus order is still wrong, the next knob is often **container / rotor** or adjusting **when** `layoutChanged` is posted relative to navigation chrome.

---

**User**

That worked!  We'll need a bunch of polish but i'm happy to stop for a bit.  Lets take a look at this branch and come up with a PR Description and we're at a good point to merge.

---

**Cursor**

Reviewing the branch’s changes against the base branch to draft an accurate PR description.



Here is a PR description you can paste into GitHub. The branch `updates-with-enchant-assets-refactor` is large relative to `main`; the text below frames the full scope and highlights the resonance / VoiceOver work you just validated.

---

## PR Title (suggestion)

**RA11y iOS: games expansion, Crystal Resonance, VoiceOver & screenshot pipeline**

—

## Summary

This branch delivers a substantial slice of the iOS product: three training games with updated art and hub integration, **Crystal Resonance** (scroll-hunt / alignment) gameplay with multimodal feedback, **VoiceOver-first** routing and messaging, **Lights Off** and basics-flow support where wired, a **deterministic screenshot / UI-test harness** (`-screenshotScene`, `-uiTesting`), and **RA11yCore** updates (hub, storage, quest feedback, scoring tests). Repository **agent/build docs** (`AGENTS.md`), **Fastlane**, and **utility scripts** are aligned with dynamic simulator selection and screenshot validation.

---

## User-visible behavior

- **Hub & navigation:** Quest cards, routing, and loading behavior updated for current game set and flows.
- **Games:** Enchanter’s Trial, Rogue’s Gauntlet, and Dungeon Descent / **Crystal Resonance** with resonance alignment (orb / reticle, lane, seal when aligned), timers on later levels, and result flow.
- **VoiceOver:** Starting a quest still expects VoiceOver for real users; **UI tests and automation** can pass **`-uiTesting`** so **game entry does not require VoiceOver** on the simulator.
- **Crystal Resonance / three-finger scroll:** The playable scroll proxy is a **UIKit `UIScrollView`** bridged via **`iOSResonanceVoiceOverScrollProxyRepresentable`**, replacing the SwiftUI-only scroll proxy so VoiceOver can focus and scroll the lane reliably; programmatic focus uses `screenChanged` → `layoutChanged` (scroll view) → announcement.
- **Screenshots:** Regenerated / extended **iPad** and **iPhone** doc screenshots; catalog and Fastlane allowlists updated where required.

---

## Technical notes

- **iOS:** Notable files include `iOSAppRouter.swift` (including `-uiTesting` bypass for `pushGame`), `iOSDungeonDescentView.swift` / `iOSDungeonResonancePlayView.swift`, `iOSResonanceVoiceOverScrollProxyRepresentable.swift`, hub/first-run/results/VoiceOver views, `Localizable.xcstrings`, and asset catalog additions.
- **RA11yCore:** Hub view model, storage batching, game session coordinator, quest feedback types/reducer, logging, scoring tests—see package tests for behavior.
- **Tooling:** `utility/build_and_test.sh`, `utility/validate_screenshot_contract.sh`, `utility/ExtractScreenshots.swift`, `utility/ValidateScreenshotContract.swift`, Fastlane/Snapfile, `resolve_simulator_udid.jq` (simulator discovery per `AGENTS.md`).
- **Documentation / memlog:** `DirectoryTree`, requirements and design notes, **ADR-0003** (resonance design), **`CrystalResonance-VoiceOverScrollProxy-Investigation.md`** (history of SwiftUI issues + UIKit follow-up).

---

## Testing / merge checklist

- [ ] `utility/build_and_test.sh` (or Core + iOS as you usually run).
- [ ] If screenshot routes or anchors changed: `utility/validate_screenshot_contract.sh`.
- [ ] Smoke **VoiceOver on device**: hub → Dungeon / Crystal Resonance → three-finger scroll + seal when aligned.
- [ ] Optional: confirm no **unwanted** tracked files (e.g. IDE `xcuserstate`, `.bak` assets, local `.claude` config) if those are not meant for the repo.

---

## Follow-ups (not blocking this PR)

- UI/copy **polish** on Crystal Resonance and related strings.
- Any **screenshot** re-runs after final polish.
- Continued tightening of **navigation / focus** order if further VoiceOver tuning is needed outside the scroll proxy.

---

You can shorten the “Summary” for reviewers who only care about the latest commit by adding a one-line callout at the top:

> **Latest:** VoiceOver scroll for Crystal Resonance now uses a **UIKit `UIScrollView` representable**; confirmed working on device.

---

**User**

lets grab new screenshots.

---

**Cursor**

Validating the screenshot contract, then running Fastlane snapshot to capture screenshots.



Here’s what ran and what changed.

### Ran
1. **`./utility/validate_screenshot_contract.sh`** — passed (Fastfile, scenes, catalog aligned).
2. **`bundle exec fastlane screenshots`** (from `fastlane/`) — **exit 0** (~7.3 minutes).

### Outputs
- **`docs/screenshots/en-US/iPhone_large/`** — `01_`–`11_` PNGs **updated**; **`12_ResonanceMockup.png`** **new** (untracked).
- **`docs/screenshots/en-US/iPad/`** — same **`01_`–`11_` updated**; **`12_ResonanceMockup.png`** **new** (untracked).
- **`fastlane/screenshots`** is the usual build output (often gitignored); the lane **copies** into **`docs/screenshots/`** for commits.

### Simulator note
The lane logged **`[simulator] Skipping duplicate: iPhone_small resolved to same UDID as a prior device`**, so **`iPhone_small` was not run** in this pass (same UDID as `iPhone_large`). **`docs/screenshots/en-US/iPhone_small/`** was **not** refreshed this time.

To capture **small** only on the next run (example):

```bash
cd fastlane && SNAPSHOT_DEVICES="iPhone SE (3rd generation)" bundle exec fastlane screenshots
```

(or pick another small phone name that appears in `xcrun simctl list devices available`).

### Next step for you
Stage and commit the **`docs/screenshots`** updates, including the new **`12_ResonanceMockup.png`** files on both iPad and iPhone_large.

---

**User**

docs/screenshots/en-US/iPad/12_ResonanceMockup.png  Take a look.  There are some weird artifacts in the image.  Like the grey rectangles around the Glyphs.

---

**Cursor**

Inspecting the resonance mockup view and glyph rendering for sources of grey rectangles.



Identifying the cause: iOS 16+ `ScrollView` applies a default scroll content background (often a light grey material) that shows through transparent PNG edges and in letterboxed areas around `scaledToFit()` images. Hiding the scroll content background and tightening image rendering.



Here is what was going on and what we changed.

### Cause
On recent iOS versions, **`ScrollView` draws a default scroll content background** (a light, material-like layer). That sits **behind** your lane content. For **transparent PNGs** (decoys, moonstone, lane ticks), that layer shows through the soft edges and in the **letterboxed** parts of a square `frame` when using **`scaledToFit()`**, which reads as **grey boxes or halos** around the art—especially in **XCTest screenshots**, where compositing is a bit harsher than on device.

### Changes (in `iOSDungeonResonanceMockupView.swift`)
1. **`.scrollContentBackground(.hidden)`** on the mockup **`ScrollView`** so the shaft background is what shows through transparency, not the system scroll surface.
2. **`.interpolation(.high)`** on catalog **`Image`**s (decoys, moonstone, lane marker) to reduce scaling fringe.
3. **`.compositingGroup()`** on decoy chips and moonstone so alpha is flattened with the layer before the row’s opacity/compositing (helps odd edge blending in some cases).

Build succeeds.

### What you should do
Re-run the **resonance mockup** screenshot (or full `fastlane screenshots`) and check `12_ResonanceMockup.png` again.

If you still see **grey at the very edge of the PNGs** only, that is often **asset** (semi-transparent grey in the file or export). In Xcode, open the imageset and confirm **Render As** is **Default** (not **Template Image**), and consider re-exporting with a clean alpha.

---

**User**

You can only 3 finger swipe up and down between 2 ui states.  We need to be able to traverse all the items in the vertical stack.  Also thee UI needs some work.  They should align visually in a satisfying way.  Also we need to use the haptic and audio components we developed into the game.  
Console snippet.

[RA11yScroll] VO proxy scroll contentOffset.y 0.0 → 7.0
alignment sample targetMidY=675.4 aimMidY=603.0 delta=72.3 reachable=false vo=true
[RA11yScroll] alignment sample targetMidY=675.4 aimMidY=603.0 delta=72.3 reachable=false vo=true
VO proxy scroll contentOffset.y 7.0 → 16.7
[RA11yScroll] VO proxy scroll contentOffset.y 7.0 → 16.7
VO proxy scroll contentOffset.y 16.7 → 30.0
[RA11yScroll] VO proxy scroll contentOffset.y 16.7 → 30.0
Haptic cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.near), family: proximityPulse
Audio cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.near), family: resonance
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
VO proxy scroll contentOffset.y 30.0 → 47.0
[RA11yScroll] VO proxy scroll contentOffset.y 30.0 → 47.0
VO proxy scroll contentOffset.y 47.0 → 77.3
[RA11yScroll] VO proxy scroll contentOffset.y 47.0 → 77.3
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
Haptic cue rendered — intent: lockLost, family: softTick
Audio cue rendered — intent: lockLost, family: warningPulse
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
VO proxy scroll contentOffset.y 77.3 → 112.3
[RA11yScroll] VO proxy scroll contentOffset.y 77.3 → 112.3
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
VO proxy scroll contentOffset.y 112.3 → 149.0
[RA11yScroll] VO proxy scroll contentOffset.y 112.3 → 149.0
Haptic cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.warm), family: softTick
Audio cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.warm), family: resonance
ViewModel alignment band→warm reachable=false vo=true
[RA11yScroll] ViewModel band→warm reachable=false
VO proxy scroll contentOffset.y 149.0 → 185.3
[RA11yScroll] VO proxy scroll contentOffset.y 149.0 → 185.3
VO proxy scroll contentOffset.y 185.3 → 218.7
[RA11yScroll] VO proxy scroll contentOffset.y 185.3 → 218.7
ViewModel alignment band→far reachable=false vo=true
[RA11yScroll] ViewModel band→far reachable=false
VO proxy scroll contentOffset.y 218.7 → 267.3
[RA11yScroll] VO proxy scroll contentOffset.y 218.7 → 267.3
VO proxy scroll contentOffset.y 267.3 → 279.7
[RA11yScroll] VO proxy scroll contentOffset.y 267.3 → 279.7
VO proxy scroll contentOffset.y 279.7 → 282.7
[RA11yScroll] VO proxy scroll contentOffset.y 279.7 → 

---

**Cursor**

Implementing VoiceOver traversal of each lane row (scroll view exposes per-row accessibility), aligning lane layout, and wiring quest feedback (haptics/audio) into the gameplay surface.



Implementing per-row VoiceOver elements in the UIKit scroll proxy, aligning scroll content height with the visual lane, and wiring wrong-activation feedback. Checking chip sizes and localization keys.



Implementing: adding layout constants to components, refactoring the scroll proxy, updating the play view and localization, and wiring wrong-activation feedback.



Implementing lane layout constants, refactoring the scroll proxy to add per-row accessibility elements, updating the play view, localization, and wrong-activation feedback.



Writing the refactored scroll proxy representable.



Fixing view-builder type erasure: `Group` prevents the `Image` chain from exposing `.interpolation`. Extracting image branches so modifiers apply to `Image` directly.



Applying `.interpolation` to `Image` before `.resizable()`, which erases the `Image` type.



Here’s what was implemented to finish the handoff.

### VoiceOver: traverse every chamber row
- `iOSResonanceVoiceOverScrollProxyRepresentable` no longer makes the `UIScrollView` a **single** accessibility element.
- It builds a vertical `UIStackView` of **`ResonanceLaneAccessibilityRowView`** instances—**one label per room**, ids `dungeon.resonance.lane.row.0…`, shared hint `dungeon.a11y.lane.row.hint`.
- Initial focus uses `.layoutChanged` on the **first row** when VoiceOver is on (fallback: scroll view).
- `scheduleVoiceOverLandingIfNeeded` and the struct’s doc comments are updated to match.

### Scroll ↔ visual alignment
- Added `iOSDungeonResonanceLaneLayout` (`rowSpacingPoints` 56, `rowContentHeightPoints` 76) in `iOSDungeonResonanceComponents.swift` and wired the play `VStack` plus **content height** to the same math (replacing the old `44 × arbitrary rowCount` formula that diverged from the UI).

### UI polish (grey / stacking)
- Decoy and Moonstone catalog images use `.interpolation(.high)` **before** `.resizable()`, plus `.compositingGroup()` to reduce stray compositing rectangles.

### Haptics & audio
- **Alignment:** unchanged path—your logs already show `questFeedbackCoordinator` driving proximity/lock; that remains.
- **Wrong seal:** `DungeonDescentViewModel.activateNonTarget` now calls `questFeedbackCoordinator.process(.wrongActivation)` when `screenshotScene == nil`, matching the `hintRequested` guard pattern.

### Copy
- New keys: `dungeon.a11y.lane.row.decoy`, `dungeon.a11y.lane.row.moonstone`, `dungeon.a11y.lane.row.hint`.
- Updated: `dungeon.a11y.scroll.vo.focusAnnouncement`, `dungeon.a11y.scroll.container.hint` (row-by-row + three-finger behavior).

`utility/build_and_test.sh` (Core + iOS) completed successfully.

If anything still feels off on device: very large Dynamic Type can make the **visual** chips taller than the **fixed 76 pt** proxy rows—say if you want those tied to the same `ScaledMetric` next.

---

**User**

This totally broke the 3 finger swipe. and ability to reach the moonsteon alignment lane.  Now there are bunch of views that you can navigate to armory, guardroom, well chamber, etc.  These are not related to the moonstone resonance guide at all.  What are they doing here?  This is a massive regression.

---

**Cursor**

Reverting the per-row VoiceOver elements — they exposed dungeon room names as separate rotor targets and disrupted VoiceOver's single scrollable surface, breaking three-finger scroll. Restoring a single accessibility element for the Moonstone alignment lane while keeping the corrected scroll-content height and other non-VO fixes.



Restoring the proven single-element scroll proxy: one VoiceOver "Moonstone alignment lane" surface so three-finger scroll works. The per-room labels were incorrect for this metaphor and split focus across chamber names.



---

**User**

Why are there chambers mentioned at all this is a game where you align objects, not navigate a dungeon.  You are mixing things up with old requirements.  Also there are no audio cues or haptics, but it could just be the error state we are in with weird room navigation artifacts.

---

**Cursor**

Searching for chamber/dungeon language in resonance + VoiceOver copy and tracing the quest feedback path for alignment haptics/audio.



Reframing copy around alignment (Moonstone, orb, lane)—not dungeon navigation. Removing room names from objectives and hints. Updating the ViewModel hint and localization entries.



Here is what was going wrong and what we changed.

### Why “chambers” showed up at all
Crystal Resonance is implemented as a **scroll-alignment** game, but the **strings were still written for an older “dungeon descent” pitch**: visible objectives and VoiceOver text used `String(format: …, target.displayName)`, so you got **Guard Room, Armory, Relic Vault**, etc. Those names come from `DungeonRoom.displayName` (art / data labels), not from the resonance mechanic. Putting them in the HUD/objective made it sound like **navigation**, not **lining up the Moonstone with the orb**.

### What we changed
- **`iOSDungeonResonancePlayView`** – `objectiveText` and `objectiveA11yLabel` no longer take `displayName`. They use fixed copy per level (`dungeon.l1/l2/l3.objective.format` and `dungeon.a11y.l*.objective.format`) that only talk about **Moonstone, center orb, timer, Moonstone alignment lane**.
- **`DungeonDescentViewModel.requestHint()`** – uses new **`dungeon.resonance.hint`** (no room name); doc comments note alignment-only copy.
- **`Localizable.xcstrings`** – updated objectives, timer blurbs, scroll hint, L1 tip, seal hint, continue hint, and stale `dungeon.l*.objective` entries so they match the **alignment** metaphor. Added **`dungeon.resonance.hint`**.
- **`DungeonRoom`** doc comment – clarifies that **`displayName` is for assets / edge cases**, not VO “where to go next.”

Narration/prologue lines that still say “shaft / chambers” (e.g. DM prompts) are **story flavor**; the **live HUD + VO objectives** for the shaft are now consistent with “align objects.”

### Haptics and audio
Feedback is still driven from **`updateResonanceDelta`** → `questFeedbackCoordinator.process(.alignmentBandChanged(band))` whenever **`screenshotScene == nil`** and the band actually changes. The profile **`QuestFeedbackProfile.dungeonResonance`** maps those to haptics and synthesized tones.

If cues feel missing:

- **Simulator:** Taptic feedback is not produced the same way as on device; rely on logs like `Haptic cue rendered` / `Audio cue rendered` or test on hardware.
- **Device:** Confirm **Settings → Sound**, ringer, and that feedback is not covered by system volume; alignment must **cross band thresholds** (idle at one band won’t repeat cues until the band changes).

`utility/build_and_test.sh --only-ios` completed successfully after these edits.

---

**User**

Are you sure that we don't need to fix the images.  They still have these big grey borders around the glyphs.
We will only be manually verifying on device, so no worries about the simulator for that context.

---

**Cursor**

Tracing how glyph images are drawn and inspecting asset configuration to determine whether borders come from the assets or from rendering.



Identifying the issue: all four glyph PNGs are RGB (color type 2) — no alpha. They include opaque canvas areas, so SwiftUI scales the full rectangle and shows visible borders. Documenting this and adding contributor guidance. Re-exporting assets as RGBA with tight crops will fix it; code can't add transparency that isn't in the files.



Confirming: all four glyphs are PNG color type 2 (RGB) — no alpha. Opaque letterboxing/light backgrounds become visible rectangles when scaled. Running the repo's edge white-removal utility to produce RGBA assets.



Yes — the **images needed fixing**, not just SwiftUI.

### What was wrong
Those glyph PNGs (`dungeon_target_moonstone`, `dungeon_decoy_*`) were **PNG RGB (color type 2)** — **no alpha**. The artwork sat on a full **1376×768 opaque canvas** (white / light matte). SwiftUI scales the **whole bitmap** into the small frame, so you see a **big rectangular panel** behind the sprite. That reads as grey or light “borders” on your dark shaft, and no amount of `.compositingGroup()` can invent transparency that isn’t in the file.

### What we did
1. Ran the repo’s **`utility/remove_white_background.py`** in **`--in-place`** mode (edge-connected near‑white → transparent) on all four glyphs so they are now **PNG RGBA (color type 6)**.
2. Removed the generated **`.png.bak`** backups so they aren’t committed.
3. Documented the requirement in **`iOSDungeonResonanceArt.swift`** and **`DungeonResonanceAssetPipeline.txt`**.

### What you should check on device
- **Fringing / holes:** Edge mode only clears background that is **white and connected to the image border**. If any glyph had **white that connects art to the frame** in a bad way, you could get odd transparency; also **internal** light areas that touch the border might be affected. Your manual pass on hardware is the right check.
- **Finer art pass:** For pixel‑perfect edges, re‑export from the design tool with **proper alpha** (and tighter crops) is still the gold standard; the script is a solid engineering fix for the old RGB masters.

So: **yes, it was an asset issue (missing alpha)**; we’ve corrected the shipped PNGs accordingly. SwiftUI tweaks alone wouldn’t have been enough.

---

**User**

Moonstone lane is focused but 3 finger swiping is broken.  You can also not navigate to the instructions or title views anymore in the right order.  You have to go past the moonstone lane a few swipes before you can find it.  We are breaking lots of things here.

---

**Cursor**

Inspecting VoiceOver sort priorities and view layering — likely causes of wrong reading order and broken three-finger scroll.



Identifying issues:
1. Programmatic `UIAccessibility.post(.layoutChanged, argument: scrollView)` forces focus onto the lane, skipping the navigation title and top chrome (objectives/instructions).
2. `accessibilitySortPriority(10)` on the scroll proxy vs `-5` on chrome makes the lane sort before the HUD — backwards for top-to-bottom reading.

Fixing both: removing the forced focus chain and correcting sort priorities so top chrome → lane → bottom chrome.



Stopping programmatic `layoutChanged` that moved VoiceOver to the scroll view (skipping the nav title and instructions). Fixing inverted `accessibilitySortPriority`: higher values sort first, so the lane at `10` was appearing before chrome at `-5`.



Here’s what was going wrong and what we changed.

### 1. Programmatic focus was skipping the HUD  
`scheduleVoiceOverLandingIfNeeded` was posting **`UIAccessibility.layoutChanged` with the `UIScrollView`**, which **moved VoiceOver straight to “Moonstone alignment lane”** after the delays. That **skipped the navigation chrome and the top HUD** (objective + gesture tips), so the experience felt out of order and people didn’t get instructions before the lane.

**Change:** That path **no longer** posts `screenChanged`, `layoutChanged`, or the lane **announcement**. Focus follows the normal view order so the **title and instructions come first**; people move to the lane when they’re ready (same idea as your L1 copy about focusing the lane).

### 2. `accessibilitySortPriority` was backwards  
In SwiftUI, **larger** `accessibilitySortPriority` values are **earlier** in the VoiceOver order.

You had:

- Moonstone lane: **`10`**
- Top / bottom chrome: **`-5`**

So the **lane sorted before the HUD**—the opposite of top-to-bottom reading. That matches “you have to swipe past the lane a bunch before things make sense.”

**Change:** Introduced explicit tiers:

- **Top HUD** (objective, timer, gesture tips): **`30`**
- **Moonstone alignment lane** (UIKit scroll proxy): **`20`**
- **Bottom** (seal, hint, continue, timeout): **`10`**

So the intended swipe flow is: **HUD → lane → bottom actions** (with the system nav title where the stack puts it).

### Files touched  
- `iOSResonanceVoiceOverScrollProxyRepresentable.swift` — removed forced VO posts; documented why.  
- `iOSDungeonResonancePlayView.swift` — `iOSResonancePlayAccessibilitySortTier` + updated priorities and docs.

`utility/build_and_test.sh --only-ios` completed successfully.

On device, confirm **linear swipe** order and that **three-finger scroll** works with focus on **Moonstone alignment lane** after you’ve reached it in order; if anything still feels off, say whether **RTL** or a **custom nav** is in play and we can tune further (e.g. container grouping).

---

**User**

Moonstone alignment lane is focused, but the 3 finger swipe doesn't work] ViewModel band→near reachable=false

[RA11yScroll] playSurface.onAppear vo=true reducedMotion=false
Failed to create 0x88 image slot (alpha=1 wide=0) (client=0x1a6865d1) [0x5 (os/kern) failure]
alignment sample targetMidY=719.1 aimMidY=139.3 delta=579.8 reachable=false vo=true
[RA11yScroll] alignment sample targetMidY=719.1 aimMidY=139.3 delta=579.8 reachable=false vo=true
ViewModel alignment band→far reachable=false vo=true
[RA11yScroll] ViewModel band→far reachable=false
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
Haptic cue rendered — intent: lockLost, family: softTick
Audio cue rendered — intent: lockLost, family: warningPulse
Haptic cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.near), family: proximityPulse
Audio cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.near), family: resonance
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
UIKit proxy: no programmatic layoutChanged — preserves nav + HUD VoiceOver order before the lane
[RA11yScroll] UIKit proxy: skipped layoutChanged/announcement — VO order uses sortPriority + swipe
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
Haptic cue rendered — intent: lockLost, family: softTick
Audio cue rendered — intent: lockLost, family: warningPulse
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
Haptic cue rendered — intent: lockAcquired, family: alignmentSnap
Audio cue rendered — intent: lockAcquired, family: resonance
ViewModel alignment band→locked reachable=true vo=true
[RA11yScroll] ViewModel band→locked reachable=true
App is being debugged, do not track this hang
Hang detected: 2.98s (debugger attached, not reporting)
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
Bound preference ResonanceAimLineGlobalMidYPreferenceKey tried to update multiple times per frame.SPACE

---

**Cursor**

Tracing geometry: logs show aimMidY ≈ 139 vs targetMidY ≈ 719 — aim-line measurement looks wrong. Checking how we measure the aim line and whether the layout causes a zero-size geometry (matches the `wide=0` error).



Identifying two issues:
1. Scroll: UIScrollView only scrolls when content height > bounds. We switched to accurate lane math; if intrinsic lane height < the viewport, content won't scroll — breaking three-finger scroll.
2. Aim line: Overlay `GeometryReader` without a guaranteed size can collapse (matches `wide=0` / bogus `aimMidY≈139`). We should measure from the full play area (or orb stack) and coalesce preference updates.

Implementing fixes: measuring viewport height, setting `contentBlockHeight = max(intrinsicLane, viewport - 2*padding + slack)`, moving aim-line preference to a full-frame background on `centerOrbStack`, and debouncing preference updates.



Implementing: ensuring scroll content height exceeds the viewport (with matching SwiftUI spacer so offsets stay aligned), fixing aim-line geometry via a full-size measurement on `centerOrbStack`, and coalescing preference updates.



Here’s what was going wrong and what we changed.

### 1. **Why three-finger scroll did nothing**  
`UIScrollView` only scrolls when **`contentSize.height > bounds.height`**. The lane’s **intrinsic** height (a few rows) was often **shorter than the playfield**. Content height matched the lane, so there was **nothing to scroll** — `contentOffset` barely moved, so VoiceOver’s three-finger scroll had no effect even though the lane was focused.

**Change:** Measure the playfield with `ResonancePlayfieldViewportHeightPreferenceKey`, then set  
`voiceOverLaneTotalScrollBlockHeight = max(intrinsicLane, playfieldHeight - 2×verticalPadding + 32)`.  
Add a **`Color.clear` spacer** at the bottom of the lane `VStack` with height  
`max(0, totalScrollBlock − intrinsic)` so the **SwiftUI lane** matches the **UIKit** scroll content height and offsets stay in sync.

### 2. **Why `aimMidY` looked like ~139 vs target ~719**  
The old **overlay** `GeometryReader` wasn’t guaranteed to fill the area (collapsed / wrong layout). That produced a bad **global** frame (and could contribute to **`Failed to create 0x88 image slot ... wide=0`** style issues).

**Change:** Stop using that overlay for the aim line. Attach the aim measurement to **`centerOrbStack`** with a **full-size** `GeometryReader` in a **background** and `.frame(maxWidth: .infinity, maxHeight: .infinity)`, so **`geo.frame(in: .global).midY`** is the **vertical center of the orb stack** (the real aim line).

### 3. **Preference churn**  
Throttled `onPreferenceChange` for aim and moonstone (ignore changes **&lt; 0.25 pt**) to cut duplicate work and the **“tried to update multiple times per frame”** warning.

---

`utility/build_and_test.sh --only-ios` completed successfully. On device you should see **sane alignment deltas** (aim and moonstone in the same vertical ballpark when lined up) and **scroll** with **contentOffset** changing in logs when using three fingers on the lane. If anything is still off, say whether it’s **L1 with few rooms** or **iPad** so we can tune the **+32** slack.

---

**User**

Still broken, even when focused on the right view.

HubViewModel.init
alignment sample targetMidY=109.1 aimMidY=139.3 delta=30.2 reachable=false vo=true
[RA11yScroll] alignment sample targetMidY=109.1 aimMidY=139.3 delta=30.2 reachable=false vo=true
Haptic cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.near), family: proximityPulse
Audio cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.near), family: resonance
ViewModel alignment band→near reachable=false vo=true
[RA11yScroll] ViewModel band→near reachable=false
playSurface.onAppear vo=true reducedMotion=false
[RA11yScroll] playSurface.onAppear vo=true reducedMotion=false
alignment sample targetMidY=10.3 aimMidY=139.3 delta=129.0 reachable=false vo=true
[RA11yScroll] alignment sample targetMidY=10.3 aimMidY=139.3 delta=129.0 reachable=false vo=true
ViewModel alignment band→far reachable=false vo=true
[RA11yScroll] ViewModel band→far reachable=false
Haptic cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.warm), family: softTick
Audio cue rendered — intent: proximityEntered(RA11yCore.QuestFeedbackBand.warm), family: resonance
ViewModel alignment band→warm reachable=false vo=true
[RA11yScroll] ViewModel band→warm reachable=false
Bound preference iOSResonanceTargetMidYPreferenceKey tried to update multiple times per frame.
Bound preference ResonancePlayfieldViewportHeightPreferenceKey tried to update multiple times per frame.
Failed to create 0x88 image slot (alpha=1 wide=0) (client=0x8f58f896) [0x5 (os/kern) failure]
Bound preference ResonanceAimLineGlobalMidYPreferenceKey tried to update multiple times per frame.
UIKit proxy: no programmatic layoutChanged — preserves nav + HUD VoiceOver order before the lane
[RA11yScroll] UIKit proxy: skipped layoutChanged/announcement — VO order uses sortPriority + swipe
App is being debugged, do not track this hang
Does VO accessibility swipes for example register inthe UIResponder chain that you can examine and add print statements?  This could be helpful for debugging.

What about this feedback
# Crystal Resonance 3-Finger Swipe: Why It's Brittle & How to Protect It

## Context

The 3-finger VoiceOver swipe in Crystal Resonance relies on a transparent `UIScrollView` proxy overlaid on the entire playfield. iOS natively delivers 3-finger scroll events to whatever `UIScrollView` has current VoiceOver focus — **no gesture recognizer, no `accessibilityAction`**. That means the gesture lives entirely at the mercy of VoiceOver's focus chain. Any change to the view hierarchy that disrupts focus order, intercepts touches, or hides the scroll proxy from VoiceOver silently kills it.

The current working tree has uncommitted changes across all five gameplay files. The committed code (HEAD) appears correct; the breakage is in-progress work. This plan identifies the specific failure modes and provides a repeatable checklist.

---

## Why It Breaks: The Five Root Causes

### 1. VoiceOver focus not landing on the scroll proxy
**The mechanism:** Three-finger swipe only scrolls the view that *currently* has VoiceOver focus. If focus is on the objective card, timer HUD, or any other element, the gesture is swallowed by iOS and the lane doesn't move.

**What breaks it when iterating:**
- Adding a new accessibility element (status badge, progress ring, overlay card) in the ZStack without an explicit `accessibilitySortPriority` that places it at tier 30 (top chrome) or tier 10 (bottom chrome). If its priority falls at 20 or is unset, VoiceOver may stop there instead of reaching the scroll proxy.
- Adding `.isAccessibilityElement = true` to any view inside the playfield ZStack.
- Removing `.accessibilityHidden(true)` from the decorative lane column — each lane row then becomes a separate VoiceOver stop between the top chrome and the scroll proxy.
- Removing or weakening `.accessibilityElement(children: .ignore)` on `resonanceLaneColumn`.

**The invariant to protect:** The `iOSResonanceVoiceOverScrollProxyRepresentable` must be the **only** interactive AX element in the ZStack body. Everything else is either `accessibilityHidden(true)` or lives in `topChrome`/`bottomChrome` at their sort tiers.

---

### 2. Hit testing intercepting the scroll view
**The mechanism:** The UIScrollView receives touches via UIKit's responder chain. If any SwiftUI view is layered above it in the ZStack with `allowsHitTesting(true)` (the default), that view consumes touch events before they reach the scroll view.

**What breaks it when iterating:**
- Adding a non-decorative overlay (e.g., a fullscreen success flash, a progress vignette, a "lights on" mode reveal) above the scroll proxy in ZStack order without `allowsHitTesting(false)`.
- The existing `iOSResonanceLightsOffVignette` already has `allowsHitTesting(false)` — new overlays need the same.

**The invariant to protect:** Every view in the ZStack above the `iOSResonanceVoiceOverScrollProxyRepresentable` entry must carry `.allowsHitTesting(false)`.

---

### 3. Content height dropping below viewport (scroll range collapses to zero)
**The mechanism:** `UIScrollView` only scrolls when `contentSize.height > bounds.height`. The proxy calculates `voiceOverLaneTotalScrollBlockHeight` to ensure this, but the calculation depends on `playfieldViewportHeight` which comes from a `GeometryReader` preference key.

**What breaks it when iterating:**
- New `safeAreaInset` additions change the available height but `playfieldViewportHeight` reflects the ZStack frame, not the insets. If viewport shrinks without the scroll proxy knowing, content height may no longer exceed bounds.
- Changes to `RA11ySpacing.xl` (used as `verticalPadding` in `computeTotalContentHeight`) will mis-size the proxy relative to the lane.
- Changing `rowContentHeightPoints` or `rowSpacingPoints` in `iOSDungeonResonanceLaneLayout` without adjusting `voiceOverLaneIntrinsicBlockHeight` — the proxy and the visual lane grow apart, so the scroll stops where the lane does.

**The invariant to protect:** `computeTotalContentHeight()` in the proxy must always exceed the proxy's rendered height. After any layout change, log `[RA11yScroll]` lines and verify `contentOffset.y` changes when scrolling.

---

### 4. UIViewRepresentable identity reset (offset snaps to zero)
**The mechanism:** SwiftUI calls `makeUIView` (not `updateUIView`) when the representable's identity changes. `makeUIView` constructs a fresh UIScrollView at offset 0. The SwiftUI state `voiceOverProxyScrollOffsetY` may still hold the old value, creating a visual/scroll mismatch.

**What breaks it when iterating:**
- Wrapping `iOSResonanceVoiceOverScrollProxyRepresentable(...)` in a new container with a changing `id(...)` modifier — this forces identity reset on every render.
- Moving the representable inside a conditional `if/else` block or a `switch` — SwiftUI may tear down and rebuild it on state changes.
- Phase transitions (L1 → L2 → L3) already reconstruct the view because `iOSDungeonResonancePlayView` is replaced wholesale in the `switch viewModel.phase` block in `iOSDungeonDescentView`. This is fine. What would break it is any new `if` branch *inside* `iOSDungeonResonancePlayView`'s `body` that conditionally shows/hides the proxy.

**The invariant to protect:** The proxy should be unconditionally present in the ZStack body (no `if` guards around it). State changes should flow through `updateUIView` props, not view identity.

---

### 5. Offset sync gap on level transition
**The mechanism:** When the phase changes, `voiceOverProxyScrollOffsetY` resets to 0 (fresh `@State`). But the newly-created UIScrollView also starts at 0, so they're in sync. The risk is partial resets: if `voiceOverProxyScrollOffsetY` is manually set to 0 (e.g., in a retry path) but the UIScrollView retains its old `contentOffset`, the visual lane and scroll position diverge.

**What breaks it when iterating:**
- Adding a "reset lane" action (e.g., on wrong-target activation, on hint, on timer threshold) that sets `voiceOverProxyScrollOffsetY = 0` without also scrolling the UIScrollView back to `contentOffset = .zero`.
- The proxy has no `scrollToTop()` API surface currently. If a reset is needed, it must be added.

---

## Best Practices Checklist (Run After Any Change to These Files)

```
iOSDungeonResonancePlayView.swift
iOSResonanceVoiceOverScrollProxyRepresentable.swift
iOSDungeonResonanceComponents.swift
iOSDungeonDescentView.swift
```

### Before building:
- [ ] Every new view added to the ZStack body: does it have `allowsHitTesting(false)` if it's above the scroll proxy entry?
- [ ] Every new accessibility element added to the ZStack body: is it `accessibilityHidden(true)` OR does it have an explicit `accessibilitySortPriority` at tier 30 or 10?
- [ ] Is `iOSResonanceVoiceOverScrollProxyRepresentable` unconditionally rendered (no `if` guards)?
- [ ] Did you change `RA11ySpacing.xl`, `rowContentHeightPoints`, or `rowSpacingPoints`? → Update the lane height math.

### After building, on device with VoiceOver on:
- [ ] Swipe right until VoiceOver announces the scroll proxy label ("Moonstone alignment lane" / localized). This must be reachable.
- [ ] While focused on the proxy, 3-finger swipe down. Lane moves. 3-finger swipe up. Lane moves back.
- [ ] Log line `[RA11yScroll] VO proxy scroll contentOffset.y` appears in Xcode console on swipe.
- [ ] Alignment `[RA11yScroll] alignment sample` lines appear as the lane scrolls.
- [ ] The Seal button appears in bottom chrome when the moonstone reaches the aim line.

---

## Files to Modify

| File | Change |
|------|--------|
| `iOSDungeonResonancePlayView.swift` | Primary surface for new requirements; guard ZStack additions with the checklist above |
| `iOSResonanceVoiceOverScrollProxyRepresentable.swift` | Only touch if scroll range or reset behavior changes |
| `iOSDungeonResonanceComponents.swift` | Lane layout constants live here; changes cascade to scroll math |

## Verification

End-to-end test on device (Simulator doesn't reproduce VoiceOver scroll behavior reliably):
1. VoiceOver on → launch → navigate past nav title and top HUD
2. Hear the scroll proxy announced → 3-finger swipe → lane moves → orb changes band
3. Align moonstone → Seal button activates → level completes
4. Advance to L2 → repeat; verify swipe still works after phase transition


---

**Cursor**

Fixing alignment by using a single named coordinate space (replacing unstable `.global` frames) and adding scroll-proxy debug hooks. Reading the file and implementing.



Switching alignment to a named playfield coordinate space (replacing unstable `.global` frames) and adding scroll-range diagnostics. Applying the changes.



Here’s what was going wrong, what we changed, and how it ties to your questions.

### Root cause: `.global` frames were wrong
`geo.frame(in: .global).midY` for the moonstone and aim line could be **nonsense during layout** (e.g. `targetMidY=10.3` vs `aimMidY=139.3`). That’s the same class of issue as **`Failed to create 0x88 image slot … wide=0`**: geometry wasn’t stable yet, so alignment and feedback were unreliable.

### Fix: one named playfield space
1. **`ResonancePlayfieldCoordinateSpace.name`** (`"resonancePlayfield"`) on the gameplay **`ZStack`** via `.coordinateSpace(name:)`.
2. **Moonstone** preference now uses  
   `geo.frame(in: .named(ResonancePlayfieldCoordinateSpace.name)).midY`  
   so the target is in **playfield** coordinates.
3. **Aim line** is no longer measured with a separate `GeometryReader`. It’s **`playfieldViewportHeight * 0.5`** in that same space (vertical center of the playfield = center orb line).
4. **`iOSResonanceAlignment.deltaPoints(targetMidY:aimMidY:)`** — parameters renamed; still `abs(a - b)` in one shared space.

Logs should look like:  
`alignment sample playfieldH=… targetMidY=… aimMidY=…` with **target** and **aim** both near **`playfieldH/2`** when the Moonstone is aligned.

### Preference spam
`onPreferenceChange` for viewport and target now **`await Task.yield()`** before updating state so updates tend to land on the **next** frame, which reduces “multiple times per frame” churn (may not remove it entirely; that’s a SwiftUI quirk).

### VoiceOver swipe vs `UIResponder`
**Three-finger VoiceOver scrolling** is handled by the system for the focused `UIScrollView`; it is **not** a normal `UIGestureRecognizer` you can trace like pan gestures. The practical way to debug is what you already have: **`scrollViewDidScroll`**, **`contentOffset`**, and **`[RA11yScroll] VO proxy scroll contentOffset.y`** in the bridge.

Documentation was added on **`iOSResonanceVoiceOverScrollProxyRepresentable`**. We also set **`isScrollEnabled = true`** explicitly and, in **DEBUG**, log **once** if **`contentSize.height <= bounds.height`** (no scroll range → VO scroll cannot move offset).

### Your checklist (the “five root causes”)
The code already follows most of it: lane **`accessibilityHidden`**, **`allowsHitTesting(false)`** on overlays, proxy **not** behind conditional identity, sort tiers for VO. The alignment bug was **geometry**, not focus order. Keeping **`iOSDungeonResonancePlayView` / proxy / components** in sync when changing spacing or lane math is still the right manual checklist.

`utility/build_and_test.sh --only-ios` completed successfully. On device, you should see sane **`playfieldH` / `targetMidY` / `aimMidY`** and scroll logs when the lane scrolls.

