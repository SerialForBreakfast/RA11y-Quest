# Coordinate Spike — NativeUIAuditKit Phase 1

**Status:** In Progress  
**Phase gate:** Must complete before Phase 2 (taxonomy schema) and Phase 3 (dataset generation at scale)  
**Fixture code:** `NativeUIAuditKit/CoordinateSpike/`

---

## Purpose

Dataset generation requires knowing the **precise pixel bounding box** of every element in each
generated screenshot. This spike validates that the coordinate pipeline produces annotations that
align with ground truth at ≤2px tolerance on both @2x and @3x Simulator output.

Three questions to answer experimentally:

| # | Question | Why it matters |
|---|----------|----------------|
| 1 | Do SwiftUI GeometryReader frames match `XCUIElement.frame`? | Ground truth export strategy |
| 2 | Does `XCUIElement.frame` (points) convert to the correct PNG pixel coordinates? | Annotation accuracy |
| 3 | Do `@2x` and `@3x` simulator screenshots both satisfy ≤2px alignment? | Scale factor handling |
| 4 | Are partially-clipped elements bounded to their visible rect? | Scroll view ground truth |

---

## Fixture Design

The spike uses a single, deterministic SwiftUI scene with **three elements at fixed positions**:

```
┌─────────────────────────────────┐  ← device top
│                                 │
│  [  Primary Button  ]           │  ← element A: fixed frame 200×44pt at (40, 100)
│                                 │
│  [_ Text Field ___________]     │  ← element B: fixed frame 280×44pt at (40, 164)
│                                 │
│  Static Label                   │  ← element C: fixed frame 200×30pt at (40, 228)
│                                 │
└─────────────────────────────────┘
```

No scroll view. No adaptive layout. No Dynamic Type. Fixed `ignoresSafeArea(.all)` so the
fixture origin is always the screen origin — removing safe area as a variable.

**Expected ground truth (points, portrait, any device):**

| Element | x | y | width | height |
|---------|---|---|-------|--------|
| Button | 40 | 100 | 200 | 44 |
| TextField | 40 | 164 | 280 | 44 |
| Label | 40 | 228 | 200 | 30 |

**Expected pixel coordinates (@2x):** multiply each value by 2.  
**Expected pixel coordinates (@3x):** multiply each value by 3.

---

## Setup

The fixture requires an Xcode project with:
- An iOS app target hosting `CoordSpikeView` (see `CoordSpikeView.swift`)
- A UI test target with `CoordSpikeUITests` (see `CoordSpikeUITests.swift`)

### Quickstart

1. Create a new Xcode project (iOS App, SwiftUI interface)
2. Copy `CoordSpikeView.swift` into the app target, replace `ContentView` with `CoordSpikeView`
3. Copy `CoordSpikeUITests.swift` into the UI test target
4. Run on an iPhone 14 Simulator (@3x) and iPhone SE Simulator (@2x)

The UI test prints measurements to the console and writes a JSON file to the test output directory.

---

## What to Measure

For each element, record three coordinate sets:

### 1. SwiftUI GeometryReader (ground truth declared in code)
The fixed `.frame(width:height:)` + `.offset(x:y:)` values are the authoritative declaration.
Use `GeometryReader` + `PreferenceKey` to capture the rendered `CGRect` in global coordinates.

### 2. XCUIElement.frame
`XCUIElement.frame` returns `CGRect` in **point coordinates** (top-left origin, portrait).
This is what XCTest can read without a Vision or CoreML model.

### 3. PNG pixel coordinates
Scale `XCUIElement.frame` by `UIScreen.main.scale` (2.0 or 3.0) to get pixel coordinates.
Cross-check by reading the screenshot PNG and locating the element visually:
- The button has a distinct background fill
- The text field has a border
- The label has unique text

Alignment tolerance: **≤2px** on all edges at both scale factors.

---

## Measurement Protocol

Run `CoordSpikeUITests` and collect output from the Xcode test results:

