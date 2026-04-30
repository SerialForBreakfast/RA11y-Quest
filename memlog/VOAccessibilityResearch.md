# VoiceOver Accessibility Research Log

This is RA11y's living research log for VoiceOver behavior we verify while building quests and onboarding. Add to this file when we encounter a VoiceOver problem, learn what fails, confirm what works, or discover that two pieces of context interact in a way future work must preserve.

The goal is not to collect generic accessibility advice. Each entry should preserve the real product context, the failed assumptions, the implementation pattern that survived testing, and the verification evidence we can use again.

## Entry Template

Use this shape for future entries:

```markdown
## YYYY-MM-DD - Short Finding Title

Status: Draft | Verified | Replaced

Related implementation:
- `path/to/file.swift`

Related research:
- `memlog/research/...`

### Problem
What user-facing behavior failed, including the screen, quest, or onboarding step.

### Context That Influenced The Issue
The surrounding state that made the issue happen: VoiceOver on/off transition, navigation timing, scroll container ownership, selected trial, modal state, focus target, etc.

### What Does Not Work Reliably
Approaches we tried or are intentionally avoiding, and why.

### What Works
The pattern that survived device testing or is supported by primary sources.

### Best-Fit UX And Implementation Model
How the pieces should fit together when designing future screens.

### Verification Checklist
The concrete VoiceOver gestures, focus movement, announcements, and UI state checks that prove the fix.

### Sources
Primary sources and local research that support the conclusion.
```

## 2026-04-30 - VoiceOver Focus Is A Contract, Not An Announcement

Status: Verified locally in RA11y context; keep validating on physical devices and simulator VoiceOver whenever related screens change.

Related implementation:
- `RA11y-iOS/RA11y-iOS/FirstRun/iOSFirstSpellVoiceOverRequiredView.swift`
- `RA11y-iOS/RA11y-iOS/FirstRun/iOSMagicTapFirstSpellView.swift`
- `RA11y-iOS/RA11y-iOS/FirstRun/iOSBasicsSequenceView.swift`
- `RA11y-iOS/RA11y-iOS/Games/iOSDungeonResonancePlayView.swift`
- `RA11y-iOS/RA11y-iOS/Games/iOSResonanceVoiceOverScrollProxyRepresentable.swift`

Related research:
- `memlog/research/CrystalResonance-VoiceOverScrollProxy-Investigation.md`
- `memlog/research/CrystalResonance-Asset-And-Scroll-QC.md`

### Problem

RA11y repeatedly hit the same class of VoiceOver problem in different forms: the screen visually had the right content, but VoiceOver did not land on, read, or operate the intended next interaction surface.

In the First Spell onboarding gate, the user could turn VoiceOver on and return to a cluttered page that still exposed enablement controls. The useful action was "Continue to First Spell", but the interface did not make that action the clear next VoiceOver target.

In VoiceOver Basics, the current skill card needed to be read as the current task, and Magic Tap needed to start the current trial without requiring a second "Begin" button. The UX also still needed to expose completed and locked trials clearly, because those states explain the learning path and allow replay of previous trials.

In Crystal Resonance, the quest needed VoiceOver users to operate a specific vertical scroll interaction. The visual game lane existed, but VoiceOver gestures did not reliably operate the intended scroll surface when focus landed elsewhere or when SwiftUI's scroll hierarchy did not expose the expected accessible element.

### Context That Influenced The Issue

VoiceOver focus is stateful. A screen is not done just because the right text exists visually or because the app posts speech. The user needs a reachable accessibility element with a stable label, trait, hint, and action behavior at the moment focus is moved.

The following context mattered:

- VoiceOver can be enabled outside the app and then the user returns to a changed onboarding state.
- SwiftUI focus targets only work after the target accessibility element exists in the rendered view hierarchy.
- `UIAccessibility.post` can move attention after a screen or layout change, but a speech announcement by itself does not prove that linear swipe navigation, double tap, Magic Tap, or three-finger scroll will operate the desired surface.
- VoiceOver gestures are interpreted relative to the current accessibility focus and the scrollable/accessibility ancestors around it.
- Magic Tap is a global/contextual VoiceOver gesture for the current action. In RA11y, it should map to the lesson's current primary action, not only to whichever visible button happens to be focused.
- Teaching screens need both a visual path model and a VoiceOver path model. Removing all locked/completed context can make the UI feel simpler, but it can also erase important orientation about where the learner is in the sequence.

### What Does Not Work Reliably

- Do not leave "Open Accessibility Settings", "How to Enable VoiceOver", Siri instructions, and confirmation controls active after VoiceOver is already on. That creates a stale task surface and makes focus compete with the next real action.
- Do not auto-advance immediately when VoiceOver turns on. The user just changed an assistive technology mode and deserves a stable confirmation point before continuing.
- Do not rely on an announcement alone as the proof that a screen is accessible. Announcements can speak useful text while focus remains on the wrong element or an unusable element.
- Do not hide the required interaction behind decorative SwiftUI layers or invisible hit areas. VoiceOver needs a real semantic surface to focus and operate.
- Do not assume `accessibilitySortPriority` can rescue a complicated hierarchy if the core focusable elements, grouping, and scroll ownership are wrong.
- Do not assume a SwiftUI `ScrollView` is sufficient for a training task whose success depends on VoiceOver three-finger scroll operating one specific surface. Crystal Resonance showed that a real UIKit `UIScrollView` proxy was the more reliable interaction surface for that lesson.
- Do not add duplicate visible buttons for an action that should be the screen-level Magic Tap action. Extra controls make the task harder to understand and increase the chance of focus landing on the wrong element.

