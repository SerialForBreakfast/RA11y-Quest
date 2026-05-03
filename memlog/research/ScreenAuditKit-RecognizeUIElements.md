

# ScreenAuditKit Native UI Element Recognition Research

## Purpose

ScreenAuditKit should evolve toward a drop-in native Apple UI detector that can analyze screenshot PNGs and return accurate, structured observations for visible UI elements.

The long-term goal is a local equivalent of a hypothetical `VNRecognizeUIElementRequest`: a Vision-style request that detects Apple platform UI controls, bounds, labels, visible state, truncation/completeness issues, platform/device hints, and accessibility-relevant metadata from screenshots.

This document outlines feasibility, dataset generation strategy, training inputs, Core ML model options, runtime architecture, and research milestones.

## Executive Summary

A real `VNRecognizeUIElementRequest` does not currently exist as a public Apple Vision API. The feasible version is a custom request built from existing Apple platform pieces:

1. Generate deterministic native Apple UIs in SwiftUI/UIKit/AppKit/tvOS/visionOS-style test harnesses.
2. Capture screenshots from known device/OS configurations.
3. Export the same UI hierarchy as structured ground truth.
4. Train an object detection model that identifies native UI element classes and normalized bounds.
5. Combine object detection with `VNRecognizeTextRequest` for visible text and text bounds.
6. Add heuristic and model-based post-processing for OS/device detection, Dynamic Type, truncation, clipping, and accessibility audit rules.
7. Package this as a ScreenAuditKit detector with an API shaped like a Vision request.

The strongest research path is not manually labeling screenshots. It is synthetic-but-native dataset generation where the app that renders the UI also exports the labels, bounds, traits, state, and text metadata.

## Why This Is Plausible

Apple already provides the major building blocks:

- Vision can run custom Core ML models through `VNCoreMLRequest`.
- Vision object detection models return detected object observations with bounding boxes.
- Vision text recognition can extract text and provide bounding boxes for recognized text.
- Create ML supports object detector training from images annotated with labeled bounding boxes.
- Core ML supports on-device model inference, which fits ScreenAuditKit’s privacy and portability goals.

The missing layer is a high-quality Apple UI-specific dataset and a ScreenAuditKit runtime that normalizes model output into an accessibility-focused UI element schema.

## Proposed Public API Shape

ScreenAuditKit should avoid pretending this is a private Apple API. The API can intentionally mirror Vision naming while staying explicit that this is ScreenAuditKit-owned.

```swift
import CoreGraphics
import Foundation

/// Detects visible Apple-platform UI elements from a screenshot image.
///
/// `ScreenAuditRecognizeUIElementRequest` is designed to behave like a Vision request
/// while remaining independent from private Apple APIs. It performs local inference only.
///
/// Concurrency: Instances are immutable after initialization and may be created from any
/// actor. `perform(on:)` should run off the main actor because Core ML and OCR inference
/// can be expensive. UI updates that consume the returned observations must hop back to
/// `MainActor`.
public struct ScreenAuditRecognizeUIElementRequest: Sendable {
    public let configuration: ScreenAuditUIElementDetectionConfiguration

    public init(configuration: ScreenAuditUIElementDetectionConfiguration = .default) {
        self.configuration = configuration
    }

    public func perform(on screenshot: CGImage) async throws -> [ScreenAuditUIElementObservation] {
        // Implementation lives in ScreenAuditKit runtime.
        // Pipeline:
        // 1. Normalize screenshot orientation and scale.
        // 2. Run UI element detector model.
        // 3. Run text recognition.
        // 4. Merge detections into semantic observations.
        // 5. Apply audit heuristics for clipping, truncation, and platform/device hints.
        return []
    }
}
```

