# NativeUIAuditKit — References

## Apple Developer Documentation

### Vision Framework
- [Vision framework overview](https://developer.apple.com/documentation/vision)
- [VNCoreMLRequest](https://developer.apple.com/documentation/vision/vncoremlrequest)
- [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [Recognizing text in images](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [Locating and displaying recognized text](https://developer.apple.com/documentation/vision/locating-and-displaying-recognized-text)
- [VNDetectedObjectObservation.boundingBox](https://developer.apple.com/documentation/vision/vndetectedobjectobservation/boundingbox) — Vision normalized coordinate system (bottom-left origin)

### Core ML
- [Core ML overview](https://developer.apple.com/documentation/coreml)
- [MLModel overview (coremltools docs)](https://apple.github.io/coremltools/docs-guides/source/mlmodel.html)
- [Integrating a Core ML model into your app](https://developer.apple.com/documentation/coreml/integrating-a-core-ml-model-into-your-app)

### Create ML
- [Create ML framework overview](https://developer.apple.com/documentation/createml)
- [MLObjectDetector](https://developer.apple.com/documentation/createml/mlobjectdetector)
- [Building an object detector data source](https://developer.apple.com/documentation/createml/building-an-object-detector-data-source)
- [MLObjectDetector.AnnotationType.boundingBox(units:origin:anchor:)](https://developer.apple.com/documentation/createml/mlobjectdetector/annotationtype/boundingbox(units:origin:anchor:)) — coordinate system for Create ML annotations
- [MLObjectDetector.ModelParameters](https://developer.apple.com/documentation/createml/mlobjectdetector/modelparameters)

### Accessibility
- [Accessibility for UIKit](https://developer.apple.com/documentation/uikit/accessibility_for_uikit)
- [UIAccessibility](https://developer.apple.com/documentation/uikit/uiaccessibility)
- [UIAccessibilityTraits](https://developer.apple.com/documentation/uikit/uiaccessibilitytraits)
- [accessibilityFrame](https://developer.apple.com/documentation/uikit/uiaccessibilityelement/1619579-accessibilityframe)
- [Dynamic Type](https://developer.apple.com/documentation/uikit/uifont/scaling_fonts_automatically)
- [UIContentSizeCategory](https://developer.apple.com/documentation/uikit/uicontentsizecategory)

### XCTest / UI Testing
- [XCUIElement](https://developer.apple.com/documentation/xctest/xcuielement)
- [XCUIElement.frame](https://developer.apple.com/documentation/xctest/xcuielement/1618505-frame)
- [XCUIApplication.screenshot()](https://developer.apple.com/documentation/xctest/xcuiapplication)

### Safe Area & Device Geometry
- [safeAreaInsets](https://developer.apple.com/documentation/uikit/uiview/2891102-safeareainsets)
- [UIScreen.scale](https://developer.apple.com/documentation/uikit/uiscreen/1617836-scale)

### coremltools (Python)
- [coremltools documentation](https://apple.github.io/coremltools/)
- [Converting models to Core ML format](https://apple.github.io/coremltools/docs-guides/source/convert-pytorch.html)
- [Quantizing a Core ML model](https://apple.github.io/coremltools/docs-guides/source/quantization.html)

---

## Prior Art

### RICO Dataset
- Paper: "Rico: A mobile app dataset for building data-driven design applications" (Deka et al., 2017)
- **Status for NativeUIAuditKit:** Android-only. Cannot be used as Apple UI training data or benchmark. Relevant only as architecture inspiration for dataset structure.
- Distribution shift is severe: Android Material Design controls look and behave differently from Apple HIG controls.

### GUI Grounding / Widget Detection
- **CogAgent:** Large VLM fine-tuned for GUI interaction. State-of-the-art GUI understanding but requires GPU inference (incompatible with CoreML on-device CI requirements).
- **SeeClick:** Smaller GUI grounding model; same architectural constraints.
- **Relevance:** Useful for understanding what high-accuracy UI element understanding looks like at a research level. Not a viable implementation path for NativeUIAuditKit's on-device, <200ms CI budget.
- **Lesson:** The academic GUI grounding field demonstrates that with sufficient synthetic and real data, fine-grained UI element detection is achievable. The engineering constraint is inference latency and deployment format (CoreML), not feasibility.

### UIBert / Screen2Words
- UI-to-language models for mobile screenshots. Android-focused. Useful for understanding semantic labeling, not for bounding-box detection pipelines.

---

## Related RA11y Research

- [`../../memlog/research/ScreenAuditKit-NativeUIElementDetection-Research.md`](../../memlog/research/ScreenAuditKit-NativeUIElementDetection-Research.md) — Original feasibility research and P0–P3 checklist
- [`../../memlog/research/ScreenAuditKit-RecognizeUIElements.md`](../../memlog/research/ScreenAuditKit-RecognizeUIElements.md) — Earlier API shape and milestone drafts
- [`../../memlog/research/ADR-0002-AI-Assisted-Screenshot-Validation.md`](../../memlog/research/ADR-0002-AI-Assisted-Screenshot-Validation.md) — Validation philosophy: deterministic first, Vision as perception layer
- [`../../memlog/research/ADR-0005-Native-Screenshot-Flow-And-Pedagogy-Validation.md`](../../memlog/research/ADR-0005-Native-Screenshot-Flow-And-Pedagogy-Validation.md) — ScreenAuditKit package design principles

---

## Open-Source Tools

| Tool | Relevance |
|------|-----------|
| [coremltools](https://github.com/apple/coremltools) | PyTorch → CoreML conversion pipeline for Option B training |
| [Ultralytics YOLOv8](https://github.com/ultralytics/ultralytics) | Candidate detector architecture for Option B |
| [RT-DETR](https://github.com/lyuwenyu/RT-DETR) | Alternative transformer-based detector; good small-object recall |
| [supervision](https://github.com/roboflow/supervision) | Dataset analysis and visualization utilities (Python) |
| [Roboflow](https://roboflow.com) | Dataset management and augmentation (external service; do not upload proprietary screenshots) |
