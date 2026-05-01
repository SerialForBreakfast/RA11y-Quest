// MARK: - iOSBanishmentArt

import Foundation

/// Asset catalog string keys for **The Banishment** final art (PNG imagesets).
///
/// All 12 assets are imported as **universal 1x** imagesets under `Assets.xcassets`.
/// SF Symbol and gradient fallbacks in ``iOSBanishmentQuestView`` remain as safety nets
/// for missing assets but are not exercised by the current catalog.
///
/// **Authoritative prompts and import order:** ``memlog/requirements/Design/Banishment-ImageGen-ExecutionPlan.txt``
/// and ``DesignTicket-BanishmentPromptSheet.txt``. **Layer stack:** ``BanishmentAssetPipeline.txt``.
/// **Traceability / verification:** ``memlog/requirements/Design/BanishmentAssetRequirements-Checklist.txt``
/// and ``utility/validate_banishment_assets.sh``.
/// **Catalog art:** ``utility/import_banishment_mockups_to_assets.py`` from ``MockupScreens/banishment_iphone_*.png``.
/// Legacy greybox only: ``utility/banishment_procedural_placeholder.py`` (not mockup fidelity).
///
/// **Sprites** must be **RGBA** with real transparency. Opaque grey / checkerboard beds
/// (alpha=255) read as mats in SwiftUI — run ``utility/transparent_edge_midgrey_matte.py`` /
/// ``utility/transparent_edge_dark_matte.py`` after import, or re-export with true alpha.
enum iOSBanishmentArt {

    // MARK: Hub (RGBA quest card)

    /// Quest board thumbnail; must match ``GameDefinition`` entry for The Banishment (`thumbnailAssetName`).
    static let hubIcon = "banishment_hub_icon"

    // MARK: Backgrounds (opaque)

    static let wardBackground = "banishment_ward_bg"
    static let towerBackground = "banishment_tower_bg"

    // MARK: Compositing (transparent)

    /// Ward binding ring raster — **not shown in UI** until art direction re-enables it; pipeline may still ship the asset.
    static let wardRing = "banishment_ward_ring"
    /// Prologue Z illustration used in ``QuestVoiceOverGestureSpellPlate`` as a gesture reference — **not a trap gameplay element**.
    /// PNG is 1376×768 landscape RGBA; the trap-decoration heuristics intentionally exclude it from ``shouldUseRasterTrapDecorations()``.
    /// Falls back to the code-drawn ``BanishmentZGestureShape`` if absent.
    static let gestureZReference = "banishment_gesture_z_reference"

    // MARK: Creature encounters (transparent RGBA)

    /// Ward practice creature — imageset ``banishment_goblin``.
    static let banishmentGoblin = "banishment_goblin"
    /// First tower encounter — imageset ``banishment_skeleton``.
    static let banishmentSkeleton = "banishment_skeleton"
    static let banishmentOrc = "banishment_orc"
    static let banishmentTroll = "banishment_troll"
    /// Lights Off / dark tower silhouette — imageset ``banishment_dragon``.
    static let banishmentDragon = "banishment_dragon"

    // MARK: Feedback (transparent)

    /// Creature-agnostic success burst — no species-specific shapes.
    static let flareEscape = "banishment_flare_escape"
    /// Optional Lights Off anchor if dragon sprite is too detailed.
    static let darkAnchor = "banishment_dark_anchor"
}

/// Reference type for locating the app ``Bundle`` from unit tests.
///
/// SwiftUI ``@main`` app types are not `AnyClass`, so ``Bundle(for:)`` cannot use ``RA11y_iOSApp``.
final class RA11yIOSAssetBundleProbe: NSObject {}