```swift
import CoreGraphics
import Foundation

/// A detected native Apple UI element in screenshot coordinates.
public struct ScreenAuditUIElementObservation: Sendable, Identifiable, Codable {
    public let id: UUID
    public let elementType: ScreenAuditUIElementType
    public let boundingBox: CGRect
    public let confidence: Double
    public let visibleText: String?
    public let textBoundingBoxes: [CGRect]
    public let inferredTraits: [ScreenAuditAccessibilityTrait]
    public let state: ScreenAuditUIElementState
    public let issues: [ScreenAuditUIIssue]
}
```

## Detection Scope

### Initial Element Classes

The first model should detect a deliberately small but high-value class set.

- `button`
- `text`
- `image`
- `textField`
- `toggle`
- `slider`
- `segmentedControl`
- `tabBarItem`
- `navigationBar`
- `toolbar`
- `listRow`
- `cell`
- `switch`
- `menuItem`
- `alert`
- `sheet`
- `popover`
- `scrollView`
- `collectionItem`
- `progressIndicator`
- `activityIndicator`
- `stepper`
- `picker`
- `datePicker`

The model does not need to solve the entire semantic hierarchy in version 1. It should first provide reliable visible bounds and coarse role classification.

### Secondary Labels

These should be derived by OCR, metadata, or post-processing rather than treated as primary detector classes:

- selected
- disabled
- focused
- destructive
- primary action
- multiline text
- truncated text
- clipped element
- contrast risk
- tappable target risk
- overlapping elements

### Platform Scope

Start with iOS screenshots because they are the easiest to generate, scale, and validate. Expand in this order:

1. iOS
2. iPadOS
3. tvOS
4. macOS
5. visionOS screenshots/captures, when a reliable capture workflow exists

## Dataset Strategy

### Core Principle

Do not rely primarily on manual annotation. Generate UI screens from Swift source and export ground truth at render time.

Each generated screen should produce:

- Screenshot PNG.
- JSON annotation file with element bounds.
- UI hierarchy metadata.
- Accessibility labels, values, hints, and traits.
- Visible text strings.
- Dynamic Type size.
- Color scheme.
- Locale.
- Device family.
- Screenshot dimensions.
- OS version.
- Scale factor.
- Safe area insets.
- Known issue flags, such as intentional clipping or truncation.

### Dataset Folder Layout

```text
ScreenAuditDataset/
  manifest.json
  schemas/
    screen_audit_annotation.schema.json
    screen_audit_generation_config.schema.json
  train/
    images/
      ios_iphone_15_pro_26_3_light_xl_000001.png
    annotations/
      ios_iphone_15_pro_26_3_light_xl_000001.json
  validation/
    images/
    annotations/
  test/
    images/
    annotations/
  generated_sources/
    SwiftUI/
    UIKit/
    AppKit/
  reports/
    dataset_balance.md
    class_distribution.json
    issue_distribution.json
```

### Annotation Schema

```json
{
  "schemaVersion": "1.0",
  "image": {
    "fileName": "ios_iphone_15_pro_26_3_light_xl_000001.png",
    "width": 1179,
    "height": 2556,
    "scale": 3,
    "platform": "iOS",
    "osVersion": "26.3",
    "deviceName": "iPhone 15 Pro",
    "interfaceIdiom": "phone",
    "orientation": "portrait",
    "colorScheme": "light",
    "dynamicTypeSize": "accessibilityExtraLarge",
    "locale": "en_US",
    "safeAreaInsets": {
      "top": 59,
      "left": 0,
      "bottom": 34,
      "right": 0
    }
  },
  "elements": [
    {
      "id": "login_button_primary",
      "elementType": "button",
      "framework": "SwiftUI",
      "boundsPixels": {
        "x": 72,
        "y": 1848,
        "width": 1035,
        "height": 156
      },
      "boundsNormalizedVision": {
        "x": 0.0611,
        "y": 0.2159,
        "width": 0.8779,
        "height": 0.0610
      },
      "visibleText": "Continue",
      "accessibilityLabel": "Continue",
      "accessibilityValue": null,
      "accessibilityHint": "Starts the next step.",
      "traits": ["button"],
      "state": {
        "isEnabled": true,
        "isSelected": false,
        "isFocused": false
      },
      "knownIssues": []
    }
  ]
}
```

