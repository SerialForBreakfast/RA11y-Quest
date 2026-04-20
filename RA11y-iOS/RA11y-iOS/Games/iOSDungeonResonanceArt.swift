// MARK: - iOSDungeonResonanceArt

/// Asset catalog string keys for Crystal Resonance (Scroll Hunt) v2 resonance UI.
///
/// PNGs live in `Assets.xcassets` as universal 1x imagesets. Layering and point sizes
/// are documented in `memlog/requirements/Design/DungeonResonanceAssetPipeline.txt`.
///
/// **Lane glyphs** (moonstone + decoys): source PNGs must be **RGBA** (true transparency).
/// Flat RGB mats (no alpha) show as grey or white rectangles behind `Image`. If a source file
/// regresses to RGB-only, run `utility/remove_white_background.py` (see asset pipeline) or
/// re-export from the art tool with alpha.
///
/// Warm / Near orb states may use code-driven effects (`DesignTicket-DungeonResonancePromptSheet`)
/// rather than additional PNGs until explicitly added.
enum iOSDungeonResonanceArt {

    static let background = "dungeon_resonance_bg"

    static let orbIdle = "dungeon_resonance_orb_idle"
    static let orbLocked = "dungeon_resonance_orb_locked"

    static let reticleRing = "dungeon_reticle_ring"

    static let targetMoonstone = "dungeon_target_moonstone"

    static let decoyEmberShard = "dungeon_decoy_ember_shard"
    static let decoyShadowGlyph = "dungeon_decoy_shadow_glyph"
    static let decoySunSigil = "dungeon_decoy_sun_sigil"

    static let laneMarkerNeutral = "dungeon_lane_marker_neutral"

    /// Optional Lights Off reference; final mask may be code-drawn instead.
    static let spotlightMaskReference = "dungeon_spotlight_mask_reference"

    static let successFlare = "dungeon_success_flare"
}
