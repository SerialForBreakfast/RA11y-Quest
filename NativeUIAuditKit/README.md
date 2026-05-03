# NativeUIAuditKit

A portable Swift package for detecting native Apple platform UI elements in screenshot PNGs, designed as a drop-in complement to [ScreenAuditKit](../ScreenAuditKit/).

**Current state:** Scaffold only — `0.1.0-scaffold`. No CoreML model or training pipeline yet. The API shape is defined; `NativeUIDetectionRequest.perform(on:sidecar:)` throws `NativeUIDetectionError.modelUnavailable` until the `NativeUIAuditKitModels` package ships.

---

## What This Package Will Do

NativeUIAuditKit builds a custom Vision-style request backed by a CoreML object detector trained on synthetic native Apple UIs. Given a screenshot PNG, it returns structured `NativeUIElementObservation` values with:

- Semantic element type (`primaryButton`, `navigationBar`, `alert`, etc.)
- Accurate bounding boxes in both Vision-normalized and pixel coordinates
- Visible text (from `VNRecognizeTextRequest` fusion)
- Audit issues: truncation, clipping, overlapping controls, insufficient touch target size
- Optional device / OS inference from visual chrome signals

Two operating modes:
- **Sidecar mode** — highest accuracy; hierarchy metadata paired with the PNG at capture time
- **Pixel-only mode** — moderate accuracy; works on orphan PNGs with no metadata

See [`Research/NativeUIElementDetection.md`](Research/NativeUIElementDetection.md) for full architecture, feasibility analysis, training strategy, and research milestones.

---

## Requirements

- macOS 15+
- Swift 6.0+
- Xcode 16+

No external dependencies. Vision, CoreML, and CoreGraphics are Apple system frameworks.

---

## Build & Test

```bash
cd NativeUIAuditKit
swift build
swift test
```

All tests should pass on the scaffold. When `NativeUIAuditKitModels` is not installed, `perform(on:sidecar:)` throws `modelUnavailable` — this is expected and tested.

---

## Package Structure

```
NativeUIAuditKit/
├── Package.swift
├── README.md
├── Tasks.md                        ← phase-structured task list and roadmap
├── Research/
│   ├── NativeUIElementDetection.md ← 20-section architecture and research doc
│   └── References.md               ← Apple docs, prior art, related tools
├── Sources/
│   └── NativeUIAuditKit/
│       ├── NativeUIAuditKit.swift
│       ├── Detection/
│       │   └── NativeUIDetectionRequest.swift
│       └── Models/
│           └── NativeUIElementObservation.swift
└── Tests/
    └── NativeUIAuditKitTests/
        └── NativeUIAuditKitTests.swift
```

---

## Roadmap

Phases are tracked in [`Tasks.md`](Tasks.md).

| Phase | Status | Goal |
|-------|--------|------|
| 0: Scaffold | ✅ Done | Buildable package + research docs |
| 1: Coordinate Spike | [ ] Next | Prove exported coords align with PNG pixels |
| 2: Schema v1 | [ ] | Freeze taxonomy and annotation schema |
| 3: Dataset Generator | [ ] | 500+ annotated SwiftUI screenshots |
| 4: UIKit Generator | [ ] | Anti-overfitting: UIKit-rendered controls |
| 5: Known-Bad UI | [ ] | Truncation, clipping, overflow failure cases |
| 6: First CoreML Detector | [ ] | 5-class Create ML model in `NativeUIDetectionRequest` |
| 7: OCR Fusion | [ ] | Visible text + truncation/clipping audit rules |
| 8: Device/OS Inference | [ ] | `NativeUIDeviceInference` from chrome heuristics |
| 9: ScreenAuditKit Integration | [ ] | Drop-in protocol, contract fields, CLI flag |

---

## Design Principles

Inherited from ScreenAuditKit (ADR-0002, ADR-0005):

1. **Deterministic checks first** — pixel inference augments, it does not replace, rule-based validation
2. **No cloud dependency** — all inference runs locally; screenshots never leave the machine
3. **Contracts over guesswork** — detection results feed declared contracts, not ad-hoc prompts
4. **Semantic roles, not private class names** — `primaryButton` survives OS redesigns; `UIButton` does not
5. **Confidence surfaced, not hidden** — every observation declares its `confidenceSource`

---

## Related

- [`../ScreenAuditKit/`](../ScreenAuditKit/) — screenshot validation engine this package integrates with
- [`../memlog/research/ScreenAuditKit-NativeUIElementDetection-Research.md`](../memlog/research/ScreenAuditKit-NativeUIElementDetection-Research.md) — original feasibility ADR
- [`../memlog/research/ADR-0002-AI-Assisted-Screenshot-Validation.md`](../memlog/research/ADR-0002-AI-Assisted-Screenshot-Validation.md)