### Coordinate Systems

The dataset must store bounds in multiple coordinate systems because Apple APIs differ by context.

- Pixel-space top-left origin: easiest for screenshots and visual overlays.
- Point-space top-left origin: easiest for UIKit/SwiftUI layout export.
- Vision normalized bottom-left origin: easiest for Vision observations.

The annotation exporter should always write all three when possible. The training pipeline can select the format required by Create ML, coremltools, or a custom PyTorch training path.

## Native UI Generation Approach

### Generator App

Build a dedicated `ScreenAuditDatasetGenerator` app target.

Responsibilities:

- Render many native UI permutations.
- Capture screenshots at stable points after layout completes.
- Export matching annotation JSON.
- Randomize controlled variables.
- Run in simulator/device automation.
- Support deterministic seeds for reproducibility.

### SwiftUI Generation

SwiftUI is the fastest way to generate large UI variation.

Generate screens from composable templates:

- Login form
- Settings screen
- List/detail
- Alert/sheet
- Media card grid
- Tab view
- Navigation stack
- Search results
- Form with validation
- Empty state
- Error state
- Loading state
- Paywall-style layout
- Onboarding pages
- Game HUD screens from RA11y

Each template should expose randomized but bounded inputs:

- Text length
- Button style
- Image/icon presence
- Color scheme
- Dynamic Type size
- Enabled/disabled state
- Selected/unselected state
- Layout density
- Orientation
- Locale
- Right-to-left layout direction
- Safe area variation
- Toolbar/navigation presence

### UIKit/AppKit Generation

SwiftUI alone will overfit the detector to SwiftUI rendering. Include UIKit and AppKit generator targets for native controls that render differently.

UIKit templates should include:

- `UIButton`
- `UILabel`
- `UITextField`
- `UITextView`
- `UISwitch`
- `UISlider`
- `UISegmentedControl`
- `UITableViewCell`
- `UICollectionViewCell`
- `UIAlertController`
- `UISheetPresentationController`
- `UITabBar`
- `UINavigationBar`

AppKit templates should include:

- `NSButton`
- `NSTextField`
- `NSSwitch`
- `NSSlider`
- `NSTableView`
- `NSCollectionView`
- `NSToolbar`
- `NSAlert`

### tvOS Generation

tvOS is especially important for focus-state detection.

Include:

- Focused and unfocused buttons.
- Shelf/card layouts.
- Collection rows.
- Playback controls.
- Large content viewer states.
- VoiceOver focus rings when testable.

### Known-Bad UI Generation

The detector should not only identify controls. It should identify accessibility and UI completeness risks.

Generate intentional failures:

- Truncated labels.
- Text clipped by parent bounds.
- Overlapping controls.
- Hit targets below minimum size expectations.
- Text hidden behind safe areas.
- Insufficient spacing between tappable controls.
- Disabled controls that look enabled.
- Image-only buttons with missing labels in metadata.
- Dynamic Type overflow.
- Landscape layouts that cut off important controls.
- Right-to-left mirroring failures.

These examples should be explicitly labeled as known issues so ScreenAuditKit can validate audit rules.

## Training Model Options

### Option A: Create ML Object Detector

Best for the first prototype.

Pros:

- Apple-native workflow.
- Designed for Core ML output.
- Lower setup cost.
- Good for proving feasibility.

Cons:

- Less control over architecture and loss functions.
- May not be ideal for very small controls or dense UI scenes.
- Dataset export format must be carefully validated.

Use Create ML for the first vertical slice:

1. Train on 5-8 classes.
2. Use generated annotations.
3. Export `.mlmodel` or `.mlpackage`.
4. Run inference through Vision.
5. Evaluate bounding box IoU and class accuracy.

### Option B: YOLO/DETR-Style Detector Converted to Core ML

Best for higher performance and denser UI scenes after the data pipeline is proven.

