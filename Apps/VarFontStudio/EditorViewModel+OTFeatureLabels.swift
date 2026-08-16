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
        guard let fontID = selectedFontID else { return }
        let key = OTFeatureLabelEditing.overrideKey(table: table, featureTag: featureTag, field: field)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        mutateFont(id: fontID) { font in
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
        guard let fontID = selectedFontID else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = OTFeatureLabelEditing.overrideKey(table: table, featureTag: featureTag, field: "UINameID")
        mutateFont(id: fontID) { font in
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
        guard let fontID = selectedFontID else { return }
        let key = OTFeatureLabelEditing.overrideKey(table: table, featureTag: featureTag, field: field)
        mutateFont(id: fontID) { font in
            font.otFeatureLabelOverrides.removeValue(forKey: key)
            font.otFeatureLabelAdditions.removeAll {
                $0.table == table && $0.featureTag == featureTag
            }
        }
    }

    func analyzeOTFeatures(sourcePath: String) async -> OTFeatureAnalysisResult? {
        do {
            return try await commitService.analyzeOTFeatures(sourcePath: sourcePath)
        } catch {
            return nil
        }
    }
}
