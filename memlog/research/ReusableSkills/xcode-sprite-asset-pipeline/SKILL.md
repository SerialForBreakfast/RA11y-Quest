---
name: xcode-sprite-asset-pipeline
description: Produce professional PNG sprite/background assets and Xcode .imageset folders from app mockups, with traceable prompts, transparent-background requirements, sizing, and QA gates.
---

# Xcode Sprite Asset Pipeline Skill

Use this skill when a project needs to turn visual mockups, concept screens, or
design briefs into individual PNG assets for an iOS, tvOS, or macOS Xcode asset
catalog.

The skill is optimized for fantasy/game UI assets, but the workflow is portable
to any app that needs extracted sprites, backgrounds, icons, props, state
overlays, or reusable visual elements.

## Core Principle

Mockups define composition and style. They are not the final asset source unless
the user explicitly accepts a bootstrap crop.

Final shippable art should be authored as individual assets:

- one subject per file,
- no UI chrome baked into sprites,
- transparent background for composited sprites,
- opaque background for full-screen backgrounds,
- stable snake_case names,
- exact Xcode `.imageset` output,
- QA before integration.

## Inputs

Gather these before generating or importing assets:

- Mockup PNGs or screenshots showing the desired experience.
- Existing prompt sheet or design brief, if present.
- Existing app asset catalog path, usually `App/Assets.xcassets`.
- Target platform and expected use:
  - full-bleed background,
  - sprite/prop,
  - hub thumbnail,
  - visual effect/flare,
  - reticle/mask/overlay,
  - icon.
- Existing naming convention and runtime asset constants.
- Required output sizes.

If no asset list exists, create a short asset registry before generating images.

## Asset Registry

Create or update a registry with one row per asset.

Required columns:

| Field | Meaning |
|---|---|
| `asset_name` | Stable lowercase snake_case Xcode imageset stem |
| `role` | `background`, `sprite`, `hub_icon`, `effect`, `mask`, `reticle`, `target`, `decoy` |
| `source_mockup` | Mockup or design brief used as visual reference |
| `transparent` | `yes` for sprites/effects, `no` for full-bleed backgrounds |
| `target_size_px` | e.g. `1024x1024`, `1376x768`, `2048x4096` |
| `prompt_status` | `needed`, `generated`, `approved`, `rejected` |
| `qa_status` | `pending`, `pass`, `warn`, `fail` |
| `swift_reference` | Runtime constant or asset lookup name, if known |

Naming rules:

- Use lowercase snake_case.
- Prefix by feature or quest: `banishment_`, `dungeon_`, `rotor_`,
  `magictap_`, etc.
- Suffix by role where useful:
  - `_bg`
  - `_hub_icon`
  - `_target_*`
  - `_decoy_*`
  - `_reticle_*`
  - `_flare_*`
  - `_mask_*`
- Once adopted, names are stable. Renames require docs, Xcode catalog, and code
  changes in the same work item.

## Mockup Analysis

For each mockup:

1. Identify non-reusable UI chrome:
   - text cards,
   - buttons,
   - labels,
   - HUD,
   - safe-area/nav chrome.

2. Identify reusable visual assets:
   - background scene,
   - foreground characters,
   - props,
   - targets,
   - decoys,
   - reticles,
   - rings,
   - visual effects,
   - hub thumbnails.

3. Decide whether each asset should be:
   - generated as a new independent image,
   - hand-exported by a designer,
   - cropped from the mockup only as a temporary bootstrap,
   - drawn in code because it is geometric UI, not illustration.

4. Record which mockup proves the asset’s scale, silhouette, palette, and role.

Do not generate multi-object sheets. One asset equals one image.

## Generation Prompt Template

For every authored asset, use a separate prompt.

```text
Use case: stylized-concept
Asset type: Xcode asset catalog PNG
Asset name: <asset_name>
Role: <background|sprite|hub_icon|effect|mask>
Reference mockup: <filename and what to match>

Primary request:
Create <one specific subject> as an app-ready asset.

Style:
Match the provided mockup's visual language: <palette, lighting, material,
shape language, atmosphere>. Keep simple large shapes first and controlled
detail second. It must remain readable at small in-app sizes.

Composition:
<Centered subject with generous padding | full-bleed portrait background with
calm center band | wide hub thumbnail with centered readable subject>.

Technical requirements:
<Transparent background | opaque full-bleed background>.
Target master size: <width>x<height>.
No text, letters, numbers, watermark, logo, UI chrome, button shapes, contact
sheet, sprite sheet, multiple variations, cast shadow on a floor plane, or
baked checkerboard.

Negative constraints:
Do not include unrelated objects. Do not crop the subject. Do not include a
rectangular matte, grey plate, white backing, black backing, or fake
transparency grid.
```

For transparent sprites, strongly prefer native transparency when the available
image tool supports it. If not available, generate on a perfectly flat
chroma-key background and remove the key mechanically, then inspect edges.

## Standard Sizes

Use the project’s own conventions first. If none exist, start here:

