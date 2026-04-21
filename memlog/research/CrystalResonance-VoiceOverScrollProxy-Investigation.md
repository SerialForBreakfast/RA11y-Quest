# Crystal Resonance — VoiceOver Scroll Proxy Investigation (SwiftUI)

**Date:** 2026-04-19 (ongoing)  
**Status:** Open for **device QA and layout invariants** — UIKit scroll proxy is **shipped** (`iOSResonanceVoiceOverScrollProxyRepresentable`); remaining risk is focus order, content-height/sync bugs, and regression when chrome or assets change (see QC doc §1).  
**Related:** [ADR-0003-Dungeon-Resonance-Scroll-Interaction.md](./ADR-0003-Dungeon-Resonance-Scroll-Interaction.md) (design intent; not a guarantee of SwiftUI runtime behavior)

---

## Problem statement

Crystal Resonance (Dungeon Descent v2) teaches **three-finger scrolling** while a **fixed aim line** (orb/reticle) stays at the screen center. The **visible lane** is offset to mirror scroll position; VoiceOver must scroll a **single, discoverable** scroll region so the lesson matches the skill.

Reported issues (device testing):

- After the **instruction / objective** VO elements, **right-swipe navigation does not reach** an element that announces **“Moonstone alignment lane”** (localized `dungeon.a11y.scroll.container`).
- Focus sometimes lands on a **small, unnamed rectangle** (e.g. bottom-center) with **no label** and **no response** to three-finger scroll.
- Even when logs show the **proxy scroll offset** updating, the **player experience** remains broken if VoiceOver focus is not on the scrollable accessibility element.

---

## Target architecture (SwiftUI — current)

Primary implementation: `RA11y-iOS/RA11y-iOS/Games/iOSDungeonResonancePlayView.swift`

| Piece | Role |
|--------|------|
| **Visual lane** | Clipped stack of glyphs; `accessibilityHidden(true)`; `allowsHitTesting(false)`; vertical `offset` tied to proxy scroll. |
| **Proxy `ScrollView(.vertical)`** | Full-screen (in remaining layout) transparent scroller; `onScrollGeometryChange` drives `voiceOverProxyScrollOffsetY` to move the lane. |
| **Chrome** | `safeAreaInset(edge: .top/.bottom)` — objective, tips, timer (L2/L3), seal / hint / continue. |
| **Aim line geometry** | `ResonanceAimLineGlobalMidYPreferenceKey` via hit-invisible overlay `GeometryReader` feeding `@State aimLineGlobalMidY`, paired with moonstone `midY` from `iOSResonanceTargetMidYPreferenceKey`. |

**UI testing vs. users:** `iOSAppRouter.pushGame` skips VoiceOver interstitial when the process argument `-uiTesting` is present (XCUITest / screenshot lanes). Product behavior for real users still requires VoiceOver for quest entry; this only affects automation.

---

## What we observed (evidence)

- Console / `[RA11yScroll]` logs sometimes show **`VO proxy scroll contentOffset.y`** changing — the **underlying** scroll view can move even when VoiceOver focus is wrong.
- Logs show **`playSurface.onAppear`**, **`UIAccessibility.Notification.screenChanged`**, **`layoutChanged`** with the `UIScrollView`, and (historically) a trailing **announcement** — **programmatic focus** runs, but does not prove linear swipe order later reaches the scroll proxy. The extra announcement was removed to avoid double-speak with the scroll view’s label and hint.
- Occasional **`Failed to create … image slot … wide=0`** messages — likely a **zero-width layer** (asset/FX path); treat as **separate** from scroll proxy until traced; may correlate with layout glitches.

---

## Attempts (what we tried)

### A. Instructional / copy

- Expanded **`dungeon.a11y.scroll.container.hint`** to state that three-finger scroll only applies when focus is on this element, not the objective row.
- Added **`dungeon.resonance.tip.voFocusOnLane`** on the L1 gesture tip card to tell the user to move VoiceOver until it reads **Moonstone alignment lane** if scrolling does nothing.
- **Result:** Helps when the user **hears** the hint; does not fix **non-discovery** in swipe order.

### B. VoiceOver ordering and focus

- **`accessibilitySortPriority`:** proxy scroll region **10**, chrome **−5** (intent: scroll lane before HUD when the platform merges trees).
- **Programmatic focus:** `@AccessibilityFocusState` for `scrollLane`, delayed `Task` after appear (~500 ms + ~300 ms), **`UIAccessibility.post(.screenChanged)`**, then announcement string `dungeon.a11y.scroll.vo.focusAnnouncement`.
- **Result:** Announcements can fire early; **subsequent right swipes** can still move through chrome / navigation / mystery views without ever landing on the labeled scroll proxy.

### C. Collapsing the SwiftUI scroll accessibility tree

