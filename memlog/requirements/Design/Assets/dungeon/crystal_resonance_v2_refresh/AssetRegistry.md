# Crystal Resonance v2 Refresh Asset Registry

Date: 2026-08-20

Source mockup: `memlog/requirements/Design/RemainingQuestMockups/PNGs/crystal_resonance_v2_iphone_mockup.png`

Purpose: track the generated Crystal Resonance refresh assets imported into `RA11y-iOS/RA11y-iOS/Assets.xcassets/`.

| asset_name | role | transparent | target_size_px | prompt_status | qa_status | swift_reference |
|---|---|---:|---:|---|---|---|
| `dungeon_resonance_bg` | background | no | `1376x768` | generated | pass | `iOSDungeonResonanceArt.background` |
| `dungeon_resonance_orb_idle` | sprite | yes | `1376x768` | generated | pass | `iOSDungeonResonanceArt.orbIdle` |
| `dungeon_resonance_orb_locked` | sprite | yes | `1376x768` | generated | pass | `iOSDungeonResonanceArt.orbLocked` |
| `dungeon_reticle_ring` | reticle | yes | `1376x768` | regenerated | pass | `iOSDungeonResonanceArt.reticleRing` |
| `dungeon_target_moonstone` | target | yes | `1376x768` | regenerated | pass | `iOSDungeonResonanceArt.targetMoonstone` |
| `dungeon_decoy_ember_shard` | decoy | yes | `1376x768` | generated | pass | `iOSDungeonResonanceArt.decoyEmberShard` |
| `dungeon_decoy_shadow_glyph` | decoy | yes | `1376x768` | generated | warn | `iOSDungeonResonanceArt.decoyShadowGlyph` |
| `dungeon_decoy_sun_sigil` | decoy | yes | `1376x768` | generated | pass | `iOSDungeonResonanceArt.decoySunSigil` |
| `dungeon_lane_marker_neutral` | marker | yes | `1376x768` | regenerated | warn | `iOSDungeonResonanceArt.laneMarkerNeutral` |
| `dungeon_spotlight_mask_reference` | mask | yes | `1376x768` | generated | warn | `iOSDungeonResonanceArt.spotlightMaskReference` |
| `dungeon_success_flare` | effect | yes | `1376x768` | generated | warn | `iOSDungeonResonanceArt.successFlare` |
| `dungeon_hub_icon` | hub_icon | yes | `1376x768` | generated | pass | `GameDefinition.thumbnailAssetName` |

## Generation Constraints

- The mockup is a style reference only; no visible UI text, cards, buttons, or gesture hints should be baked into the assets.
- `dungeon_resonance_bg` is the only opaque asset.
- All other files must preserve real alpha outside the subject, with transparent corners and no rectangular matte.
- Wide masters are intentional because `iOSResonanceWideCanvasImage` center-crops them into the runtime point frames.

## Import Notes

- Built-in image generation produced source files at `1678x937` / `1679x937`; approved files were normalized to `1376x768` before catalog import.
- RGB-only generated sprites with checker/white preview beds were cleaned mechanically with `utility/remove_white_background.py --edge-matte`; the reticle required a regenerated low-haze source plus a global near-white pass to clear the center hole.
- `dungeon_target_moonstone` and `dungeon_lane_marker_neutral` were regenerated after visual review rejected a stray Moonstone fragment and an over-decorated marker.
- QA warnings remain on intentionally semi-transparent VFX / soft-glow assets and the thin lane marker; there are no PNG QA failures.