Pros:

- Strong object detection ecosystem.
- Better tuning options.
- Easier to compare model sizes and speed.
- Potentially better small-object detection with the right architecture.

Cons:

- More training infrastructure.
- Conversion and output decoding must be validated.
- Additional maintenance cost.

Use this once the generated dataset is stable and there is a benchmark suite.

### Option C: Hybrid Detector + OCR + Heuristics

This should be the production architecture.

The object detector identifies visual UI regions. OCR extracts text. Heuristics and optional metadata merge both into useful UI observations.

Example:

- Detector finds a `button` at bounds A.
- OCR finds “Continue” at bounds B inside A.
- Metadata/post-processing labels the element as a primary button with visible text “Continue”.
- Audit rules verify that the text is not clipped and the button is large enough.

## Runtime Architecture

```text
Screenshot PNG / CGImage
  ↓
Image normalization
  ↓
Platform/device preflight
  ↓
UI element object detector model
  ↓
Vision text recognition
  ↓
Observation merger
  ↓
Accessibility/UI audit heuristics
  ↓
ScreenAuditUIElementObservation[]
  ↓
Overlay renderer / JSON report / test assertions
```

### Runtime Components

```text
ScreenAuditKit/
  Sources/
    ScreenAuditKit/
      Detection/
        ScreenAuditRecognizeUIElementRequest.swift
        ScreenAuditUIElementDetector.swift
        ScreenAuditTextRecognizer.swift
        ScreenAuditObservationMerger.swift
      Models/
        ScreenAuditUIElementObservation.swift
        ScreenAuditUIElementType.swift
        ScreenAuditUIIssue.swift
      DeviceInference/
        ScreenAuditDeviceClassifier.swift
        ScreenAuditSafeAreaAnalyzer.swift
      AuditRules/
        ScreenAuditTruncationRule.swift
        ScreenAuditTargetSizeRule.swift
        ScreenAuditOverlapRule.swift
      Rendering/
        ScreenAuditOverlayRenderer.swift
```

## Device and OS Detection

Device and OS detection from a screenshot alone should be treated as probabilistic.

Useful signals:

- Screenshot pixel dimensions.
- Scale factor if known from metadata.
- Safe area geometry.
- Status bar height.
- Dynamic Island/notch shape.
- Home indicator region.
- Navigation bar and tab bar metrics.
- tvOS focus ring styling.
- macOS window chrome style.
- visionOS window ornaments, if captured.

Best practice:

- Prefer explicit metadata when the screenshot is captured by ScreenAuditKit.
- Use image-only inference only when metadata is unavailable.
- Return confidence and multiple candidates, not a single hard-coded guess.

Example:

```swift
public struct ScreenAuditDeviceInference: Sendable, Codable {
    public let platform: ScreenAuditPlatform
    public let deviceCandidates: [ScreenAuditDeviceCandidate]
    public let inferredOSMajorVersion: Int?
    public let confidence: Double
}
```

## Training Best Practices

### Data Splits

Use screen-template-aware splits, not only random image splits.

Bad split:

- Same generated screen template appears in train, validation, and test with small parameter changes.

Better split:

- Some templates are withheld entirely from training.
- Some devices are withheld from training.
- Some Dynamic Type sizes are withheld from training.
- Some locales are withheld from training.

This measures generalization instead of memorization.

### Minimum Dataset Dimensions

For the first prototype:

- 5-8 classes.
- 10-15 screen templates.
- 5,000-10,000 generated screenshots.
- Balanced light/dark mode.
- Several Dynamic Type sizes.
- At least 3 phone dimensions.
- At least 1 iPad dimension.

For a production-quality model:

- 20-30 classes.
- 50+ screen templates.
- 100,000+ generated screenshots.
- Real app screenshots with safe internal annotations where possible.
- Device, OS, locale, orientation, color scheme, and Dynamic Type coverage.

### Augmentation

Use augmentation carefully. UI screenshots are not natural images.

