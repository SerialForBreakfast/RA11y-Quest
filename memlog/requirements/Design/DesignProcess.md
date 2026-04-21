RA11y — Quest Design Process
=============================

Date: 2026-04-19
Owner: Product / Design / Engineering
Status: Canonical

This document defines the repeatable end-to-end workflow for every accessibility
quest in RA11y. Follow the phases in order. Each phase has explicit outputs and
acceptance gates before the next phase begins.

---

Phase 0 — Pedagogy & Curriculum Fit
=====================================

Before any design or code work begins, answer these four questions in writing:

1. What is the single VoiceOver or accessibility skill being taught?
2. What is the one-sentence lesson (the "aha" moment the player must have)?
3. What prior skills does this quest depend on?
4. What downstream skills does this quest unlock?

Rule: Every quest teaches exactly one paradigm shift. If two distinct skills are
required to complete the quest, the quest is two quests.

Stage Structure
---------------
All quests follow a three-stage arc. No more, no fewer.

  Stage 1 — Practice
    No timer. Visual hints visible. Minimal complexity.
    Goal: confidence. Player performs the gesture correctly at least once.
    No rank awarded.

  Stage 2 — Trial
    Hard timer. No hints. Full complexity.
    Goal: mastery under pressure. Rank awarded here.

  Stage 3 — Lights Off
    Hard timer. No visual cues. Screen darkened.
    Goal: prove the skill is internalised. Player relies entirely on
    VoiceOver announcements, haptics, and audio.
    Rank awarded separately.

Output: a plain-text one-pager covering skill, one-sentence lesson,
stage descriptions, and wrong-action behaviour. File as:
  memlog/requirements/Design/QuestConcept-[QuestName].txt

---

Phase 1 — ADR (Architecture Decision Record)
=============================================

Write an ADR before any UI is designed. The ADR locks the interaction model
so mockups, specs, and prompts stay aligned.

Required ADR sections:
  - Context: why this mechanic, what prior approach it supersedes
  - Decision: the core interaction model (gestures, states, feedback model)
  - Accessibility model: VoiceOver structure, focus behaviour, announcement rules
  - Lights Off strategy
  - Feedback roles: haptics / sound / VoiceOver / visuals and what each carries
  - State ladder: named states (e.g. Far / Warm / Near / Locked) with behaviour
  - Wrong-action model
  - Asset generation decision: what is code-drawn vs image-driven
  - Consequences: positive and costs
  - Acceptance criteria for the ADR itself

File as:
  memlog/research/ADR-[NNNN]-[QuestName]-[ShortDescription].md

The ADR moves from Proposed to Accepted only when Product, Design, Engineering,
and Accessibility review have all signed off.

---

Phase 2 — Game Spec
====================

Write the GameSpec after the ADR is accepted. The spec is the authoritative
source of truth for implementation.

Required GameSpec sections:
  - Game ID and canonical name
  - One-sentence lesson
  - Prerequisites (which quests must be completed first)
  - Stage structure (3 stages per above)
  - Per-stage: timer, element count, hint visibility, wrong-action feedback
  - Scoring: metrics tracked, rank thresholds, tie-breaking rules
  - Rank copy (Legendary / Skilled / Novice / Defeated with thematic flavour)
  - VoiceOver announcement schedule (what fires, when, rate limits)
  - Haptic schedule (which generator, which stage, what event triggers it)
  - Audio cue schedule (what plays, when, ducking rules)
  - Lights Off specification (what remains visible, what is audio/haptic only)
  - Wrong-action cooldown rules
  - Hint text per stage
  - Asset references (forward-link to prompt sheet)

File as:
  memlog/requirements/GameSpec-[QuestName].txt

---

Phase 3 — UX Mockup
====================

Build an interactive HTML mockup before any SwiftUI is written. The mockup
exists to validate layout, state transitions, and the visual logic of the
mechanic. It is not a prototype — it is a design communication tool.

