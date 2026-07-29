import Foundation
import VarFontCore

extension EditorViewModel {
    func refreshPendingExportKeys() {
        pendingExportRefreshTask?.cancel()
        guard let plan = instancePlan, let font = selectedFont else {
            pendingExportInstanceKeys = []
            return
        }

        let fontID = font.id
        let sourcePath = font.sourcePath
        let planSnapshot = plan
        let bookmark = sourceBookmarks[fontID]

        pendingExportRefreshTask = Task { @MainActor in
            let pending: Set<String>
            do {
                let analysis = try await Task.detached(priority: .userInitiated) {
                    try SourceFontAccess.withReadableSourceURL(
                        bookmark: bookmark,
                        fallbackPath: sourcePath
                    ) { sourceURL in
                        try FontAnalysisReader.analyzeForCommitDiff(url: sourceURL)
                    }
                }.value
                guard !Task.isCancelled else { return }
                pending = InstanceExportPending.pendingIncludedKeys(plan: planSnapshot, analysis: analysis)
            } catch {
                pending = []
            }

            guard !Task.isCancelled,
                  selectedFontID == fontID,
                  selectedFont?.sourcePath == sourcePath else { return }

            pendingExportInstanceKeys = pending
            refreshInstanceListDisplay()
        }
    }
}