### What Works

- When VoiceOver becomes enabled on the required-gate screen, collapse the UI to the current state and one next action: status text plus "Continue to First Spell".
- Move VoiceOver focus to that Continue button after the view updates. The button should have a clear label and hint, for example: "Continue to First Spell" and "Double-tap to continue."
- Use semantic controls for actions. A SwiftUI `Button` with an accessibility label and hint is more robust than a gesture attached to a decorative view.
- Use `@AccessibilityFocusState` / `.accessibilityFocused` when the focused SwiftUI element is present and stable. This lets the app both observe focus changes and request focus on the intended element.
- Use `UIAccessibility.post(.screenChanged, argument:)` when a new major view appears, and `UIAccessibility.post(.layoutChanged, argument:)` when the current screen changes enough that VoiceOver should move to a new element. Pass the target element when practical.
- Avoid redundant announcements that speak over or duplicate the focused element's label and hint. The best result is usually one clear focus move, not a focus move plus a second spoken sentence.
- For Magic Tap lessons, attach `.accessibilityAction(.magicTap)` at the screen or lesson container that owns the current primary action. In First Spell, the same gesture can first learn the spell and then continue the basics. In Basics, Magic Tap can start the selected playable trial, defaulting to the current trial.
- For a required VoiceOver scroll training surface, expose the actual surface VoiceOver should operate. In Crystal Resonance, the best-fit implementation was a UIKit `UIScrollView` wrapped in SwiftUI, with a stable accessibility identifier, label, hint, content height, and scroll offset reporting.

### Best-Fit UX And Implementation Model

Design every RA11y VoiceOver teaching screen as four explicit surfaces:

1. Orientation: what screen or lesson the user is on.
2. Current objective: what they are expected to do now.
3. Primary action: the one action Magic Tap and the main focused control should perform.
4. Practice surface: the actual accessible element or control the user must operate to learn the skill.

The focus model should follow the user's task:

- On first entry to a lesson, focus the current objective or the current playable card if that is the action surface.
- After a state transition, focus the next actionable control only after the layout has settled.
- When VoiceOver has just been enabled, keep the user on a stable confirmation action rather than auto-navigating.
- When a lesson requires a specific gesture, the focused element's hint should name the gesture and outcome.
- When Magic Tap is part of the lesson, the screen-level Magic Tap action should perform the same current primary action that the visual UI communicates.
- Keep completed and locked future trials visible when they provide orientation, but make their VoiceOver labels explicit: completed, current, locked, or unavailable.

For Crystal Resonance specifically, the interaction surface matters more than visual resemblance. The accessible scroll lane must be the object VoiceOver can focus and scroll. Visual art can sit around it, but the lane itself needs to be the semantic contract.

### Verification Checklist

Run these checks whenever a screen changes focus behavior, Magic Tap behavior, or a VoiceOver-specific interaction surface:

- With VoiceOver off, enter the screen and verify the standard visual flow still works.
- Turn VoiceOver on from outside the app if the screen supports that path, return, and verify stale enablement controls are gone.
- Confirm the intended element receives VoiceOver focus without requiring exploratory swipes.
- Confirm VoiceOver reads the element label and hint in a useful order.
- Swipe right and left through the screen and confirm the order matches the task model.
- Double-tap the focused primary action and verify the same behavior a sighted tap would trigger.
- Perform Magic Tap and verify it triggers the current primary action, unless the user intentionally selected a different playable previous trial.
- For locked items, confirm VoiceOver says they are locked or unavailable and does not start the trial.
- For scroll lessons, put focus on the named scroll surface and verify three-finger scrolling moves the intended content across the required range.
- Re-enter the screen after navigation and confirm focus does not land on a stale or hidden element.

### Sources

- Apple Developer Documentation, `accessibilityFocused(_:)`: SwiftUI can bind accessibility focus to state, and setting that state programmatically moves focus to the modified accessibility element. https://developer.apple.com/documentation/swiftui/view/accessibilityfocused%28_%3A%29/
- Apple Developer Documentation, `UIAccessibility.Notification`: apps can post `announcement`, `layoutChanged`, `screenChanged`, and `pageScrolled` notifications to assistive apps. https://developer.apple.com/documentation/uikit/uiaccessibility/notification
- Apple Developer Documentation, `AccessibilityNotification.LayoutChanged`: a layout-changed notification may include an accessibility element for VoiceOver to move to after processing the notification. https://developer.apple.com/documentation/accessibility/accessibilitynotification/layoutchanged
- Apple Developer Documentation, SwiftUI accessibility actions: accessibility actions allow assistive technologies such as VoiceOver to invoke actions, including action kinds such as `magicTap`. https://developer.apple.com/documentation/swiftui/view-accessibility
- Apple Support, VoiceOver gestures on iPhone: VoiceOver changes standard touchscreen gestures; swipe right selects the next item, double tap activates, two-finger double tap starts or stops the current action, and three-finger gestures participate in VoiceOver navigation. https://support.apple.com/en-lamr/guide/iphone/use-voiceover-gestures-iph3e2e2281/26/ios/26

### Open Follow-Ups

- Add a small repeatable manual QA script for onboarding VoiceOver handoff: VoiceOver off entry, settings/Siri enablement, return, focus target, hint, double tap, Magic Tap.
- Consider whether future VoiceOver lessons should expose a shared "current primary action" model so the visible button, Magic Tap, and VoiceOver hint cannot drift apart.
- Keep extending this log when a screen looks correct visually but fails because focus ownership, gesture routing, or semantic surface ownership is wrong.