```
[CoordSpike] Element: Button
  Declared (pt):     x=40  y=100  w=200  h=44
  XCUIElement (pt):  x=?   y=?    w=?    h=?
  Delta (pt):        dx=?  dy=?   dw=?   dh=?

[CoordSpike] Element: TextField
  ...

[CoordSpike] Scale factor: 3.0
[CoordSpike] Button pixel bounds: x=? y=? w=? h=?
[CoordSpike] Expected pixel bounds: x=120 y=300 w=600 h=132
```

Fill in the Results section below after running.

---

## Results

> **Fill this section in after running the spike on the simulators listed.**

### iPhone 14 Pro Simulator — @3x (390pt wide × 844pt tall)

| Element | Declared (pt) | XCUIElement (pt) | Delta |
|---------|--------------|-----------------|-------|
| Button | 40, 100, 200×44 | ___, ___, ___×___ | dx=___ dy=___ |
| TextField | 40, 164, 280×44 | ___, ___, ___×___ | dx=___ dy=___ |
| Label | 40, 228, 200×30 | ___, ___, ___×___ | dx=___ dy=___ |

**Scale factor:** 3.0  
**Pixel alignment within ≤2px:** ☐ Pass / ☐ Fail

| Element | Expected pixel (×3) | Measured pixel | Max edge delta |
|---------|--------------------|----|----------------|
| Button | 120, 300, 600×132 | ___, ___, ___×___ | ___ px |
| TextField | 120, 492, 840×132 | ___, ___, ___×___ | ___ px |
| Label | 120, 684, 600×90 | ___, ___, ___×___ | ___ px |

---

### iPhone SE (3rd gen) Simulator — @2x (375pt wide × 667pt tall)

| Element | Declared (pt) | XCUIElement (pt) | Delta |
|---------|--------------|-----------------|-------|
| Button | 40, 100, 200×44 | ___, ___, ___×___ | dx=___ dy=___ |
| TextField | 40, 164, 280×44 | ___, ___, ___×___ | dx=___ dy=___ |
| Label | 40, 228, 200×30 | ___, ___, ___×___ | dx=___ dy=___ |

**Scale factor:** 2.0  
**Pixel alignment within ≤2px:** ☐ Pass / ☐ Fail

| Element | Expected pixel (×2) | Measured pixel | Max edge delta |
|---------|--------------------|----|----------------|
| Button | 80, 200, 400×88 | ___, ___, ___×___ | ___ px |
| TextField | 80, 328, 560×88 | ___, ___, ___×___ | ___ px |
| Label | 80, 456, 400×60 | ___, ___, ___×___ | ___ px |

---

## Frame Export Strategy Decision

After running the spike, record which strategy was chosen and why:

**Question: Which frame source should the dataset generator use as ground truth?**

| Option | Mechanism | Accuracy | Complexity |
|--------|-----------|----------|------------|
| A | Fixed `.frame()` values + scale factor | Exact by construction | Simplest |
| B | `GeometryReader` + `PreferenceKey` in global space | Rendered position | Medium |
| C | `XCUIElement.frame` × `UIScreen.main.scale` | Accessibility frame | Low |

**Decision (fill in after spike):** ___

**Rationale (fill in after spike):** ___

---

## Known Risks to Investigate

| Risk | Test approach | Outcome |
|------|--------------|---------|
| Safe area shifts origin | Compare `ignoresSafeArea` vs. without | ___ |
| `clipsToBounds` clips reported frame | Add clipped element and compare | ___ |
| SwiftUI animation frame lag | Assert stable frame after idle wait | ___ |
| `.accessibilityFrame` vs `.frame` divergence | Check UITextField (uses UIKit under the hood) | ___ |

---

## Acceptance Criteria

- [ ] ≤2px alignment on all three elements at @3x
- [ ] ≤2px alignment on all three elements at @2x
- [ ] Frame export strategy decided and documented in this file
- [ ] Scale factor conversion formula confirmed (`pointRect × scale = pixelRect`)
- [ ] At least one known-risk investigated with a conclusion

When all criteria are met, mark Phase 1 complete in `Tasks.md` and add the chosen strategy
to `Research/NativeUIElementDetection.md` Section 6 (Dataset Strategy).