Recommended:

- Slight compression variation.
- Light blur/noise for screenshot sharing artifacts.
- Minor brightness/contrast variation.
- Cropping only when modeling partial screenshots intentionally.

Avoid or restrict:

- Large rotations.
- Heavy perspective transforms.
- Wild color jitter.
- Random cutouts that create impossible UI.

### Metrics

Track model metrics and ScreenAudit-specific metrics.

Model metrics:

- mAP by class.
- IoU by class.
- Precision/recall by class.
- Small object recall.
- False positive rate on decorative images.

ScreenAudit metrics:

- Button detection recall.
- Text/control association accuracy.
- Truncation issue detection accuracy.
- Overlap issue detection accuracy.
- Device inference confidence calibration.
- Inference time by device.
- Model size.

## Ground Truth Export Techniques

### SwiftUI

SwiftUI does not expose every layout detail directly in the same way UIKit does. Use a combination of controlled layout wrappers and accessibility identifiers.

Preferred approach:

- Wrap generated elements in known components.
- Assign stable IDs.
- Use geometry readers/preference keys to export frames.
- Capture after layout stabilization.
- Store point-space frames and convert to pixel-space using screen scale.

### UIKit

UIKit can export frames more directly.

Preferred approach:

- Traverse the view hierarchy.
- Read `frame`, `bounds`, `accessibilityFrame`, `accessibilityLabel`, `accessibilityValue`, `accessibilityHint`, and traits.
- Convert frames into screenshot coordinate space.
- Export hidden/clipped state.

### AppKit

Preferred approach:

- Traverse `NSView` hierarchy.
- Read accessibility role/label where available.
- Convert bounds through window/screen coordinate spaces.
- Capture window screenshots with matching scale metadata.

## ScreenAuditKit Output Format

ScreenAuditKit should support both in-memory Swift observations and JSON reports.

```json
{
  "screen": {
    "width": 1179,
    "height": 2556,
    "platformInference": {
      "platform": "iOS",
      "confidence": 0.94
    }
  },
  "observations": [
    {
      "elementType": "button",
      "confidence": 0.982,
      "boundsPixels": {
        "x": 72,
        "y": 1848,
        "width": 1035,
        "height": 156
      },
      "visibleText": "Continue",
      "issues": []
    }
  ]
}
```

## Feasibility Risks

### Risk: Synthetic Data Overfitting

The model may learn the generator’s visual style instead of Apple UI primitives.

Mitigation:

- Use SwiftUI, UIKit, and AppKit generators.
- Include real app screenshots where legally and ethically allowed.
- Withhold entire screen families for testing.
- Randomize typography, text length, spacing, state, and layout composition.

### Risk: Text Recognition Is Not Enough

OCR can identify visible words but not semantic roles.

Mitigation:

- Use object detection for role and bounds.
- Use OCR only for visible text extraction.
- Merge OCR text into detected UI regions.

### Risk: Small Controls Are Hard

Tiny icons, toolbar buttons, and tab bar items may be missed.

Mitigation:

- Train at realistic screenshot resolution.
- Track small-object recall separately.
- Consider tiling large screenshots during inference.
- Use class-specific confidence thresholds.

### Risk: Screenshots Do Not Include Accessibility Metadata

A PNG alone cannot prove the true accessibility label, hint, or action.

Mitigation:

- Be explicit: image-only detection infers visible semantics only.
- When ScreenAuditKit captures the screen in-app, pair PNG with exported accessibility metadata.
- Use model output to flag probable issues, not claim certainty where metadata is unavailable.

### Risk: Apple UI Changes Across OS Versions

Control appearance can change between OS releases.

Mitigation:

- Version generated screenshots by OS.
- Keep model training data current for current and previous OS versions.
- Add per-OS evaluation reports.
- Keep the detector modular so model versions can be swapped.

## Research Milestones

### Milestone 1: Dataset Schema and Generator Prototype

Deliverables:

