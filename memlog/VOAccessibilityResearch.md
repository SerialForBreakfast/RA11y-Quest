# VoiceOver Accessibility Research Playbook

Portable principles for accessible UI/UX design and implementation learned through iterative product work. This document is intentionally non-project-specific and focuses on reusable rules, failure patterns, context analogs, and verification methods.

## Scope

- Platform focus: iOS VoiceOver behavior in app UI flows.
- Goal: preserve generalized, transferable practice rather than product-specific history.
- Use this as a design and QA companion when building onboarding, guided learning flows, gesture practice, and task-driven interfaces.
- Add new findings as portable entries. Name the context clue explicitly instead of naming the original feature that exposed the issue.

## Core Principle

VoiceOver success is a **semantic interaction contract**, not a visual layout or spoken announcement.

A screen is accessible only when a user can:
- Reach the intended element with predictable focus order.
- Understand what that element is and what action it performs.
- Execute the action with expected gestures.
- Recover from mistakes without losing orientation.

## Relative Analog Context Clues

Use these explicit analogs when mapping specific UI issues into general patterns.

- **Analog A: Train Platform Handoff**  
  User arrives after changing accessibility mode externally. The platform must expose one stable next action, not a crowded set of stale setup controls.

- **Analog B: Control Tower Console**  
  Multiple visual controls exist, but one control currently owns the task-critical action. Focus and gesture routing must privilege that control.

- **Analog C: Single-Lane Gesture Surface**  
  A task depends on one exact interaction surface (for example, a scroll lane). Decorative or layered views must not intercept focus or gestures.

- **Analog D: Action Stack Selector**  
  One focused element supports default activate plus custom actions. Users must deliberately choose the active action before double-tap.

- **Analog E: State Transition Airlock**  
  After major state changes, delay focus movement until target elements exist and layout has settled.

- **Analog F: Progress Map Orientation**  
  Users need current/complete/locked status semantics to stay oriented. Simplification that removes state cues can reduce accessibility.

## General Rules That Survive Iteration

### 1) Focus is authoritative

- Treat focus destination as a product decision, not an implementation side effect.
- Focus movement must map to user intent and current objective.
- Never assume an announcement proves usability; verify focus and action execution.

### 2) One primary action at a time

- Each step should expose one clear next action.
- Remove or de-emphasize stale actions once the state changes.
- Avoid duplicate controls for the same action when one gesture pathway is preferred.

### 3) Prefer semantic controls over gesture hacks

- Use native semantic controls and accessibility traits first.
- Avoid attaching core behavior only to decorative layers or ambiguous hit targets.
- Use custom gesture handling only when semantic controls cannot represent the task.

### 4) Match gesture model to lesson model

- If a flow teaches a specific gesture, the focused element hint must name the expected gesture and outcome.
- Global/contextual gestures (for example Magic Tap) should trigger the same current primary action implied by visible UI and focus.
- Do not require users to infer hidden gesture ownership.

### 5) Make interaction surfaces explicit

- For gesture-dependent tasks, expose one named, focusable surface that truly owns the behavior.
- If SwiftUI hierarchy behavior is unreliable for that requirement, bridge to a UIKit surface that provides deterministic focus and gesture handling.
- Keep decorative content visually rich but semantically secondary.

### 6) Keep copy behavior-oriented, not string-dependent

- Teach interaction patterns and user intent ("select the ordinary action"), not brittle verbatim system strings.
- Assume system-owned language can vary by locale, OS version, and control type.
- Reserve exact string checks for telemetry/debugging, not user learning dependency.

### 7) Preserve orientation semantics

- Maintain explicit state semantics for steps or modules: current, completed, locked, unavailable.
- Do not hide orientation structure if it helps users plan and recover.
- Order and grouping should reflect task flow, not visual decoration order.

### 8) Design for recovery

- Wrong action should yield clear outcome feedback tied to user-observable results.
- Provide retry loops without disorienting focus jumps.
- Avoid punitive loops that require rediscovering context from scratch.

## Current Findings

## 2026-04-30 - Focus And Current Action Ownership

Status: Verified pattern
Portability: Cross-Flow Pattern

### Problem Pattern

A screen can look visually correct while VoiceOver users remain blocked because focus, spoken output, and gesture ownership do not point to the same current task.

This usually appears after one of three moments:

- A user changes assistive technology state outside the app and returns.
- A guided flow advances from instruction into practice.
- A gesture-specific task depends on one exact interactive surface.

### Relative Analog Context Clue

- **Analog A: Train Platform Handoff** applies when the user returns after enabling or changing an accessibility mode. The screen should become a stable handoff point with one next action, not a setup page with stale controls.
- **Analog B: Control Tower Console** applies when many controls or cards are visible but one currently owns the task. Focus and contextual gestures should route to that control unless the user deliberately chooses another eligible control.
- **Analog C: Single-Lane Gesture Surface** applies when success depends on operating a specific scroll, drag, or gesture area. That surface must be the semantic owner of the interaction, not just a visual region.
- **Analog E: State Transition Airlock** applies when UI state changes before the accessibility tree is ready. Focus should move only after the target element exists and layout is stable.
- **Analog F: Progress Map Orientation** applies when locked, complete, and current states help the user understand position in a sequence. Removing those states may simplify visuals while weakening nonvisual orientation.

### What Fails

- Speaking an announcement without moving focus to a usable element.
- Moving focus before the target element exists or before state-driven layout has settled.
- Leaving stale setup controls active after the user has completed the setup condition.
- Adding a duplicate visible button for an action that should be the screen's contextual primary action.
- Relying on visual grouping, decorative layers, invisible overlays, or sort priority to compensate for an unclear semantic hierarchy.
- Expecting a gesture to operate the intended surface when VoiceOver focus is on a different element or ancestor.
- Hiding future or unavailable steps when those states are part of the user's mental map.