Setup
-----
  - All mockup files live inside the project:
      memlog/requirements/Design/Mockups-v2/
  - NEVER write mockup files outside the project directory.
  - The preview server is configured in .claude/launch.json:
      python3 -m http.server 7331 --directory memlog/requirements/Design/Mockups-v2
  - Access at: http://localhost:7331/[mockup-filename].html

Mockup structure requirements
------------------------------
  - iPhone shell at 390px width (standard iPhone frame)
  - State tabs for every named state (e.g. Far / Warm / Near / Locked)
  - All state content driven from a JS data object — no static HTML content
    that diverges from the data source. Call setState() on DOMContentLoaded.
  - CSS custom properties for state-specific visual variables (colours, glow,
    opacity) so state transitions are a single class swap on the phone element
  - A description card below the phone listing the feedback model for each state:
    orb/visual behaviour, haptic, audio, VoiceOver announcement
  - Edge fades on scrollable play areas to imply content above/below viewport

Component identification
------------------------
While building the mockup, identify every distinct visual element and note:
  - Is it a generated image asset or code-drawn?
  - Does it have transparent background or opaque?
  - What is its layer order (back to front)?
  - Does it animate or change per state?
  - What is its approximate point size on device?

This list becomes the asset definition in Phase 4.

Iteration rule
--------------
Iterate until all named states look correct and distinct. Verify each state
by screenshot before signing off. The mockup is complete when:
  - Every state is visually distinguishable at a glance
  - Fixed elements (orb, reticle) are clearly different from moving elements
    (targets, decoys) in both shape and colour
  - The Lights Off state reads correctly using only the centre anchor
  - The locked / success state is unambiguous

File as:
  memlog/requirements/Design/Mockups-v2/[quest_name]_mockup.html

---

Phase 4 — Asset Definition
===========================

After the mockup is stable, define every generated image asset in a prompt sheet
and a pipeline doc.

Naming convention
-----------------
  [quest_prefix]_[role]_[descriptor]

  Quest prefixes:
    enchanter_    dungeon_    banishment_    (new quests follow same pattern)

  Role suffixes:
    _bg           non-transparent background
    _orb_*        fixed centre orb variants
    _reticle_*    aiming ring or frame
    _target_*     correct target object
    _decoy_*      wrong target / distractor
    _marker_*     decorative lane or field element
    _flare_*      success or feedback overlay
    _mask_*       Lights Off / vignette reference

  All names: lowercase snake_case. Stable once adopted — renaming requires a
  coordinated change across asset catalog, Swift string constants, and docs.

Prompt sheet requirements (one file per quest)
----------------------------------------------
  - Global style constraints section included in EVERY individual prompt
  - One entry per asset: filename, role, requirements, prompt
  - Requirements per asset: transparency rule, output size, composition rules,
    what must NOT appear (text, extra objects, UI chrome, watermarks)
  - Generation rules stated explicitly:
      - Generate every asset separately
      - Glyphs and floating objects MUST have transparent backgrounds
      - Backgrounds MUST be generated separately and non-transparent
      - Preferred size: 1024x1024 for transparent glyphs; 2048x4096 portrait
        master for tall backgrounds
      - No sprite sheets, contact sheets, or multi-variation layouts

Generative image tools (LLM / diffusion) — Crystal Resonance
-------------------------------------------------------------
  When commissioning **new** PNGs (not hand-painting), start from the shared
  template of positive/negative constraints and per-asset paragraphs:

    memlog/requirements/Design/CrystalResonance-ImageGen-PromptTemplate.txt

  That file is written for **image generation** prompts only (style, alpha,
  donut reticle, centered wide masters). It does not describe QA scripts or
  Xcode steps. To print the same text in a terminal::

    python3 utility/qa_crystal_resonance_png_assets.py --llm-snippet

  Fold the relevant paragraphs into your quest prompt sheet (Phase 4) per
  filename; keep one generation per asset.