- Annotation JSON schema.
- SwiftUI generator with 3 templates.
- Screenshot and annotation exporter.
- 500 generated images.
- Visual overlay validation tool.

Acceptance criteria:

- Every generated screenshot has a matching annotation file.
- Bounds align with rendered controls in overlay validation.
- Dataset includes light/dark mode and at least 3 Dynamic Type sizes.

### Milestone 2: First Create ML Detector

Deliverables:

- 5-class detector: `button`, `text`, `textField`, `toggle`, `image`.
- Core ML model integrated into ScreenAuditKit.
- Basic `ScreenAuditRecognizeUIElementRequest` API.
- JSON report output.

Acceptance criteria:

- Detector returns normalized and pixel bounds.
- Inference runs locally.
- Test screenshots produce overlay output.
- Evaluation report includes precision, recall, and IoU by class.

### Milestone 3: OCR and Observation Merging

Deliverables:

- Text recognition layer.
- OCR-to-element association.
- Visible text in observations.
- Text clipping/truncation prototype rule.

Acceptance criteria:

- Buttons and text fields are associated with visible text where present.
- Known truncated labels are flagged in generated test cases.
- False positives are documented and added to regression data.

### Milestone 4: Device/OS Inference

Deliverables:

- Device inference component.
- Screenshot dimension/safe-area heuristic database.
- Optional visual classifier for notch/Dynamic Island/home indicator features.

Acceptance criteria:

- Captured screenshots with metadata return exact platform/device info.
- Metadata-free screenshots return candidate devices with confidence.
- Ambiguous dimensions return multiple candidates instead of overclaiming.

### Milestone 5: Production-Quality Dataset Expansion

Deliverables:

- UIKit generator.
- tvOS generator.
- Known-bad UI issue generator.
- Dataset balance report.
- Regression benchmark suite.

Acceptance criteria:

- Dataset covers 20+ UI classes.
- Known-bad UI examples are labeled and testable.
- Withheld-template evaluation is tracked separately from random validation.

## Recommended Initial Implementation Plan

1. Create `ScreenAuditDatasetGenerator` as a separate app target.
2. Define `screen_audit_annotation.schema.json`.
3. Build 3 SwiftUI templates with stable element IDs.
4. Export screenshots and annotation JSON from simulator runs.
5. Build a simple overlay viewer to validate labels and bounds.
6. Train a Create ML object detector on 5 classes.
7. Add a ScreenAuditKit runtime wrapper around `VNCoreMLRequest`.
8. Add `VNRecognizeTextRequest` as a second pass.
9. Merge detections and OCR into `ScreenAuditUIElementObservation`.
10. Add audit rules for truncation, clipping, overlap, and target size.

## References

- Apple Developer Documentation: Vision framework. https://developer.apple.com/documentation/vision
- Apple Developer Documentation: `VNCoreMLRequest`. https://developer.apple.com/documentation/vision/vncoremlrequest
- Apple Developer Documentation: Core ML. https://developer.apple.com/documentation/coreml
- Apple Developer Documentation: Create ML. https://developer.apple.com/documentation/createml
- Apple Developer Documentation: Building an object detector data source. https://developer.apple.com/documentation/createml/building-an-object-detector-data-source
- Apple Developer Documentation: Create ML bounding box annotation type. https://developer.apple.com/documentation/createml/mlobjectdetector/annotationtype/boundingbox(units:origin:anchor:)
- Apple Developer Documentation: Recognizing text in images. https://developer.apple.com/documentation/vision/recognizing-text-in-images
- Apple Developer Documentation: Locating and displaying recognized text. https://developer.apple.com/documentation/vision/locating-and-displaying-recognized-text
- Apple Developer Documentation: `VNDetectedObjectObservation.boundingBox`. https://developer.apple.com/documentation/vision/vndetectedobjectobservation/boundingbox
- Apple Core ML Tools Guide: `MLModel` overview. https://apple.github.io/coremltools/docs-guides/source/mlmodel.html