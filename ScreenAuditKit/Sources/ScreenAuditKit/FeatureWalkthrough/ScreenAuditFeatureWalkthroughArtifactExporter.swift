import Foundation

/// Errors raised while copying curated feature-walkthrough outputs into `Docs/FeatureWalkthrough/`.
public enum ScreenAuditFeatureWalkthroughExportError: Error, Equatable, LocalizedError {
    /// The SwiftPM test output directory is missing (run `swift test` for this package first).
    case missingTestArtifacts(path: String)

    /// A source file the exporter expects after a successful walkthrough test run was not found.
    case missingExpectedFile(path: String)

    /// File system copy or removal failed.
    case fileSystemError(path: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case let .missingTestArtifacts(path):
            "Missing walkthrough test artifacts at `\(path)`. Run `swift test` for the ScreenAuditKit package first."
        case let .missingExpectedFile(path):
            "Missing expected walkthrough file: `\(path)`."
        case let .fileSystemError(path, underlying):
            "File system error at `\(path)`: \(underlying)."
        }
    }
}

/// Copies deterministic walkthrough PNGs and ScreenAuditKit reports from SwiftPM test output into
/// `Docs/FeatureWalkthrough/Artifacts` and a flat `Docs/FeatureWalkthrough/images` folder for Markdown.
///
/// This type keeps all walkthrough curation logic inside the ScreenAuditKit package so the same
/// workflow works when the package lives in its own repository.
public struct ScreenAuditFeatureWalkthroughArtifactExporter {
    private static let pathPlaceholder = "<feature-walkthrough-test-output>"
    private let fileManager: FileManager