- **`accessibilityElement(children: .ignore)`** on inner `VStack` (clear rows) and on the **`ScrollView`** after content, with **`accessibilityLabel` / `accessibilityHint` / `accessibilityIdentifier`** (`dungeon.resonance.scrollLane`) on the combined element.
- **Intent:** Avoid extra focusable children from **`Color.clear`** rows on some OS versions.
- **Result:** Still insufficient for reliable swipe order to the proxy.

### D. Layout containers and “mystery” rects

- **Removed root `GeometryReader`** wrapping the whole playfield (suspected extra **unnamed VoiceOver frame**). Replaced with **`ZStack` + overlay `GeometryReader`** posting **`ResonanceAimLineGlobalMidYPreferenceKey`**, with **`allowsHitTesting(false)`** and **`accessibilityHidden(true)`** on the overlay.
- **Alignment math:** **`applyResonanceAlignmentFromLastFrames()`** so preferences can arrive in **either** order (aim vs. target `midY`).
- **Empty bottom chrome:** **`hasPlayfieldBottomControls`** — do not apply bottom `safeAreaInset` content when there is no seal / hint / continue. Previously an **empty `VStack`** inside padded material could present as a **blank, focusable rect** on L1 when the moonstone was not yet aligned and `onHint` was nil.
- **Result:** Removes one concrete source of **unnamed bottom rectangles**; does **not** fix inability to swipe from instructions to the scroll lane.

### E. Game entry / automation

- **`pushGame`:** when `-uiTesting` is present, skip `GameStartDecision` / interstitial and push the playable route directly — so **XCUITest does not require VoiceOver enabled**. This is orthogonal to in-game scroll proxy discovery.

---

## Why SwiftUI remains problematic (working hypothesis)

1. **VoiceOver linear navigation** and **`safeAreaInset` / `NavigationStack`** composition can produce an accessibility order where the **full-screen `ScrollView`** is **not** the next element after the HUD, despite **`accessibilitySortPriority`**.
2. **`UIScrollView` exposed through SwiftUI** may still decompose or interact poorly with **combined** accessibility elements on some iOS versions.
3. **Three-finger scroll** is delivered to the scrollable AX ancestor of **focused** element; if focus never rests on the scroll proxy, the lane will not move even if direct manipulation / logging paths show offset changes from other events.

---

## Planned direction (next implementation)

**Introduce a UIKit `UIScrollView` (or `UIScrollView` subclass)** for the VoiceOver scroll proxy — typically via **`UIViewRepresentable`** (or a small hosted controller) — while keeping SwiftUI for the rest of the screen:

- Set **`isAccessibilityElement`**, **`accessibilityLabel`**, **`accessibilityIdentifier`**, and appropriate traits on the **UIKit** scroll view.
- Drive **`contentOffset`** (or equivalent) from the same offset model used for the visual lane, preserving current gameplay semantics.
- Validate with **VoiceOver on device**: linear swipe from objective through to the scroll proxy, then **three-finger** scroll.

Keep this document updated when the UIKit path lands (files, API boundaries, any deprecation of SwiftUI-only proxy).

---

## Key files and strings (reference)

| Item | Location |
|------|----------|
| Play surface | `RA11y-iOS/RA11y-iOS/Games/iOSDungeonResonancePlayView.swift` |
| Game container / phases | `RA11y-iOS/RA11y-iOS/Games/iOSDungeonDescentView.swift` |
| Router / UI testing gate | `RA11y-iOS/RA11y-iOS/App/iOSAppRouter.swift` (`-uiTesting`) |
| Localized scroll proxy label / hint (optional legacy announcement key) | `dungeon.a11y.scroll.container`, `dungeon.a11y.scroll.container.hint`, `dungeon.a11y.scroll.vo.focusAnnouncement` (unused by coordinator after 2026-04); L1 tip `dungeon.resonance.tip.voFocusOnLane` — `RA11y-iOS/RA11y-iOS/Localizable.xcstrings` |

---

## Revision history

| Date | Note |
|------|------|
| 2026-04-19 | Initial capture after SwiftUI mitigation attempts; records UIKit as follow-up. |
| 2026-04-19 | **Shipped interop:** `iOSResonanceVoiceOverScrollProxyRepresentable.swift` — transparent `UIScrollView` with Auto Layout content height, `UIScrollViewDelegate` for `contentOffset.y`, accessibility id/label/hint on the scroll view, initial VO sequence (`screenChanged` → delay → `layoutChanged` with `UIScrollView` → announcement). Wired from `iOSDungeonResonancePlayView` replacing SwiftUI `ScrollView`. |
| 2026-04-21 | Header status updated: problem history remains valid; **current** work is QC invariants + on-device verification, not “waiting on UIKit.” |
| 2026-04-21 | Coordinator: removed redundant `.announcement` (was double-speak with label+hint). |
| 2026-04-21 | Coordinator: **two** `layoutChanged` posts (second after 320 ms) restored for iPad focus landing; still no `.announcement`. |
