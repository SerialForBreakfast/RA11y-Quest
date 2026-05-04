# NativeUIAuditKit — Tasks

## Status Legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Done
- `[!]` Blocked — see note

Full research and architecture documentation: [`Research/NativeUIElementDetection.md`](Research/NativeUIElementDetection.md)

---

## Phase 0: Scaffold ✅

*Goal: A buildable Swift package with research documentation and task structure.*

- [x] Create `NativeUIAuditKit` Swift package (`Package.swift`, Swift 6, macOS 15+)
- [x] Write `Sources/NativeUIAuditKit/NativeUIAuditKit.swift` — entry point and version constant
- [x] Write `Sources/NativeUIAuditKit/Detection/NativeUIDetectionRequest.swift` — API shape (stub, throws `modelUnavailable`)
- [x] Write `Sources/NativeUIAuditKit/Models/NativeUIElementObservation.swift` — full data type hierarchy
- [x] Write `Tests/NativeUIAuditKitTests/NativeUIAuditKitTests.swift` — smoke tests (build, API shape, Codable round-trip)
- [x] Write `Research/NativeUIElementDetection.md` — synthesized 20-section research document
- [x] Write `Research/References.md` — Apple docs, prior art, related tools
- [x] Write `Tasks.md` (this file)
- [x] Write `README.md`
- [x] Verify `swift build` and `swift test` pass — 6/6 tests pass (2026-05-03)

**Extraction readiness at end of Phase 0:** Package builds standalone with no workspace dependencies. No RA11y-specific code in `Sources/`.

---

## Phase 1: Coordinate Spike (P0 blocker) [~]

*Goal: Prove that exported element coordinates align with PNG pixels before any dataset generation.*

Full spike protocol and results template: [`Research/CoordinateSpike.md`](Research/CoordinateSpike.md)  
Fixture code (copy into Xcode project): [`CoordinateSpike/`](CoordinateSpike/)

- [x] Write `Research/CoordinateSpike.md` — methodology, protocol, results template, acceptance criteria
- [x] Write `CoordinateSpike/CoordSpikeView.swift` — SwiftUI fixture: Button + TextField + Label at fixed positions
- [x] Write `CoordinateSpike/CoordSpikeUITests.swift` — XCTest UI test measuring XCUIElement.frame vs declared ground truth at @2x and @3x
- [ ] **Run on iPhone 14 Pro Simulator (@3x)** — fill in Results section of CoordinateSpike.md
- [ ] **Run on iPhone SE Simulator (@2x)** — fill in Results section of CoordinateSpike.md
- [ ] Resolve SwiftUI frame export strategy (GeometryReader vs `XCUIElement.frame`) — document in CoordinateSpike.md
- [ ] Investigate known risks (safe area shift, clipsToBounds, transform divergence) — document outcome
- [ ] Confirm ≤2px alignment at both scale factors — mark acceptance criteria in CoordinateSpike.md
- [ ] Update `Research/NativeUIElementDetection.md` Section 6 with chosen coordinate strategy

**Gate:** Do not begin Phase 2 until `Research/CoordinateSpike.md` acceptance criteria are all checked.

---

## Phase 2: Taxonomy & Sidecar Schema v1

*Goal: Freeze the element role set and annotation schema before generating data at scale.*

- [ ] Confirm or adjust `NativeUIElementType` cases based on coordinate spike learnings
- [ ] Write `Research/annotation.schema.json` — versioned JSON schema with all required fields
- [ ] Confirm multi-coordinate storage: `boundsPixels`, `boundsPoints`, `boundsVisionNormalized`
- [ ] Confirm `imageSHA256` checksum linkage in `NativeUISidecar`
- [ ] Write `Research/OCRFusionPolicy.md` — when OCR overrides or contradicts detector bounds

**Gate:** Schema tagged `v1.0`. Any structural change after tagging is a version bump.

---

## Phase 3: Dataset Generator Prototype

*Goal: 500 annotated images from at least 3 SwiftUI templates with overlay validation.*

- [ ] Create `NativeUIDatasetGenerator` app target (separate from library)
- [ ] Build 3 SwiftUI screen templates: login form, settings list, alert
- [ ] Implement screenshot exporter (PNG at @3x from Simulator)
- [ ] Implement sidecar JSON exporter (element bounds + metadata)
- [ ] Implement overlay viewer: draw annotation boxes over PNG for manual inspection
- [ ] Sweep at least: light/dark × 3 Dynamic Type sizes × 2 device sizes = 12 variants per template
- [ ] Generate ≥500 annotated images
- [ ] Run dataset balance report: class distribution, Dynamic Type distribution, device distribution
- [ ] Confirm every generated PNG has a matching annotation file with valid `imageSHA256`

**Gate:** Overlay viewer shows all annotation boxes aligning to rendered elements. No misaligned boxes in a manual review of 50 random samples.

---

## Phase 4: UIKit Generator (Anti-Overfitting Requirement)

*Goal: Supplement SwiftUI data with UIKit-rendered controls before any model training.*

This phase must complete before Phase 5 training — SwiftUI-only training overfits to SwiftUI rendering.

