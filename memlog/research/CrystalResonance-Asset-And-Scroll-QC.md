# Crystal Resonance — asset & VoiceOver scroll QC (living notes)

**Purpose:** Capture what repeatedly breaks so art, scripts, and UI don’t loop on the same failures.

**Related:** `DungeonResonanceAssetPipeline.txt`, `ADR-0003`, `CrystalResonance-VoiceOverScrollProxy-Investigation.md`, `utility/remove_white_background.py`.

---

## 1. VoiceOver three-finger scroll — “can’t reach last lane item”

### Symptoms
- Scroll offset jumps backward (e.g. 588 → 392) after reaching the last slot.
- Logs: `UIKit proxy: updateContentHeight` with **wrong** `bounds.height` (e.g. full-screen) then a smaller playfield height — `maxY = contentSize - bounds` **clamps** `contentOffset` below `(n-1) × laneStep`.

### Code invariants (iOS)
1. **Lane selection** must start at the **Moonstone row** (`firstIndex(where: \.isTarget)`) when the play surface appears and whenever the room-list identity changes — not slot `0` by default.
2. **UIKit proxy** must not call SwiftUI state from `scrollViewDidScroll` **during** `UIViewRepresentable.updateUIView` (use programmatic flag + deferred callbacks; defer height/offset apply to next run loop).
3. **Scroll content height** must satisfy  
   `contentHeight ≥ boundsHeight + (n-1) × laneStep + headroom`  
   for the **smallest** stable playfield height, not a transient layout size.
4. **Trailing slack:** extra `Color.clear` + height term so paging past the last snap does not sit on the `maxY` rail.
5. **`laneStepPoints`** must match **actual** lane row stride. `@ScaledMetric` rows that grow without a fixed frame **drift** from the nominal `rowContentHeightPoints` used for the UIKit proxy — **pin each row** to `iOSDungeonResonanceLaneLayout.rowContentHeightPoints`.

### When “regenerating” won’t help
This class of bug is **layout/sync**, not PNG.

---

## 2. Grey boxes / dark rectangles around glyphs or reticle

### Root causes (check in order)
| Cause | How to detect | Fix |
|--------|----------------|-----|
| **RGB PNG** (no alpha) on dark UI | Xcode asset inspector; file shows opaque where art should float | Re-export **RGBA** or run cleanup script |
| **Flat light-grey mat** (not white) | Eyedropper ~230–245 RGB, uniform | Re-export with alpha, or `remove_white_background.py --edge-matte` (QC!), or careful global mode |
| **SwiftUI `.shadow` on `Image(uiImage:)`** | Grey slab behind sprite in ZStack | Remove shadow or use stroke-only highlight |
| **`.compositingGroup()`** on small images | Odd premultiplied bands | Remove unless required |
| **`.blur` on lane rows** | Dark fringes | Avoid blur on stacked PNG lanes |
| **Template rendering** | Tinted / boxed | `.renderingMode(.original)` |
| **Opaque centre in reticle/orb art** | Cannot see lane through ring | **Art:** donut PNG; **Code:** donut `mask` + radial orb mask (see `iOSResonanceReticleRing` / `iOSResonanceCenterOrb`) |
| **L3 `ra11yLightsOffGameplayBlackout` on the glyph lane** | Opaque black plate over the stack + vignette | Crystal Resonance uses **vignette only** on the lane; do not stack the generic gameplay blackout on `resonanceLaneColumn` (see `iOSDungeonResonancePlayView`). |

### Script vs regenerate
- **`utility/remove_white_background.py`:** Best for **near-white** mats touching the **edge** (`--mode edge`). Does **not** fix mid-image grey boxes unless they touch the border and match matte heuristics (`--edge-matte`).
- **Regenerate:** Prefer when exports are **RGB**, wrong colour space, or grey mat is **interior** / connects to glyph.

---

## 3. Centre stack — “see the glyph underneath”

**Design intent:** Fixed reticle + orb sit **above** the scrolling lane. If assets are **opaque discs**, the Moonstone disappears under the hub.

**Mitigations:**
1. **Reticle:** Donut mask (transparent centre) so the ring frames the aim line but the lane shows through (`iOSResonanceReticleDonutMask`).
2. **Orb:** Radial mask (softer centre opacity) + thin stroke glow instead of large `shadow`.
3. **Art:** Prompt for **true alpha** in ring interior and semi-transparent orb core if the code mask is not enough.

---

## 4. Quick device QC checklist (Crystal Resonance L1)

- [ ] VoiceOver lands on **Moonstone alignment lane**; three-finger scroll moves **all** items including **last**.
- [ ] No grey plate behind Moonstone / decoys / reticle on **dark** shaft.
- [ ] With Moonstone under centre, **glyph remains visible** through ring (and ideally through orb centre).
- [ ] Console: no “**Modifying state during view update**” when scrolling.
- [ ] Assets: lane glyphs are **PNG RGBA** in catalog.

---

## 5. Command examples (glyphs only)

```bash
# Normalize entire catalog: backgrounds stay RGB; sprites get edge alpha; dungeon_room_* → RGBA opaque
python3 utility/ensure_png_rgba.py --dry-run
python3 utility/ensure_png_rgba.py

# Safe first pass — white edge mat (single file)
python3 utility/remove_white_background.py --in-place path/to/dungeon_target_moonstone.png

# Light grey edge mat (inspect output — can eat silver highlights)
python3 utility/remove_white_background.py --in-place --edge-matte path/to/dungeon_decoy_*.png
```

---

## 3. Off-by-one hub alignment (VoiceOver name vs visible Moonstone)

### Cause
`resonanceLaneColumn` uses `VStack(spacing:)`, so there is an extra **leading** gap between the top centering spacer and row `0`. Scroll math that used `s + i × laneStep + h/2` omitted that gap: row centers were **one spacing interval** too low, Moonstone sat **below** the reticle hub, and `laneIndexClosestToAimLine` could disagree with the eye.

### Fix (iOS)
- Row center in content space: `s + laneColumnInterItemSpacing + i × laneStep + h/2`.
- Snapped `contentOffset.y`: `laneRowCenterContentY(i) − playfieldHeight/2` (not `i × laneStep` alone).
- Extra `minForLastSlot` headroom for the larger maximum offset.

---

*Last updated: 2026-04-20 (§3 VStack leading gap in lane scroll math; orb clear core + reticle draw order for hub see-through).*
