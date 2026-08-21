import Foundation
import VarFontCore

extension EditorViewModel {
    func otFeatureLabelValue(
        table: String,
        featureTag: String,
        field: String,
        analysis: FontAnalysis?
    ) -> String {
        guard let font = selectedFont else { return "" }
        let rows = OTFeatureLabelEditing.populatedRows(
            labels: analysis?.otFeatureLabels ?? [],
            unlabeled: analysis?.otFeaturesUnlabeled ?? [],
            overrides: font.otFeatureLabelOverrides,
            additions: font.otFeatureLabelAdditions,
            nameidStrategy: project?.nameidStrategy ?? font.options.nameidStrategy
        )
        return rows.first {
            $0.table == table && $0.featureTag == featureTag && $0.field == field
        }?.value ?? ""
    }

    func setOTFeatureLabelValue(table: String, featureTag: String, field: String, value: String) {
        let key = OTFeatureLabelEditing.overrideKey(table: table, featureTag: featureTag, field: field)
        let coalesceKey = Self.otFeatureLabelUndoKey(table: table, featureTag: featureTag, field: field)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        mutateNameTableCosmetic(undoCoalesceKey: coalesceKey) { font in
            // Clearing a pending addition drops the intent (back to unlabeled).
            if trimmed.isEmpty,
               font.otFeatureLabelAdditions.contains(where: {
                   $0.table == table && $0.featureTag == featureTag
               }) {
                font.otFeatureLabelOverrides.removeValue(forKey: key)
                font.otFeatureLabelAdditions.removeAll {
                    $0.table == table && $0.featureTag == featureTag
                }
                return
            }
            // Empty string on an existing label → name-table delete on save (feature stays).
            font.otFeatureLabelOverrides[key] = value
        }
    }

    func addOTFeatureLabel(table: String, featureTag: String, string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = OTFeatureLabelEditing.overrideKey(table: table, featureTag: featureTag, field: "UINameID")
        let coalesceKey = Self.otFeatureLabelUndoKey(table: table, featureTag: featureTag, field: "UINameID")
        mutateNameTableCosmetic(undoCoalesceKey: coalesceKey) { font in
            font.otFeatureLabelOverrides[key] = trimmed
            if !font.otFeatureLabelAdditions.contains(where: {
                $0.table == table && $0.featureTag == featureTag
            }) {
                font.otFeatureLabelAdditions.append(
                    OTFeatureLabelAddition(table: table, featureTag: featureTag, string: trimmed)
                )
                font.otFeatureLabelAdditions.sort {
                    if $0.table != $1.table { return $0.table < $1.table }
                    return $0.featureTag < $1.featureTag
                }
            } else if let index = font.otFeatureLabelAdditions.firstIndex(where: {
                $0.table == table && $0.featureTag == featureTag
            }) {
                font.otFeatureLabelAdditions[index].string = trimmed
            }
        }
    }

    /// Clear the name-table label only. Does not remove the OpenType feature/lookups.
    func clearOTFeatureLabel(table: String, featureTag: String, field: String) {
        setOTFeatureLabelValue(table: table, featureTag: featureTag, field: field, value: "")
    }

    func canRevertOTFeatureLabel(
        table: String,
        featureTag: String,
        field: String,
        analysis: FontAnalysis?
    ) -> Bool {
        guard let font = selectedFont else { return false }
        return OTFeatureLabelEditing.canRevert(
            table: table,
            featureTag: featureTag,
            field: field,
            labels: analysis?.otFeatureLabels ?? [],
            overrides: font.otFeatureLabelOverrides,
            additions: font.otFeatureLabelAdditions
        )
    }

    func revertOTFeatureLabel(table: String, featureTag: String, field: String) {
        let key = OTFeatureLabelEditing.overrideKey(table: table, featureTag: featureTag, field: field)
        mutateNameTableCosmetic(
            undoCoalesceKey: Self.otFeatureLabelUndoKey(table: table, featureTag: featureTag, field: field)
        ) { font in
            font.otFeatureLabelOverrides.removeValue(forKey: key)
            font.otFeatureLabelAdditions.removeAll {
                $0.table == table && $0.featureTag == featureTag
            }
        }
    }

    /// Inventory OpenType feature labels. Prefer `includeSuggestions: false` for a fast
    /// complete feature list; suggestions can be loaded in a follow-up pass.
    func analyzeOTFeatures(
        sourcePath: String,
        includeSuggestions: Bool = false
    ) async throws -> OTFeatureAnalysisResult {
        try Task.checkCancellation()
        do {
            await commitService.ensureWorkerReady()
            try Task.checkCancellation()
            let result = try await commitService.analyzeOTFeatures(
                sourcePath: sourcePath,
                includeSuggestions: includeSuggestions
            )
            if result.ok { return result }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Fall through to one retry after a fresh worker warm-up.
        }
        try Task.checkCancellation()
        await commitService.ensureWorkerReady()
        try Task.checkCancellation()
        let retry = try await commitService.analyzeOTFeatures(
            sourcePath: sourcePath,
            includeSuggestions: includeSuggestions
        )
        guard retry.ok else {
            throw CommitServiceError.invalidHelperOutput(retry.error ?? "analyze_ot_features failed")
        }
        return retry
    }

    func cachedOTFeatureAnalysis(fontID: String, sourcePath: String) -> OTFeatureAnalysisResult? {
        otFeatureAnalysisCache[Self.otFeatureCacheKey(fontID: fontID, sourcePath: sourcePath)]
    }

    func storeOTFeatureAnalysis(fontID: String, sourcePath: String, result: OTFeatureAnalysisResult) {
        guard result.ok else { return }
        otFeatureAnalysisCache[Self.otFeatureCacheKey(fontID: fontID, sourcePath: sourcePath)] = result
    }

    func invalidateOTFeatureAnalysis(fontID: String) {
        let prefix = "\(fontID)|"
        otFeatureAnalysisCache = otFeatureAnalysisCache.filter { !$0.key.hasPrefix(prefix) }
    }

    private static func otFeatureCacheKey(fontID: String, sourcePath: String) -> String {
        "\(fontID)|\(sourcePath)"
    }
}