Global style constraints for RA11y (include in every prompt)
-------------------------------------------------------------
  - Painterly flat fantasy illustration consistent with existing RA11y mockups
  - Same world as hub, Enchanter, and Rogue mockups: torchlit stone, warm amber
    light, dark umbers, muted slate blues, golden magical highlights
  - High contrast, readable on phone and tablet
  - Simple large shapes first; controlled detail second
  - No text, letters, numbers, watermark, logo, or UI chrome baked into art
  - Avoid collage layouts and multiple objects in one canvas
  - One asset only per generation
  - Preserve clean edges and clear silhouette at small sizes

Asset pipeline doc requirements (one file per quest)
-----------------------------------------------------
  - Layer stack (back to front) with asset name at each layer
  - Runtime sizing in SwiftUI points (not pixels); use @ScaledMetric where
    appropriate; document min/max clamp values
  - Transparency rules for every asset
  - iPad layout notes (maxWidth cap, centring behaviour)
  - Naming stability note

File prompt sheet as:
  memlog/requirements/Design/DesignTicket-[QuestName]PromptSheet.txt

File pipeline doc as:
  memlog/requirements/Design/[QuestName]AssetPipeline.txt

---

Phase 5 — Asset Generation & Import
=====================================

Generate
--------
  - Use the prompt sheet. One generation per asset. Never batch.
  - Review every output against the QC checklist before accepting.

QC checklist (from DesignTicket-AssetReviewChecklist.txt)
----------------------------------------------------------
  A) Style consistency
     - Flat vector look; clean edges; bold silhouettes
     - No embedded text, letters, numbers, logos, or watermarks
     - Consistent stroke and shape language with other RA11y assets

  B) Accessibility and clarity
     - High contrast against likely backgrounds
     - Meaning does not rely on colour alone (shape cues exist)
     - Avoid low-contrast gradients that degrade under Increase Contrast

  C) Technical quality
     - Transparent sprites: no white fringe, dark fringe, or semi-opaque halo
     - Subject centred with generous padding; no cropping
     - Visual centre of mass balanced for SwiftUI composition
     - File names match the prompt sheet exactly

  D) In-app smoke test
     - Sprite readable at 24-32pt and at 64-96pt
     - Background does not reduce legibility of overlay UI text
     - With largest Dynamic Type: UI text remains readable
     - With Increase Contrast: UI remains legible
     - With Reduce Transparency: overlay panels remain readable

Background removal
------------------
  If generated sprites have white backgrounds instead of transparency:

    python3 utility/remove_white_background.py \
      --allow-large --fuzz 20 --in-place \
      [path/to/sprite.png]

  The --allow-large flag is required for all RA11y assets (source files exceed
  the 1200px default guard). Only run on sprite/glyph assets. Never run on
  background files (*_bg.png or room/environment images).

  Review edges after processing — check for fringing at subject boundary.

Xcode import
------------
  - Place each PNG in Assets.xcassets as a universal imageset (single 1x PNG)
  - Verify Contents.json has "filename" key for every image entry
  - Add @2x / @3x only when sharpness is visibly inadequate; do not rename
    the 1x slot when adding higher-resolution variants

Asset registry test
-------------------
  After import, verify every required asset name resolves from the bundle:
    UIImage(named: assetName) != nil for every name in the prompt sheet.
  This test should be added to the unit test suite and run on every build.

Automated PNG QA (Crystal Resonance lane / hub art)
---------------------------------------------------
  Run from repo root whenever Crystal Resonance PNGs are added, re-exported, or
  batch-normalized::

    python3 utility/qa_crystal_resonance_png_assets.py

  - **FAIL** (exit 1): missing imageset, unreadable file, or **sprite saved as RGB**
    (common cause of grey mats / checkerboard fringes on dark UI in SwiftUI).
  - **WARN**: odd color modes, nearly empty RGBA, possible premultiplied halos
    (use ``--strict-warnings`` in CI if those should fail the job).
  - **Does not replace** on-device checks or VoiceOver scroll QA — see
    ``memlog/research/CrystalResonance-Asset-And-Scroll-QC.md``.

  **Image generation** (what to ask DALL·E, Midjourney, Firefly, etc.) is
  documented in ``CrystalResonance-ImageGen-PromptTemplate.txt`` — not here.
  After assets exist, this Python QA validates files on disk (RGB vs RGBA, etc.).

  **Engineering note:** opaque SwiftUI back-plates behind every lane PNG were
  tried to hide checkerboard; they **regressed** other hub art. Prefer fixing
  **source alpha** (template + ``remove_white_background.py`` / ``ensure_png_rgba.py``).