### What Works

- Collapse completed setup UI into a clear confirmation state and one primary next action.
- Move focus to the next actionable element after the UI state has settled.
- Give the focused element a behavior-oriented label and hint that state what the user can do next.
- Keep the visual primary action, VoiceOver focus target, and contextual gesture action aligned.
- Expose one named, focusable practice surface for gesture-dependent tasks.
- Preserve current, complete, locked, and unavailable states when they help orientation, but make those states explicit in accessibility labels, values, or hints.
- Verify with actual VoiceOver gestures: next/previous navigation, double tap, contextual action, and any required scroll or gesture operation.

### Generalized Rule

VoiceOver focus is the operating contract. Announcements can supplement that contract, but the user must be able to land on the right semantic element, hear the right instruction, and perform the right action from that focus position.

### Verification Evidence

A focus/action fix is not complete until all of these pass:

1. First focus lands on the intended current task or primary action.
2. The focused element's label, value, trait, and hint explain the next step.
3. Swipe order follows the task sequence.
4. Double tap activates the expected primary control.
5. The contextual/global gesture activates the same current primary action when applicable.
6. Gesture-specific practice operates the intended semantic surface.
7. Re-entry after state change does not expose stale controls or focus hidden elements.

### Sources

- Apple Developer Documentation, `accessibilityFocused(_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityfocused%28_%3A%29/
- Apple Developer Documentation, `UIAccessibility.Notification`: https://developer.apple.com/documentation/uikit/uiaccessibility/notification
- Apple Developer Documentation, `AccessibilityNotification.LayoutChanged`: https://developer.apple.com/documentation/accessibility/accessibilitynotification/layoutchanged
- Apple Developer Documentation, SwiftUI accessibility actions: https://developer.apple.com/documentation/swiftui/view-accessibility
- Apple Support, VoiceOver gestures on iPhone: https://support.apple.com/en-lamr/guide/iphone/use-voiceover-gestures-iph3e2e2281/26/ios/26

## Anti-Patterns To Avoid

- Announcement-only accessibility verification.
- Auto-advance immediately after assistive mode changes.
- Overreliance on sort-priority tuning to fix a broken semantic hierarchy.
- Multiple active controls that compete with the current objective.
- Gesture-critical tasks implemented on surfaces VoiceOver cannot reliably focus.
- Teaching that depends on fixed wording for system-owned labels.

## Reusable UX Model (Task-Centered Accessibility Surface)

Design each step with four explicit surfaces:

1. **Orientation Surface**: where the user is.
2. **Objective Surface**: what to do now.
3. **Primary Action Surface**: the action to execute now.
4. **Practice Surface**: the exact semantic element the user must operate.

If any surface is missing, accessibility regressions are likely.

## Verification Protocol (Portable QA)

Run this checklist after any change to focus, actions, gesture handling, or state transitions:

1. Enter flow with VoiceOver off; verify visual baseline still works.
2. Toggle VoiceOver externally and re-enter; verify stale setup controls do not remain active.
3. Confirm first focus lands on intended element without exploratory swipes.
4. Confirm label, value, trait, and hint read in useful order.
5. Swipe next/previous through elements and verify traversal matches task flow.
6. Execute primary action via double-tap and confirm expected state change.
7. Execute contextual/global action (for example Magic Tap) and confirm it maps to current primary action.
8. Verify locked/unavailable states are announced and non-activating.
9. For scroll or gesture-specific tasks, verify required gesture operates the intended surface across full range.
10. Re-enter flow and verify no focus lands on hidden/stale elements.

## Implementation Notes (iOS/SwiftUI)

- Use `@AccessibilityFocusState` / `.accessibilityFocused` for explicit focus control when the target element is rendered and stable.
- Use `UIAccessibility.post(.screenChanged, argument:)` for major screen entry and `UIAccessibility.post(.layoutChanged, argument:)` for intra-screen structural changes; provide the target element when possible.
- Keep announcement usage minimal and non-duplicative of focused control speech.
- Use `.accessibilityAction(.magicTap)` at the container that owns the current primary action.

## Entry Template For New Findings

```markdown
## YYYY-MM-DD - Short Finding Title

Status: Draft | Verified | Replaced
Portability: Local Pattern | Cross-Flow Pattern | Platform-Level Pattern

### Problem Pattern
Describe the user-facing failure in generalized terms.

### Relative Analog Context Clue
Choose one or more: Analog A-F (or define a new analog with explicit naming).

### What Fails
List approaches that were unreliable.

### What Works
List implementation and UX patterns that passed testing.

### Generalized Rule
State one portable rule that future work can apply.

### Verification Evidence
Record gesture, focus, and outcome checks used to validate behavior.

### Sources
Primary platform docs or validated references.
```

## Sources

- Apple Developer Documentation, `accessibilityFocused(_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityfocused%28_%3A%29/
- Apple Developer Documentation, `UIAccessibility.Notification`: https://developer.apple.com/documentation/uikit/uiaccessibility/notification
- Apple Developer Documentation, `AccessibilityNotification.LayoutChanged`: https://developer.apple.com/documentation/accessibility/accessibilitynotification/layoutchanged
- Apple Developer Documentation, SwiftUI accessibility actions: https://developer.apple.com/documentation/swiftui/view-accessibility
- Apple Support, VoiceOver gestures on iPhone: https://support.apple.com/en-lamr/guide/iphone/use-voiceover-gestures-iph3e2e2281/26/ios/26
