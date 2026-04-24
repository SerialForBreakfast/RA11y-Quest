// MARK: - iOSBanishmentArt

import Foundation

/// Asset catalog string keys for **The Banishment** final art (PNG imagesets).
///
/// PNGs are intended as **universal 1x** imagesets under `Assets.xcassets`, matching
/// ``iOSDungeonResonanceArt``. Until files are imported, the quest continues to use
/// SF Symbol greybox portraits.
///
/// **Authoritative prompts and import order:** ``memlog/requirements/Design/Banishment-ImageGen-ExecutionPlan.txt``
/// and ``DesignTicket-BanishmentPromptSheet.txt``. **Layer stack:** ``BanishmentAssetPipeline.txt``.
/// **Traceability / verification:** ``memlog/requirements/Design/BanishmentAssetRequirements-Checklist.txt``
/// and ``utility/validate_banishment_assets.sh``.
/// **Catalog art:** ``utility/import_banishment_mockups_to_assets.py`` from ``MockupScreens/banishment_iphone_*.png``.
/// Legacy greybox only: ``utility/banishment_procedural_placeholder.py`` (not mockup fidelity).
///
/// **Sprites** must be **RGBA** (true alpha). Flat RGB mats show as grey boxes on dark UI;
/// run ``utility/remove_white_background.py`` or re-export with alpha (see pipeline).
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
    /// Prologue Z illustration (golden particle trail + nodes, mockup-aligned). PNG is **RGBA** with transparent exterior matte (see ``utility/transparent_edge_dark_matte.py``).
    static let gestureZReference = "banishment_gesture_z_reference"

    // MARK: Threats (transparent)

    static let threatGoblin = "banishment_threat_goblin"
    static let threatSkeleton = "banishment_threat_skeleton"
    static let threatOrc = "banishment_threat_orc"
    static let threatTroll = "banishment_threat_troll"
    static let threatDragon = "banishment_threat_dragon"

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
