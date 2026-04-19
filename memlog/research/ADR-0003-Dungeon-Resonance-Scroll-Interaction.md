# ADR-0003: Dungeon Descent v2 as Resonance-Based Scroll Alignment

Date: 2026-04-19
Status: Proposed

## Context

The current Dungeon Descent implementation teaches vertical scrolling through a stacked
room-list metaphor. That approach is serviceable, but it is weaker than the rest of
RA11y's game language for three reasons:

1. It reads as standard list navigation rather than a deliberate skill mechanic.
2. It is more prone to responsive-layout issues because the screen is composed of
   large cards, room rows, HUD chrome, and explanatory copy in one vertical stack.
3. It does not take advantage of haptics and sound as first-class feedback channels,
   which limits how well the mechanic can scale into Lights Off mode.

Recent design discussion converged on a more direct metaphor: the player scrolls to
align a moving magical target with a fixed orb or reticle at the center of the screen.
As alignment improves, the orb's resonance becomes clearer through sound, haptics,
and visual response.

This maps more naturally to the skill being taught:
- a three-finger vertical scroll moves content relative to a fixed point,
- the player learns spatial positioning rather than list traversal,
- activation occurs only when the target is correctly aligned,
- Lights Off mode can shift emphasis from visual cues to haptics and sound without
  changing the core mechanic.

The design discussion also surfaced an important production constraint for assets:
image generators perform poorly when asked to produce multiple related sprites in one
prompt. They tend to return multi-object canvases, collage sheets, or compositions
with inconsistent scale. That is not acceptable for app ingestion. Each asset must be
specified and generated independently.

## Decision

Adopt a new design direction for Dungeon Descent based on resonance-guided scroll
alignment.

The mechanic will be framed as:
- a fixed orb or reticle at screen center,
- a vertical target lane that moves under the reticle when the player scrolls,
- a target object or glyph that becomes actionable only when aligned,
- multimodal feedback where haptics convey proximity, sound conveys resonance
  quality, and VoiceOver carries sparse semantic confirmation.

This decision is design-directional rather than implementation-final. It locks the
interaction metaphor, feedback model, and asset-generation strategy so future UI,
mockups, and prompts remain aligned.

## Core Interaction Model

### Base mechanic

1. The center of the screen contains a fixed orb, crystal sight, or reticle.
2. The dungeon lane moves vertically in response to scroll gestures.
3. Distance from the target to the reticle defines the gameplay state.
4. Activation becomes available only within a tight alignment window.
5. Double-tap confirms the aligned target.

## Accessibility Model

The resonance mechanic must remain compatible with VoiceOver's focus model rather
than competing with it.

### Baseline accessibility structure

- The fixed orb / reticle region is the primary semantic anchor on screen.
- The moving dungeon lane is treated as gameplay content, not as a large set of
  independently focusable visual objects.
- Decorative lane markers and non-aligned decoys should be hidden from the
  accessibility tree unless implementation testing proves an aligned target needs
  an explicit temporary accessibility element.
- VoiceOver focus should remain stable on the tutorial/objective/status region while
  scroll gestures move the world underneath it.
- The mechanic must not require the player to swipe through a dense list of lane
  objects in order to play.

### VoiceOver guidance model

- VoiceOver carries instructions, sparse state changes, and target identity.
- Continuous hotter/colder narration is out of scope for the default experience.
- If an aligned state is announced, it should be brief and rate-limited.

### Lights Off accessibility rule

- Lights Off must preserve a visible focal anchor: the center orb and reticle remain
  visible even when the environment is darkened.
- The lane/world may be reduced to spotlight-only or near-black treatment, but the
  player must retain a stable center reference.

### Feedback roles

- Haptics: proximity and lock confirmation.
- Sound: resonance quality, from rough or detuned to clear and stable.
- VoiceOver: instructions, state changes, target identity, and optional aligned
  confirmation.
- Visuals: thematic presentation and clear read of current alignment state.

### Recommended state ladder

1. Far
   - target visibly away from reticle
   - faint unstable orb glow
   - little or no haptic feedback
   - low, rough, or muffled resonance

2. Warm
   - target entering proximity band
   - soft haptic pulses
   - orb glow intensifies slightly
   - resonance roughness decreases

3. Near
   - target close to reticle
   - clearer glow ring or lane highlight
   - slightly faster or firmer haptic cue
   - resonance becomes cleaner and brighter

4. Locked
   - target inside activation window
   - crisp alignment haptic
   - stable clear resonance tone or short held note
   - optional VoiceOver confirmation such as "Aligned"

5. Success
   - short magical flourish
   - success haptic
   - result transition

## Wrong Activation Model

Wrong-target behavior is part of the teaching loop and must be explicit.

### Default wrong-action rules

- A wrong activation increments mistakes.
- A wrong activation produces a distinct error haptic and short dissonant or dull
  audio cue.
- Wrong targets do not enter the same "locked" state vocabulary as the correct
  target; the game should not imply a decoy is valid simply because it is centered.
- VoiceOver copy should reinforce the objective without excessive verbosity, for
  example: "Not the Moonstone."

### Cooldown constraint

- Any wrong-action cooldown must remain short and instructional.
- The player should be able to resume scrolling immediately after the feedback cue.
- The game should not punish experimentation with long lockouts.

## Lights Off Strategy

Lights Off should preserve the same mechanic while removing reliance on wide-field
visual reading.

### Preferred Lights Off version

- Keep the center orb visible.
- Reduce environmental visibility to a narrow spotlight or near-black field.
- Preserve the same vertical scrolling behavior.
- Make haptics and sound primary guidance channels.
- Use VoiceOver only for sparse confirmations rather than constant warmer/colder
  narration.