- [ ] Build `UIKitGeneratorViewController` with at minimum: `UIButton` (4 styles), `UILabel`, `UITextField`, `UISwitch`, `UISlider`, `UISegmentedControl`, `UITableViewCell` (4 styles), `UIAlertController`, `UITabBar`, `UINavigationBar`
- [ ] Export matching sidecar JSON from UIKit view hierarchy
- [ ] Verify coordinate alignment for UIKit frames (same ±2px standard)
- [ ] Generate ≥2,000 annotated UIKit images
- [ ] Merge into dataset; verify class distribution remains balanced

---

## Phase 5: Known-Bad UI Generator

*Goal: Intentional failure cases labeled so audit rules can detect them.*

- [ ] Implement truncated label generation: constrained width, `.lineBreakMode = .byTruncatingTail`
- [ ] Implement clipped content generation: `clipsToBounds = true` with overflow
- [ ] Implement overlapping controls generation
- [ ] Implement small hit-target generation: <44×44pt buttons
- [ ] Implement Dynamic Type overflow generation: fixed-height container + `accessibilityXXXLarge`
- [ ] Implement off-screen element generation: content below fold in `UIScrollView`
- [ ] Tag all known-bad images in annotation JSON with `knownIssues` array
- [ ] Generate ≥500 known-bad images (10% of total dataset — hard negative budget)

---

## Phase 6: First Create ML Vertical Slice

*Goal: A 5-class CoreML detector integrated into `NativeUIDetectionRequest`.*

- [ ] Prepare training dataset: 5 classes (`primaryButton`, `navigationBar`, `alert`, `textField`, `toggle`)
- [ ] Apply screen-template-aware split: withhold 1 device family and 1 Dynamic Type size from training
- [ ] Train Create ML `MLObjectDetector` (10,000 iterations, `scenePrint` feature extractor)
- [ ] Export `.mlpackage` to `NativeUIAuditKitModels/` (separate package, not committed here)
- [ ] Wire `VNCoreMLRequest` into `NativeUIDetectionRequest.perform(on:sidecar:)`
- [ ] Run evaluation: mAP@0.5, per-class recall on withheld-template test set
- [ ] Run on 10 real app screenshots; document failure modes
- [ ] Adjust confidence thresholds based on precision/recall tradeoff

**Acceptance:** mAP@0.5 ≥ 0.70 on withheld-template test set (prototype bar — production target is 0.85).

---

## Phase 7: OCR Fusion & Audit Rules

*Goal: Visible text associated to detected elements; truncation and clipping rules active.*

- [ ] Add `VNRecognizeTextRequest` pass after detector
- [ ] Implement observation merger: associate OCR text regions to nearest element bounds
- [ ] Surface `visibleText` in `NativeUIElementObservation`
- [ ] Implement `NativeUIIssue(.truncatedText)` rule: OCR bounding box narrower than element bounds + `…` character
- [ ] Implement `NativeUIIssue(.clippedElement)` rule: element bounds extend past image edge
- [ ] Implement `NativeUIIssue(.tappableTargetTooSmall)` rule: `boundingBoxPixels.width * scale < 44`
- [ ] Implement `NativeUIIssue(.overlappingElements)` rule: IoU > 0.1 between two observations
- [ ] Write unit tests for each rule using known-bad fixture images from Phase 5

---

## Phase 8: Device & OS Inference

*Goal: `NativeUIDeviceInference` from dimension/chrome heuristics; pixel classifier for orphan PNGs.*

- [ ] Build dimension/safe-area heuristic database (device candidates by screenshot pixel dimensions)
- [ ] Implement `NativeUIDeviceInference` from dimensions + safe area inset detection
- [ ] Return ranked candidates, not a single hard claim
- [ ] Train optional visual classifier: Dynamic Island vs. notch vs. no-notch
- [ ] Verify: sidecar screenshots return exact metadata; orphan PNGs return candidates with confidence

---

## Phase 9: ScreenAuditKit Integration

*Goal: `NativeUIRecognizing` protocol wired into ScreenAuditKit; `--native-ui coreml` CLI flag.*

- [ ] Define `NativeUIRecognizing` protocol (parallel to `ScreenAuditOCRRecognizing`)
- [ ] Implement `NativeUINoOpRecognizer` for test determinism
- [ ] Extend `ScreenAuditScreenContract` with `uiElements.required/forbidden/minConfidence`
- [ ] Implement new rule IDs: `missingUIElement`, `unexpectedUIElement`, `uiElementBoundsViolation`, `uiElementTruncated`, `inferredOSMismatch`
- [ ] Add `--native-ui none|coreml` flag to `screenaudit validate` CLI
- [ ] Add graceful error when `NativeUIAuditKitModels` is not installed
- [ ] Update ScreenAuditKit integration tests

---

## Extraction Readiness Checklist

Before moving `NativeUIAuditKit` to its own repository:

- [ ] No RA11y-specific code, paths, or terminology inside `Sources/NativeUIAuditKit/`
- [ ] Package builds standalone (`swift build` from `NativeUIAuditKit/` with no workspace)
- [ ] `README.md` includes a minimal integration guide for a project that is not RA11y
- [ ] License decision made and `LICENSE` file added
- [ ] Dataset folder structure documented in `README.md`
- [ ] `NativeUIAuditKitModels` package structure defined (even if models not yet trained)
- [ ] At least one non-RA11y test scenario documented in `Research/` or `README.md`
- [ ] `AGENTS.md`-compatible (no prohibited commands in any scripts, no filesystem boundary violations)