| Role | Master Size | Background |
|---|---:|---|
| Full-bleed portrait background | `2048x4096` | opaque RGB or fully opaque RGBA |
| Full-bleed landscape/wide background | `1920x1080` or `2048x1152` | opaque |
| Sprite/prop/target/decoy | `1024x1024` | transparent RGBA |
| Reticle/ring/effect | `1024x1024` | transparent RGBA |
| Hub thumbnail | `1376x768` | usually transparent RGBA or project-defined |
| Small icon | `512x512` or `1024x1024` | transparent RGBA |

Do not force square masters for backgrounds. Do not force portrait masters for
small composited sprites.

## Technical QA Gate

Reject or regenerate assets with:

- no alpha channel when transparency is required,
- baked white/black/grey/chroma matte,
- checkerboard transparency bed,
- semi-opaque rectangular plate,
- cropped subject,
- tiny subject with excessive empty padding,
- subject touching image edges,
- embedded text or UI labels,
- multiple objects where one was requested,
- inconsistent style versus mockup,
- low contrast at expected runtime size,
- wrong dimensions,
- unreadable hub thumbnail composition.

For transparent sprites, inspect over:

- black,
- white,
- the target app background,
- a mid-grey checkerboard.

Look specifically for edge fringe, halos, premultiply artifacts, and fake
transparency grids.

## Xcode .imageset Output

Each asset should produce this structure:

```text
Assets.xcassets/
  <asset_name>.imageset/
    <asset_name>.png
    Contents.json
```

Use this `Contents.json` for a single universal 1x PNG:

```json
{
  "images" : [
    {
      "filename" : "<asset_name>.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Add `@2x` and `@3x` only when the app needs separate density masters. Do not add
them by default if the project convention is universal 1x high-resolution PNGs.

## Import Workflow

1. Save raw generated or human-authored exports under the project, for example:

   ```text
   memlog/requirements/Design/Assets/<feature>/
   ```

2. Name raw exports predictably:

   ```text
   <asset_name>_source.png
   <asset_name>_approved.png
   ```

3. Normalize final files mechanically:

   - fit/crop background to target background size,
   - fit transparent sprite into square canvas without cropping,
   - preserve alpha,
   - write `<asset_name>.png`,
   - create/update `.imageset/Contents.json`.

4. Run QA.

5. Update runtime asset constants or bundle-load tests.

6. Update design docs and directory tree.

## Review Workflow

Use a two-pass review.

### Pass 1: Product/Design Review

Ask:

- Does the asset match the mockup’s world and tone?
- Is the silhouette readable at the smallest intended size?
- Does it communicate meaning without relying only on color?
- Does it avoid UI/text that should remain native SwiftUI?
- Does it feel reusable across states?

### Pass 2: Technical Review

Ask:

- Is the file the expected pixel size?
- Is alpha present where required?
- Are all corners transparent for sprites?
- Is the subject centered and padded?
- Are there halos or rectangular mattes on dark backgrounds?
- Does Xcode asset catalog load the name exactly?
- Does the Swift code reference a stable constant rather than a magic string?

## Failure Recovery

If output has a matte or wrong transparency:

1. Regenerate with stronger prompt constraints.
2. If the background is flat and removable, use a mechanical background-removal
   helper.
3. Inspect edge quality over dark and light backgrounds.
4. Reject if the edge still has visible halo/fringe.

If output does not match the mockup:

1. Make the mockup reference explicit.
2. Restate the exact silhouette, palette, and scale.
3. Generate only the failed asset again.
4. Do not regenerate unrelated accepted assets.

If output includes text/UI:

1. Reject.
2. Regenerate with “no text, no labels, no UI chrome, no buttons, no cards,
   no screenshots inside the image.”

If output is a sheet or multiple variants:

1. Reject.
2. Regenerate one asset per prompt.

## RA11y-Specific Defaults

When working in RA11y:

- Design docs live in `memlog/requirements/Design/`.
- Mockup PNGs live in `memlog/requirements/Design/MockupScreens/`.
- Pre-import assets live in `memlog/requirements/Design/Assets/<quest>/`.
- Xcode catalog is `RA11y-iOS/RA11y-iOS/Assets.xcassets/`.
- Use one universal 1x PNG per imageset unless a specific asset needs more.
- Backgrounds generally use `2048x4096`.
- Sprites generally use `1024x1024`.
- Hub icons use `1376x768` when matching existing quest cards.
- Existing QA scripts:
  - `utility/qa_banishment_png_assets.py`
  - `utility/qa_crystal_resonance_png_assets.py`
  - `utility/remove_white_background.py`
  - `utility/ensure_png_rgba.py`
  - `utility/ingest_llm_banishment_pngs.py`

Follow the project rule: creative pixels come from LLM image generation or human
art, not procedural scripts.

## Done Criteria

The work is complete only when:

- every required asset has a registry row,
- every accepted generated asset is saved inside the project,
- every `.imageset` has the expected PNG and `Contents.json`,
- transparent sprites are real RGBA with clean transparent corners,
- opaque backgrounds are correctly sized and not flat failed exports,
- asset names match prompt sheet, pipeline doc, Xcode folder, PNG filename, and
  Swift constants,
- QA passes or warnings are documented,
- the app can load the images by name,
- visual review confirms the assets match the mockup and remain readable at
  runtime scale.