### Why this is stronger than the current room-list pattern

- It scales into audio-first play without rewriting the mechanic.
- It teaches confidence in nonvisual positioning.
- It avoids a visually dense layout that can become fragile on different screens.

## Teaching Progression

This redesign is not only an art change; it is a curriculum change.

### Expected progression levers

- L0: wide alignment band, one target, explicit tutorial messaging
- L1: narrower band, one target plus a small number of decoys
- L2: more decoys and/or faster scan expectation, optional timer
- L3 / Lights Off: reduced visual context, heavier reliance on haptics and sound

The exact thresholds remain implementation work, but the progression should narrow
the alignment window and reduce visual support over time.

## Sound Design Decision

The preferred audio metaphor is "align the resonance of the crystal orb."

### Accepted audio model

- Misalignment sounds rough, unstable, filtered, or beating.
- Alignment sounds pure, stable, and harmonically resolved.
- The player is taught to "listen for the clear note."

### Practical guidance

- Avoid constant loud continuous tones.
- Update sound on meaningful position changes or debounced settle moments.
- Prefer timbre and stability change over pitch-only guidance.
- Keep custom audio short and compatible with VoiceOver ducking.

## Haptics Decision

Haptics are part of the core mechanic, not a decorative add-on.

### Haptic roles

- Proximity cue when entering the warm/near band.
- Crisp lock cue when the target becomes actionable.
- Distinct error cue for incorrect activation.
- Reward cue on success.

### Constraint

Do not use constant vibration while scrolling. Haptics must remain eventful and
learnable.

## Asset Generation Decision

All new Dungeon v2 assets must be generated one asset per prompt.

### Hard requirements

- Never request multiple sprites or glyphs in a single generation prompt.
- Every glyph or sprite intended for compositing must have a transparent background.
- Backgrounds are generated separately from glyphs and overlays.
- The prompt sheet must specify filename, role, output size, transparency rules,
  and composition constraints for each asset independently.

### Rationale

Atomic asset generation reduces:
- unwanted sprite sheets,
- inconsistent scale between icons,
- background contamination behind glyphs,
- unnecessary large canvases that complicate ingestion and cropping.

Companion prompt specification:
- `memlog/requirements/Design/DesignTicket-DungeonResonancePromptSheet.txt`

## Consequences

### Positive

- Stronger gesture-to-feedback mapping.
- Better thematic coherence with magical training and dungeon fantasy.
- More robust path into Lights Off mode.
- Cleaner support for haptics and sound.
- Less dependence on dense vertical card layouts.
- Better promptability for asset generation.

### Costs

- Requires new mockups and likely new assets.
- Requires audio/haptic tuning to avoid fatigue.
- Requires accessibility review to ensure VoiceOver and custom feedback coexist well.
- May require redesign of current Dungeon screenshot coverage and tutorial copy.

## Relationship to Existing Dungeon Spec

This ADR proposes a Dungeon Descent v2 interaction direction that supersedes the
current room-list metaphor as the preferred future design direction.

Until implementation formally migrates, `GameSpec-ScrollHunt.txt` remains the
current shipped gameplay spec. Once implementation starts, the requirements docs
must explicitly state whether:

- Dungeon v2 replaces the existing Scroll Hunt flow entirely, or
- Dungeon v2 first replaces only L0-L1 while later levels remain on the legacy flow.

The repository must not retain two equally authoritative Dungeon interaction specs
without a clear transition note.

## Screenshot and Automation Impact

If this direction moves into implementation, the screenshot automation contract must
be updated alongside the UI:

- `RA11y-iOS/RA11y-iOS/App/iOSScreenshotScene.swift`
- `RA11y-iOS/RA11y-iOSUITests/RA11y_iOSScreenshots.swift`
- `RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md`
- `fastlane/Fastfile`

Expected changes include new scene IDs, updated root anchors, and new screenshot
coverage for the resonance tutorial, active alignment play state, and Lights Off or
result states as appropriate.

## Design prototype (SwiftUI mockup)

An interactive **design-time** mockup ships in the iOS target (not routed in
`AppRoute`; open from SwiftUI Previews):

- `RA11y-iOS/RA11y-iOS/Games/iOSDungeonResonanceMockupView.swift`

It demonstrates the fixed center orb + reticle, scrollable lane with moonstone and
decoy stand-ins, geometry-driven distance-to-aim (live resonance band), manual band
override for Far–Success reviews, and a Lights Off vignette preview. Use it to
iterate on layout and thresholds before implementation and to refine the companion
prompt sheet and requirements.

## Follow-on Requirements

1. Update Dungeon requirements/spec docs if this direction is adopted for implementation.
2. Produce a dedicated Dungeon v2 prompt sheet with one prompt per asset.
3. Decide which elements are code-drawn versus image-driven.
4. Define feedback thresholds for far, warm, near, and locked states.
5. Add a Lights Off-specific design note for audio-first play.

## Non-Goals

This ADR does not:
- lock exact sound assets or haptic APIs,
- require immediate implementation,
- require replacing all existing Dungeon art at once,
- define final timing thresholds for resonance bands.

## Acceptance Criteria for This ADR

This ADR should move from `Proposed` to `Accepted` only when all of the following
are true:

1. Product/design agree that the resonance model replaces the room-list metaphor as
   the primary Dungeon direction.
2. Accessibility review confirms the VoiceOver model is coherent alongside custom
   haptics and sound.
3. At least one mockup or prototype demonstrates the fixed-orb alignment loop.
4. The companion design prompt sheet is accepted as the source of truth for v2 asset
   generation.

Accepting roles:
- Product
- Design
- Engineering
- Accessibility review
