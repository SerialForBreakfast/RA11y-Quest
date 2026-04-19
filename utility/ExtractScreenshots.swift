#!/usr/bin/env swift
// Copies PNG attachments from xcresulttool export into a destination folder with
// human-readable names derived from manifest.json. Two arguments: temp export dir, output dir.
//
// Uses Foundation only — local filesystem and JSON parsing only.

import Foundation

let expKeys = ["exportedFileName", "filename", "file", "name"]
let sugKeys = ["suggestedHumanReadableName", "suggestedName", "humanReadableName", "displayName"]

/// Recursively walks JSON to pair exported file names with suggested display names.
func walkJSON(_ obj: Any, nameMap: inout [String: String]) {
    guard let dict = obj as? [String: Any] else {
        if let arr = obj as? [Any] {
            for item in arr { walkJSON(item, nameMap: &nameMap) }
        }
        return
    }
    var exp = ""
    for k in expKeys {
        if let v = dict[k] as? String, !v.isEmpty { exp = v; break }
    }
    var sug = ""
    for k in sugKeys {
        if let v = dict[k] as? String, !v.isEmpty { sug = v; break }
    }
    if !exp.isEmpty, !sug.isEmpty {
        nameMap[exp] = sug
    }
    for v in dict.values {
        walkJSON(v, nameMap: &nameMap)
    }
}

func main() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 2 else {
        fputs("[extract_screenshots] ERROR: Expected <temp-dir> <output-dir>\n", stderr)
        exit(1)
    }
    let tempDir = args[0]
    let outputDir = args[1]

    let fm = FileManager.default
    guard fm.fileExists(atPath: tempDir) else {
        fputs("[extract_screenshots] ERROR: Temp dir missing: \(tempDir)\n", stderr)
        exit(1)
    }
    try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    let contents = try fm.contentsOfDirectory(atPath: tempDir)
    let exportedFiles = contents.filter { name in
        name != "manifest.json" && name.lowercased().hasSuffix(".png")
            && fm.fileExists(atPath: (tempDir as NSString).appendingPathComponent(name))
    }

    if exportedFiles.isEmpty {
        fputs("[extract_screenshots] ERROR: No PNG files found in temp dir.\n", stderr)
        fputs("[extract_screenshots] Temp dir contents: \(contents)\n", stderr)
        exit(1)
    }

    var nameMap: [String: String] = [:]
    let manifestPath = (tempDir as NSString).appendingPathComponent("manifest.json")
    if fm.fileExists(atPath: manifestPath) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
            let json = try JSONSerialization.jsonObject(with: data)
            walkJSON(json, nameMap: &nameMap)
        } catch {
            fputs("[extract_screenshots] WARNING: manifest.json parse error: \(error)\n", stderr)
            fputs("[extract_screenshots] Continuing with original filenames.\n", stderr)
        }
    } else {
        fputs("[extract_screenshots] WARNING: No manifest.json found; using original filenames.\n", stderr)
    }

    let uuidPattern = try NSRegularExpression(
        pattern: #"_0_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(\.[^.]+)?$"#,
        options: []
    )

    /// Strips `_0_<UUID>` before extension, matching the Python `re.sub` behavior.
    func stripUUIDSuffix(_ suggested: String) -> String {
        let ns = suggested as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = uuidPattern.firstMatch(in: suggested, options: [], range: range) else {
            return suggested
        }
        let extRange = match.range(at: 1)
        let ext = extRange.location != NSNotFound ? ns.substring(with: extRange) : ""
        let prefix = ns.substring(with: NSRange(location: 0, length: match.range.location))
        return prefix + ext
    }

    var copied = 0
    for filename in exportedFiles {
        let suggested = nameMap[filename] ?? filename
        let cleanName = stripUUIDSuffix(suggested)

        let src = (tempDir as NSString).appendingPathComponent(filename)
        var dst = (outputDir as NSString).appendingPathComponent(cleanName)

        let baseName = (cleanName as NSString).deletingPathExtension
        let extPart = (cleanName as NSString).pathExtension
        let extSuffix = extPart.isEmpty ? "" : ".\(extPart)"

        var counter = 1
        while fm.fileExists(atPath: dst) {
            let next = extPart.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter)\(extSuffix)"
            dst = (outputDir as NSString).appendingPathComponent(next)
            counter += 1
        }

        try fm.copyItem(atPath: src, toPath: dst)
        print("  Saved: \((dst as NSString).lastPathComponent)")
        copied += 1
    }

    if copied == 0 {
        fputs("[extract_screenshots] ERROR: No screenshots were saved.\n", stderr)
        exit(1)
    }
    print("[extract_screenshots] Done — \(copied) screenshot(s) written to: \(outputDir)")
}

do {
    try main()
} catch {
    fputs("[extract_screenshots] ERROR: \(error)\n", stderr)
    exit(1)
}