---

Phase 6 — SwiftUI Implementation
==================================

Component breakdown rule
------------------------
  Decompose the game view into the smallest composable units before writing
  any code. Each component should:
    - Have a single visual responsibility
    - Accept its state as a value type (no internal state for game logic)
    - Be previewable in isolation via #Preview

  Typical component hierarchy for a quest view:
    QuestView (root, owns ViewModel)
    ├── QuestNavBar
    ├── QuestDMCard (dungeon master narration)
    ├── QuestHUD (timer bar + mistakes counter)
    ├── QuestPlayArea (the mechanic itself)
    │   ├── [mechanic-specific subviews]
    │   └── LightsOffOverlay (code-drawn, not image)
    └── QuestStatusStrip (bottom instruction / CTA)

ViewModel pattern
-----------------
  - One @Observable ViewModel per quest
  - Game state as an enum (e.g. .idle / .stage1 / .stage2 / .lightsOff / .result)
  - Stage transitions are pure async functions on the ViewModel
  - Timer lives on the ViewModel; uses Swift structured concurrency (Task +
    continuousClock)

VoiceOver grace period (all timed levels)
-----------------------------------------
  L3-equivalent timed stages must not start the timer while VoiceOver is reading
  navigation announcements. Apply a 5-second grace period:

    if UIAccessibility.isVoiceOverRunning {
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
    }
    startTimer(...)

  This guard goes immediately before startTimer(), after any coordinator or
  monitoring setup. Do NOT use `guard let self, !Task.isCancelled` inside a
  Task closure where self was already unwrapped at the closure top — this
  produces a compiler error. Use `guard !Task.isCancelled` only.

Accessibility model requirements
---------------------------------
  Every quest view must satisfy all of the following:

  - Fixed orb / reticle / anchor: .accessibilityHidden(true) — decorative
  - Moving targets: .accessibilityElement(children: .ignore) with explicit
    label + hint; .accessibilityAddTraits(.isButton) + .accessibilityAction
    for any non-Button view that must be double-tappable
  - No outer container should have .accessibilityLabel / .accessibilityHint
    that would swallow child elements into a single inaccessible group
  - VoiceOver focus must remain stable on the status/objective region while
    game content moves beneath it
  - Decorative images: .accessibilityHidden(true)
  - Timer HUD: single .accessibilityElement group; announce only at threshold
    percentages (75% / 50% / 25% / 10s / 5-4-3-2-1); never per-second

VoiceOver announcement rules
------------------------------
  - Post .screenChanged notification after route resolution completes
  - Rate-limit proximity or state-change announcements (once per state change)
  - No continuous narration during active play
  - Success and failure announcements are always made immediately
  - Use UIAccessibility.post(notification: .announcement, argument: message)
    for in-play state changes

Haptic schedule
---------------
  Stage 1 (practice): no haptics
  Stage 2 (trial):    UIImpactFeedbackGenerator (.light / .medium / .heavy)
                      to signal proximity, lock, error, and success events
  Stage 3 (Lights Off): haptics are primary feedback; CoreHaptics for
                      sustained patterns (rhythmic pulse, escalating tempo)

  Never use continuous vibration during scroll or free play. Haptics must be
  eventful and learnable — each pattern maps to exactly one game event.

Lights Off implementation
--------------------------
  - Darken the world with a code-drawn radial gradient overlay (not a generated
    image) using .background or ZStack layer
  - The centre orb and reticle remain fully opaque above the overlay (z-index)
  - Visual darkness and spotlight treatment apply to the surrounding world/lane
  - The optional dungeon_spotlight_mask_reference asset (if generated) is a
    reference only; implement final mask in code for precision control
  - Lights Off must never remove the focal anchor from view