    /// Creates an exporter using the shared file manager.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Copies curated walkthrough artifacts from `.build/test-artifacts/feature-walkthrough` into docs.
    /// - Parameter packageRoot: Directory containing `Package.swift` for ScreenAuditKit (typically the package checkout root).
    public func export(packageRoot: URL) throws {
        let sourceRoot = packageRoot
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("test-artifacts", isDirectory: true)
            .appendingPathComponent("feature-walkthrough", isDirectory: true)

        guard fileManager.fileExists(atPath: sourceRoot.path) else {
            throw ScreenAuditFeatureWalkthroughExportError.missingTestArtifacts(path: sourceRoot.path)
        }

        let docsRoot = packageRoot
            .appendingPathComponent("Docs", isDirectory: true)
            .appendingPathComponent("FeatureWalkthrough", isDirectory: true)
        let destRoot = docsRoot.appendingPathComponent("Artifacts", isDirectory: true)
        let imageRoot = docsRoot.appendingPathComponent("images", isDirectory: true)

        if fileManager.fileExists(atPath: destRoot.path) {
            try removeItem(at: destRoot)
        }
        try fileManager.createDirectory(at: destRoot, withIntermediateDirectories: true)

        try copyFile(
            sourceRoot.appendingPathComponent("ios-alert-pass/screenshots/screen.png"),
            destRoot.appendingPathComponent("ios-alert/pass.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("ios-alert-fail/screenshots/screen.png"),
            destRoot.appendingPathComponent("ios-alert/fail.png")
        )
        try copyReports(from: sourceRoot, scenario: "ios-alert-fail", into: destRoot, folder: "ios-alert")

        try copyFile(
            sourceRoot.appendingPathComponent("settings-debug-pass/screenshots/screen.png"),
            destRoot.appendingPathComponent("settings-debug/pass.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("settings-debug-fail/screenshots/screen.png"),
            destRoot.appendingPathComponent("settings-debug/fail.png")
        )
        try copyReports(from: sourceRoot, scenario: "settings-debug-fail", into: destRoot, folder: "settings-debug")

        try copyFile(
            sourceRoot.appendingPathComponent("no-ocr-skip/screenshots/screen.png"),
            destRoot.appendingPathComponent("no-ocr/fixture.png")
        )
        try copyReports(from: sourceRoot, scenario: "no-ocr-skip", into: destRoot, folder: "no-ocr")

        try copyFile(
            sourceRoot.appendingPathComponent("baseline-volatile-pass/baselines/screen.png"),
            destRoot.appendingPathComponent("baseline-drift/baseline.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("baseline-volatile-pass/screenshots/screen.png"),
            destRoot.appendingPathComponent("baseline-drift/ignored-volatile-pass.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("baseline-clipped-fail/screenshots/screen.png"),
            destRoot.appendingPathComponent("baseline-drift/clipped-copy-fail.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("baseline-protected-drift/screenshots/screen.png"),
            destRoot.appendingPathComponent("baseline-drift/stable-cta-fail.png")
        )
        try copyReports(from: sourceRoot, scenario: "baseline-clipped-fail", into: destRoot, folder: "baseline-drift")

        try copyFile(
            sourceRoot.appendingPathComponent("device-orientation-pass/screenshots/screen.png"),
            destRoot.appendingPathComponent("device-orientation/pass.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("device-orientation-fail/screenshots/screen.png"),
            destRoot.appendingPathComponent("device-orientation/fail.png")
        )
        try copyReports(from: sourceRoot, scenario: "device-orientation-fail", into: destRoot, folder: "device-orientation")

        try copyFile(
            sourceRoot.appendingPathComponent("tvos-focus-pass/screenshots/screen.png"),
            destRoot.appendingPathComponent("tvos-focus/pass.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("tvos-focus-fail/screenshots/screen.png"),
            destRoot.appendingPathComponent("tvos-focus/fail.png")
        )
        try copyReports(from: sourceRoot, scenario: "tvos-focus-fail", into: destRoot, folder: "tvos-focus")

        try copyFile(
            sourceRoot.appendingPathComponent("mac-toolbar-pass/screenshots/screen.png"),
            destRoot.appendingPathComponent("mac-toolbar/pass.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("mac-toolbar-fail/screenshots/screen.png"),
            destRoot.appendingPathComponent("mac-toolbar/fail.png")
        )
        try copyReports(from: sourceRoot, scenario: "mac-toolbar-fail", into: destRoot, folder: "mac-toolbar")

        try copyFile(
            sourceRoot.appendingPathComponent("visual-artifacts-pass/screenshots/art.png"),
            destRoot.appendingPathComponent("visual-artifacts/pass-art.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("visual-artifacts-fail/screenshots/matte.png"),
            destRoot.appendingPathComponent("visual-artifacts/fail-flat-matte.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("visual-artifacts-fail/screenshots/checker.png"),
            destRoot.appendingPathComponent("visual-artifacts/fail-checkerboard.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("visual-artifacts-fail/screenshots/alpha.png"),
            destRoot.appendingPathComponent("visual-artifacts/fail-opaque-alpha-border.png")
        )
        try copyReports(from: sourceRoot, scenario: "visual-artifacts-fail", into: destRoot, folder: "visual-artifacts")

        try copyFile(
            sourceRoot.appendingPathComponent("flow-completeness-pass/screenshots/01_Welcome.png"),
            destRoot.appendingPathComponent("flow-completeness/pass-01-welcome.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("flow-completeness-pass/screenshots/02_Permissions.png"),
            destRoot.appendingPathComponent("flow-completeness/pass-02-permissions.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("flow-completeness-pass/screenshots/03_Ready.png"),
            destRoot.appendingPathComponent("flow-completeness/pass-03-ready.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("flow-completeness-fail/screenshots/01_Welcome.png"),
            destRoot.appendingPathComponent("flow-completeness/fail-01-welcome.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("flow-completeness-fail/screenshots/03_Ready.png"),
            destRoot.appendingPathComponent("flow-completeness/fail-03-ready.png")
        )
        try copyReports(from: sourceRoot, scenario: "flow-completeness-fail", into: destRoot, folder: "flow-completeness")

        try copyFile(
            sourceRoot.appendingPathComponent("clean-happy-path/screenshots/01_Welcome.png"),
            destRoot.appendingPathComponent("clean-happy-path/01-welcome.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("clean-happy-path/screenshots/02_Permissions.png"),
            destRoot.appendingPathComponent("clean-happy-path/02-permissions.png")
        )
        try copyFile(
            sourceRoot.appendingPathComponent("clean-happy-path/screenshots/03_Ready.png"),
            destRoot.appendingPathComponent("clean-happy-path/03-ready.png")
        )
        try copyReports(from: sourceRoot, scenario: "clean-happy-path", into: destRoot, folder: "clean-happy-path")

        try sanitizeReportPaths(in: destRoot, replacing: sourceRoot.path)

        if fileManager.fileExists(atPath: imageRoot.path) {
            try removeItem(at: imageRoot)
        }
        try fileManager.createDirectory(at: imageRoot, withIntermediateDirectories: true)

        try copyFile(destRoot.appendingPathComponent("ios-alert/pass.png"), imageRoot.appendingPathComponent("ios-alert-pass.png"))
        try copyFile(destRoot.appendingPathComponent("ios-alert/fail.png"), imageRoot.appendingPathComponent("ios-alert-fail.png"))
        try copyFile(destRoot.appendingPathComponent("settings-debug/pass.png"), imageRoot.appendingPathComponent("settings-debug-pass.png"))
        try copyFile(destRoot.appendingPathComponent("settings-debug/fail.png"), imageRoot.appendingPathComponent("settings-debug-fail.png"))
        try copyFile(destRoot.appendingPathComponent("no-ocr/fixture.png"), imageRoot.appendingPathComponent("no-ocr-fixture.png"))
        try copyFile(destRoot.appendingPathComponent("baseline-drift/baseline.png"), imageRoot.appendingPathComponent("baseline-drift-baseline.png"))
        try copyFile(
            destRoot.appendingPathComponent("baseline-drift/ignored-volatile-pass.png"),
            imageRoot.appendingPathComponent("baseline-drift-ignored-volatile-pass.png")
        )
        try copyFile(
            destRoot.appendingPathComponent("baseline-drift/clipped-copy-fail.png"),
            imageRoot.appendingPathComponent("baseline-drift-clipped-copy-fail.png")
        )
        try copyFile(destRoot.appendingPathComponent("device-orientation/pass.png"), imageRoot.appendingPathComponent("device-orientation-pass.png"))
        try copyFile(destRoot.appendingPathComponent("device-orientation/fail.png"), imageRoot.appendingPathComponent("device-orientation-fail.png"))
        try copyFile(destRoot.appendingPathComponent("tvos-focus/pass.png"), imageRoot.appendingPathComponent("tvos-focus-pass.png"))
        try copyFile(destRoot.appendingPathComponent("tvos-focus/fail.png"), imageRoot.appendingPathComponent("tvos-focus-fail.png"))
        try copyFile(destRoot.appendingPathComponent("mac-toolbar/pass.png"), imageRoot.appendingPathComponent("mac-toolbar-pass.png"))
        try copyFile(destRoot.appendingPathComponent("mac-toolbar/fail.png"), imageRoot.appendingPathComponent("mac-toolbar-fail.png"))
        try copyFile(destRoot.appendingPathComponent("visual-artifacts/pass-art.png"), imageRoot.appendingPathComponent("visual-artifacts-pass.png"))
        try copyFile(
            destRoot.appendingPathComponent("visual-artifacts/fail-flat-matte.png"),
            imageRoot.appendingPathComponent("visual-artifacts-fail-flat-matte.png")
        )
        try copyFile(
            destRoot.appendingPathComponent("visual-artifacts/fail-checkerboard.png"),
            imageRoot.appendingPathComponent("visual-artifacts-fail-checkerboard.png")
        )
        try copyFile(
            destRoot.appendingPathComponent("visual-artifacts/fail-opaque-alpha-border.png"),
            imageRoot.appendingPathComponent("visual-artifacts-fail-opaque-alpha-border.png")
        )
        try copyFile(
            destRoot.appendingPathComponent("flow-completeness/pass-01-welcome.png"),
            imageRoot.appendingPathComponent("flow-completeness-pass-welcome.png")
        )
        try copyFile(
            destRoot.appendingPathComponent("flow-completeness/pass-02-permissions.png"),
            imageRoot.appendingPathComponent("flow-completeness-pass-permissions.png")
        )
        try copyFile(
            destRoot.appendingPathComponent("flow-completeness/pass-03-ready.png"),
            imageRoot.appendingPathComponent("flow-completeness-pass-ready.png")
        )
        try copyFile(
            destRoot.appendingPathComponent("flow-completeness/fail-01-welcome.png"),
            imageRoot.appendingPathComponent("flow-completeness-fail-welcome.png")
        )
        try copyFile(
            destRoot.appendingPathComponent("flow-completeness/fail-03-ready.png"),
            imageRoot.appendingPathComponent("flow-completeness-fail-ready.png")
        )
        try copyFile(destRoot.appendingPathComponent("clean-happy-path/01-welcome.png"), imageRoot.appendingPathComponent("clean-happy-path-welcome.png"))
        try copyFile(
            destRoot.appendingPathComponent("clean-happy-path/02-permissions.png"),
            imageRoot.appendingPathComponent("clean-happy-path-permissions.png")
        )
        try copyFile(destRoot.appendingPathComponent("clean-happy-path/03-ready.png"), imageRoot.appendingPathComponent("clean-happy-path-ready.png"))
    }

    private func copyFile(_ source: URL, _ destination: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw ScreenAuditFeatureWalkthroughExportError.missingExpectedFile(path: source.path)
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try removeItem(at: destination)
        }
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw ScreenAuditFeatureWalkthroughExportError.fileSystemError(path: destination.path, underlying: error.localizedDescription)
        }
    }

    private func copyReports(from sourceRoot: URL, scenario: String, into destRoot: URL, folder: String) throws {
        let reports = sourceRoot.appendingPathComponent(scenario, isDirectory: true).appendingPathComponent("reports", isDirectory: true)
        let destFolder = destRoot.appendingPathComponent(folder, isDirectory: true)

        try copyFile(reports.appendingPathComponent("summary.md"), destFolder.appendingPathComponent("summary.md"))
        try copyFile(reports.appendingPathComponent("findings.json"), destFolder.appendingPathComponent("findings.json"))
        try copyFile(reports.appendingPathComponent("evidence.json"), destFolder.appendingPathComponent("evidence.json"))

        let flowSummary = reports.appendingPathComponent("flow-summary.md")
        if fileManager.fileExists(atPath: flowSummary.path) {
            try copyFile(flowSummary, destFolder.appendingPathComponent("flow-summary.md"))
        }

        let overlaySource = reports.appendingPathComponent("overlays", isDirectory: true)
        if fileManager.fileExists(atPath: overlaySource.path) {
            let overlayDest = destFolder.appendingPathComponent("overlays", isDirectory: true)
            try fileManager.createDirectory(at: overlayDest, withIntermediateDirectories: true)
            let contents = try fileManager.contentsOfDirectory(at: overlaySource, includingPropertiesForKeys: [.isDirectoryKey])
            for url in contents {
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard !isDirectory else { continue }
                let name = url.lastPathComponent
                try copyFile(url, overlayDest.appendingPathComponent(name))
            }
        }
    }

    private func sanitizeReportPaths(in destRoot: URL, replacing sourceRootPath: String) throws {
        let escapedSlashes = sourceRootPath.replacingOccurrences(of: "/", with: "\\/")
        guard let enumerator = fileManager.enumerator(at: destRoot, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return
        }
        while let fileURL = enumerator.nextObject() as? URL {
            let isFile = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isFile else { continue }
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "json" || ext == "md" else { continue }
            var text = try String(contentsOf: fileURL, encoding: .utf8)
            text = text.replacingOccurrences(of: sourceRootPath, with: Self.pathPlaceholder)
            text = text.replacingOccurrences(of: escapedSlashes, with: Self.pathPlaceholder)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func removeItem(at url: URL) throws {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ScreenAuditFeatureWalkthroughExportError.fileSystemError(path: url.path, underlying: error.localizedDescription)
        }
    }
}
