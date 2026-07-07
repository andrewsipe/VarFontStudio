import Foundation

public struct FileClarifierInferenceResult: Equatable, Sendable {
    public var clarifiers: [FileClarifier]
    public var elidedFallbackOverride: String?

    public init(clarifiers: [FileClarifier] = [], elidedFallbackOverride: String? = nil) {
        self.clarifiers = clarifiers
        self.elidedFallbackOverride = elidedFallbackOverride
    }
}

public enum FileClarifierInference {
    public static func infer(
        sourceURL: URL,
        analysis: FontAnalysis?,
        font: FontDocument
    ) -> FileClarifierInferenceResult {
        let skipped = skippedCategories(font: font)
        let basename = sourceURL.deletingPathExtension().lastPathComponent
        let haystack = "\(basename) \(analysis?.source.fullName ?? "")"

        var clarifiers: [FileClarifier] = []

        if !skipped.contains(.slope), let slope = inferSlope(haystack: haystack, analysis: analysis) {
            clarifiers.append(FileClarifier(category: .slope, label: slope))
        }
        if !skipped.contains(.width),
           let width = inferLabelFromStopNames(basename: basename, axisTag: "wdth", font: font) {
            clarifiers.append(FileClarifier(category: .width, label: width))
        }
        if !skipped.contains(.optical),
           let optical = inferLabelFromStopNames(basename: basename, axisTag: "opsz", font: font) {
            clarifiers.append(FileClarifier(category: .optical, label: optical))
        }

        clarifiers = dedupeCategories(clarifiers)

        var elidedOverride: String?
        if clarifiers.contains(where: { $0.category == .slope }),
           let defaultName = analysis?.instancesExisting.first(where: { inst in
               inst.coords["wght"] == 400 || inst.coords["wght"] == 400.0
           })?.composedName ?? analysis?.instancesExisting.first?.composedName {
            if defaultName == "Italic" || defaultName.hasSuffix(" Italic") {
                elidedOverride = defaultName == "Italic" ? "Italic" : nil
            }
        }

        return FileClarifierInferenceResult(
            clarifiers: clarifiers,
            elidedFallbackOverride: elidedOverride
        )
    }

    /// Categories that should not receive inferred clarifiers on this file.
    public static func skippedCategories(font: FontDocument) -> Set<FileClarifierCategory> {
        ClarifierSlotCoverage.skippedCategories(font: font)
    }

    private static func inferSlope(haystack: String, analysis: FontAnalysis?) -> String? {
        let lower = haystack.lowercased()
        if lower.contains("oblique") { return "Oblique" }
        if lower.contains("italic") { return "Italic" }
        if analysis?.inferred.isItalicFont == true { return "Italic" }
        return nil
    }

    /// Match a filename token against axis stop names; return the stop label as stored in the font.
    private static func inferLabelFromStopNames(
        basename: String,
        axisTag: String,
        font: FontDocument
    ) -> String? {
        guard let axis = font.axes.first(where: { $0.tag == axisTag }) else { return nil }
        let lowerBasename = basename.lowercased()
        let candidates = axis.values
            .map(\.name)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.count > $1.count }
        for name in candidates where lowerBasename.contains(name.lowercased()) {
            return name
        }
        return nil
    }

    private static func dedupeCategories(_ clarifiers: [FileClarifier]) -> [FileClarifier] {
        var seen = Set<FileClarifierCategory>()
        var result: [FileClarifier] = []
        for item in clarifiers {
            guard !seen.contains(item.category) else { continue }
            seen.insert(item.category)
            result.append(item)
        }
        return result
    }
}