---

Phase 7 — Screenshot Testing
==============================

Every quest requires screenshot coverage at the following states:
  - Tutorial / Stage 1 (practice, hint visible)
  - Active play — mid-stage (timer visible, elements in play)
  - Locked / success state (CTA or result visible)
  - Lights Off state
  - Result screen (rank displayed)

File locations:
  RA11y-iOS/RA11y-iOS/App/iOSScreenshotScene.swift    (scene ID definitions)
  RA11y-iOS/RA11y-iOSUITests/RA11y_iOSScreenshots.swift (capture calls)
  RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md  (human-readable catalog)
  fastlane/Fastfile                                      (lane configuration)

Steps:
  1. Add scene IDs to iOSScreenshotScene.swift for each new state
  2. Add root anchor routes to the screenshot scene router
  3. Add capture calls to RA11y_iOSScreenshots.swift for each scene ID
  4. Document each scene in ScreenshotRouteCatalog.md with:
       - Scene ID
       - What state it captures
       - Any required setup (pre-navigated state, mock data)
  5. Run fastlane screenshot lane to verify all scenes render without errors

---

Phase 8 — Verification
========================

VoiceOver walkthrough
---------------------
  With VoiceOver enabled, navigate the full quest from entry to result:
    - Every interactive element announces a meaningful label
    - Every hint reads correctly and is not redundant with the label
    - Timer HUD announces only at thresholds, not continuously
    - Wrong-action feedback is heard and distinguishable from success
    - Result screen rank and score are fully accessible
    - Navigating back to hub works without focus loss

Lights Off verification
-----------------------
  - Screen darkened; only orb / reticle / centre anchor visible
  - VoiceOver announcements, haptics, and audio carry all gameplay information
  - Quest is completable with eyes closed
  - Reduce Motion respected (no strobing flare; flare shortened or skipped)

Accessibility settings matrix
-------------------------------
  Run at least one representative screen for each quest against:
    - Largest Dynamic Type size
    - Increase Contrast enabled
    - Reduce Transparency enabled
    - Reduce Motion enabled
    - VoiceOver ON (full walkthrough as above)

Asset registry verification
-----------------------------
  Run the asset registry unit test. Every named asset in the prompt sheet must
  resolve to a non-nil UIImage from the bundle. No silent missing-asset fallbacks
  in shipped builds.

---

Artefact Checklist (per quest)
===============================

Phase 0   QuestConcept-[Name].txt
Phase 1   ADR-[NNNN]-[Name].md
Phase 2   GameSpec-[Name].txt
Phase 3   Mockups-v2/[name]_mockup.html
Phase 4   DesignTicket-[Name]PromptSheet.txt
          [Name]AssetPipeline.txt
          (Crystal Resonance: CrystalResonance-ImageGen-PromptTemplate.txt)
Phase 5   Assets imported to Assets.xcassets
          ``python3 utility/qa_crystal_resonance_png_assets.py`` passing (Crystal Resonance)
          Asset registry unit test passing
Phase 6   Quest SwiftUI implementation
          ViewModel with state machine
          Accessibility model complete
          Haptics and audio wired
          Lights Off overlay implemented
Phase 7   Screenshot scenes added and verified
Phase 8   VoiceOver walkthrough complete
          Accessibility settings matrix checked
          Asset registry test passing in CI

---

Revision History
================
2026-04-21  Phase 5: ``utility/qa_crystal_resonance_png_assets.py`` for on-disk
            PNG checks; ``CrystalResonance-ImageGen-PromptTemplate.txt`` for
            generative **image** prompts (separate from QA).
2026-04-19  Initial version. Derived from Dungeon Resonance v2 design process,
            existing DesignTicket conventions, ADR-0003, and observed patterns
            from Enchanter, Rogue, and Crystal Resonance quest development.
