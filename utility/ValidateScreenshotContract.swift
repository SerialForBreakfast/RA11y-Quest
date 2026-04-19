#!/usr/bin/env swift
// Validates alignment between Fastfile screenshot allowlist, UI tests, route catalog,
// and iOSScreenshotScene. Run from validate_screenshot_contract.sh (four path arguments).
//
// Uses Foundation only — no network, no dynamic code loading.

import Foundation

enum ContractError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        if case .message(let s) = self { return s }
        return ""
    }
}

func readFile(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func main() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 4 else {
        throw ContractError.message("Expected 4 arguments: Fastfile, UI test, catalog, scene file")
    }
    let fastfilePath = args[0]
    let uiPath = args[1]
    let catalogPath = args[2]
    let scenePath = args[3]

    let fastfile = try readFile(fastfilePath)
    let uiFile = try readFile(uiPath)
    let catalog = try readFile(catalogPath)
    let sceneFile = try readFile(scenePath)

    var errors: [String] = []

    // 1) Allowlisted test methods from Fastfile
    let methodPattern = try NSRegularExpression(
        pattern: #"RA11y-iOSUITests/RA11y_iOSScreenshots/(testScreenshots_[A-Za-z0-9_]+)"#,
        options: []
    )
    var allowlisted: Set<String> = []
    let fastRange = NSRange(fastfile.startIndex..., in: fastfile)
    methodPattern.enumerateMatches(in: fastfile, options: [], range: fastRange) { result, _, _ in
        guard let r = result, r.numberOfRanges >= 2,
              let range = Range(r.range(at: 1), in: fastfile) else { return }
        allowlisted.insert(String(fastfile[range]))
    }
    if allowlisted.isEmpty {
        errors.append("Fastfile has no allowlisted screenshot test methods.")
    }

    // 2) Each allowlisted method exists in UI test file
    for method in allowlisted.sorted() {
        if !uiFile.contains("func \(method)()") {
            errors.append("Allowlisted method missing in UI test file: \(method)")
        }
    }

    // 3) Scene IDs from iOSScreenshotScene
    let scenePattern = try NSRegularExpression(pattern: #"case\s+\w+\s*=\s*"([^"]+)""#, options: [])
    var sceneIDs = Set<String>()
    let sceneRange = NSRange(sceneFile.startIndex..., in: sceneFile)
    scenePattern.enumerateMatches(in: sceneFile, options: [], range: sceneRange) { result, _, _ in
        guard let r = result, r.numberOfRanges >= 2,
              let range = Range(r.range(at: 1), in: sceneFile) else { return }
        sceneIDs.insert(String(sceneFile[range]))
    }
    if sceneIDs.isEmpty {
        errors.append("Screenshot scene file defines no scene IDs.")
    }

    // 4) Catalog rows
    var rows: [[String]] = []
    for line in catalog.split(separator: "\n", omittingEmptySubsequences: false) {
        let lineStr = String(line)
        guard lineStr.trimmingCharacters(in: .whitespaces).hasPrefix("|"),
              lineStr.contains("`testScreenshots_") else { continue }
        let parts = lineStr.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        if parts.count >= 7 {
            rows.append(parts)
        }
    }
    if rows.isEmpty {
        errors.append("ScreenshotRouteCatalog.md has no screenshot rows with test methods.")
    }

    let methodCellPattern = try NSRegularExpression(pattern: #"`(testScreenshots_[A-Za-z0-9_]+)`"#, options: [])
    let backtickPattern = try NSRegularExpression(pattern: #"`([^`]+)`"#, options: [])

    for parts in rows {
        guard parts.count > 5 else { continue }
        let fileName = parts[1]
        let methodCell = parts[2]
        let sceneCell = parts[4]
        let anchorCell = parts[5]

        let methodRange = NSRange(methodCell.startIndex..., in: methodCell)
        guard let methodMatch = methodCellPattern.firstMatch(in: methodCell, options: [], range: methodRange),
              methodMatch.numberOfRanges >= 2,
              let mRange = Range(methodMatch.range(at: 1), in: methodCell) else {
            errors.append("Catalog row missing method: \(fileName)")
            continue
        }
        let method = String(methodCell[mRange])
        if !allowlisted.contains(method) {
            errors.append("Catalog method not in Fastfile allowlist: \(method)")
        }

        let sceneRange = NSRange(sceneCell.startIndex..., in: sceneCell)
        if let sceneMatch = backtickPattern.firstMatch(in: sceneCell, options: [], range: sceneRange),
           sceneMatch.numberOfRanges >= 2,
           let sRange = Range(sceneMatch.range(at: 1), in: sceneCell) {
            let scene = String(sceneCell[sRange])
            if !sceneIDs.contains(scene) {
                errors.append("Catalog scene not defined in iOSScreenshotScene.swift: \(scene)")
            }
        } else {
            errors.append("Catalog row missing scene ID: \(fileName)")
        }

        let anchorRange = NSRange(anchorCell.startIndex..., in: anchorCell)
        if let anchorMatch = backtickPattern.firstMatch(in: anchorCell, options: [], range: anchorRange),
           anchorMatch.numberOfRanges >= 2,
           let aRange = Range(anchorMatch.range(at: 1), in: anchorCell) {
            let anchor = String(anchorCell[aRange])
            if !uiFile.contains(anchor) && !sceneFile.contains(anchor) {
                errors.append("Catalog anchor not referenced in tests or scene contract: \(anchor)")
            }
        }
    }

    if !uiFile.contains("\"-screenshotScene\"") {
        errors.append("UI test file must launch scenes via \"-screenshotScene\".")
    }
    if !fastfile.contains("expected_screenshot_files") {
        errors.append("Fastfile must validate extracted screenshots against the catalog.")
    }

    if !errors.isEmpty {
        fputs("[screenshot-contract] Validation failed:\n", stderr)
        for err in errors {
            fputs("- \(err)\n", stderr)
        }
        exit(1)
    }
    print("[screenshot-contract] OK: Fastfile allowlist, screenshot scenes, and route catalog are aligned.")
}

do {
    try main()
} catch {
    fputs("[screenshot-contract] ERROR: \(error)\n", stderr)
    exit(1)
}
