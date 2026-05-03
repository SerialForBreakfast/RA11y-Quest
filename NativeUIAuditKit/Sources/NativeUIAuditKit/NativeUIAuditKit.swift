/// NativeUIAuditKit — native Apple UI element detection for screenshot audits.
///
/// Future pipeline:
///   PNG screenshot → VNCoreMLRequest (object detector) + VNRecognizeTextRequest (OCR)
///   → NativeUIElementObservation[] → audit rules → ScreenAuditKit integration
///
/// Current state: scaffold only. No CoreML model or inference logic.
/// Use `NativeUIDetectionRequest` as the entry point once the model is available.
public enum NativeUIAuditKit {
    /// Semantic version of this package.
    public static let version = "0.1.0-scaffold"
}
