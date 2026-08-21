import Foundation
import VarFontCore

extension EditorViewModel {
    /// Effective Names-panel value (override / PS prefix / empty).
    func windowsNameValue(nameID: Int, analysis: FontAnalysis?) -> String {
        guard let font = selectedFont else { return "" }
        let rows = WindowsNameTableEditing.populatedRows(
            windowsNameTable: analysis?.windowsNameTable ?? [],
            overrides: font.windowsNameOverrides,
            removals: font.windowsNameRemovals,
            familyPSPrefix: font.options.familyPSPrefix
        )
        return rows.first(where: { $0.nameID == nameID })?.value ?? ""
    }

    /// Editing a field never removes its row — clearing the text leaves an empty override
    /// so the user can retype. Only the remove control takes an ID out of the panel.
    func setWindowsNameValue(nameID: Int, value: String) {
        guard let fontID = selectedFontID else { return }
        if nameID == 25 {
            let coalesceKey = Self.windowsNameUndoKey(25)
            mutateNameTableCosmetic(undoCoalesceKey: coalesceKey) { font in
                font.windowsNameOverrides.removeValue(forKey: WindowsNameTableEditing.overrideKey(25))
                font.windowsNameRemovals.removeAll { $0 == 25 }
            }
            setFamilyPSPrefix(value, for: fontID, undoCoalesceKey: coalesceKey)
            return
        }
        guard OpenTypeNameTable.editableLowNameIDs.contains(nameID) else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateNameTableCosmetic(undoCoalesceKey: Self.windowsNameUndoKey(nameID)) { font in
            font.windowsNameOverrides[key] = value
            font.windowsNameRemovals.removeAll { $0 == nameID }
        }
    }

    func addWindowsNameID(_ nameID: Int) {
        guard selectedFontID != nil else { return }
        guard OpenTypeNameTable.editableLowNameIDs.contains(nameID) else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateNameTableCosmetic(undoCoalesceKey: Self.windowsNameUndoKey(nameID)) { font in
            let wasRemoved = font.windowsNameRemovals.contains(nameID)
            font.windowsNameRemovals.removeAll { $0 == nameID }
            // Restoring a removal brings back the file record (or ID 25 + PS prefix);
            // a fresh add starts as an empty draft row.
            if wasRemoved {
                font.windowsNameOverrides.removeValue(forKey: key)
            } else if nameID != 25, font.windowsNameOverrides[key] == nil {
                font.windowsNameOverrides[key] = ""
            }
        }
    }

    func applyWindowsNamePolicy(nameID: Int, value: String) {
        setWindowsNameValue(nameID: nameID, value: value)
    }

    func canRevertWindowsName(nameID: Int, analysis: FontAnalysis?) -> Bool {
        guard let font = selectedFont else { return false }
        return WindowsNameTableEditing.canRevert(
            nameID: nameID,
            windowsNameTable: analysis?.windowsNameTable ?? [],
            overrides: font.windowsNameOverrides,
            removals: font.windowsNameRemovals
        )
    }

    /// Remove the entire name ID from the panel / export. Does not clear `familyPSPrefix` for ID 25.
    func removeWindowsNameID(_ nameID: Int, analysis: FontAnalysis? = nil) {
        guard WindowsNameTableEditing.canRemove(nameID: nameID) else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateNameTableCosmetic(undoCoalesceKey: Self.windowsNameUndoKey(nameID)) { font in
            // Drop any draft edit with it, so restoring the ID shows the file record.
            font.windowsNameOverrides.removeValue(forKey: key)
            if !font.windowsNameRemovals.contains(nameID) {
                font.windowsNameRemovals.append(nameID)
                font.windowsNameRemovals.sort()
            }
        }
    }

    /// Discard the pending edit so the row shows the record currently in the font file.
    func revertWindowsName(nameID: Int) {
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateNameTableCosmetic(undoCoalesceKey: Self.windowsNameUndoKey(nameID)) { font in
            font.windowsNameOverrides.removeValue(forKey: key)
            font.windowsNameRemovals.removeAll { $0 == nameID }
        }
    }

    // MARK: - Push shared names (master → siblings)

    func requestPushMasterNames() {
        workspace.confirmPushNames = true
    }

    func confirmPushNamesAction() {
        workspace.confirmPushNames = false
        Task { await pushMasterNamesToAllFonts() }
    }

    func pushNamesConfirmationMessage() -> String {
        let count = max((project?.fonts.count ?? 1) - 1, 0)
        let ids = NameTableMerge.pushableNameIDs.map(String.init).joined(separator: ", ")
        if count == 1 {
            return "This will copy name IDs \(ids) and matching OpenType feature labels from the master onto 1 file."
        }
        return "This will copy name IDs \(ids) and matching OpenType feature labels from the master onto \(count) files."
    }

    func pushMasterNamesToAllFonts() async {
        guard let project, let projectID = activeProjectID,
              let masterID = masterFontID(for: projectID),
              let masterFont = project.fonts.first(where: { $0.id == masterID }) else { return }

        let masterWindowsOverrides = masterFont.windowsNameOverrides
        let masterWindowsRemovals = masterFont.windowsNameRemovals
        let masterOTOverrides = masterFont.otFeatureLabelOverrides
        let masterOTAdditions = masterFont.otFeatureLabelAdditions

        let masterAnalysis: FontAnalysis
        do {
            masterAnalysis = try analyzeSourceFont(fontID: masterFont.id, sourcePath: masterFont.sourcePath)
        } catch {
            postStatusMessage("Could not read master font names: \(error.localizedDescription)")
            return
        }

        postStatusMessage("Reading OpenType names…")
        let masterOT = await otFeatureInventory(fontID: masterFont.id, sourcePath: masterFont.sourcePath)

        let masterIntents = NameTableMerge.masterIntents(
            windowsNameTable: masterAnalysis.windowsNameTable,
            overrides: masterWindowsOverrides,
            removals: masterWindowsRemovals
        )
        let masterOTIntents = NameTableMerge.otMasterIntents(
            labels: masterOT?.otFeatureLabels ?? [],
            overrides: masterOTOverrides,
            additions: masterOTAdditions
        )

        let targetIDs = project.fonts.map(\.id).filter { $0 != masterID }
        var targetOT: [String: OTFeatureAnalysisResult] = [:]
        await withTaskGroup(of: (String, OTFeatureAnalysisResult?).self) { group in
            for font in project.fonts where font.id != masterID {
                let fontID = font.id
                let sourcePath = font.sourcePath
                group.addTask {
                    let result = await self.otFeatureInventory(fontID: fontID, sourcePath: sourcePath)
                    return (fontID, result)
                }
            }
            for await (fontID, result) in group {
                if let result { targetOT[fontID] = result }
            }
        }

        pushUndoSnapshot()
        guard var updated = self.project else { return }

        var failed = 0
        for index in updated.fonts.indices where updated.fonts[index].id != masterID {
            let targetFont = updated.fonts[index]
            let targetAnalysis: FontAnalysis
            do {
                targetAnalysis = try analyzeSourceFont(fontID: targetFont.id, sourcePath: targetFont.sourcePath)
            } catch {
                failed += 1
                postStatusMessage(
                    "Could not read names for \(fontBasename(for: targetFont)): \(error.localizedDescription)"
                )
                continue
            }

            let merged = NameTableMerge.mergeIntoTarget(
                masterIntents: masterIntents,
                targetOverrides: targetFont.windowsNameOverrides,
                targetRemovals: targetFont.windowsNameRemovals,
                targetWindowsNameTable: targetAnalysis.windowsNameTable
            )
            updated.fonts[index].windowsNameOverrides = merged.overrides
            updated.fonts[index].windowsNameRemovals = merged.removals

            if let ot = targetOT[targetFont.id] {
                let mergedOT = NameTableMerge.mergeOTIntoTarget(
                    masterIntents: masterOTIntents,
                    targetLabels: ot.otFeatureLabels,
                    targetUnlabeled: ot.otFeaturesUnlabeled,
                    targetOverrides: targetFont.otFeatureLabelOverrides,
                    targetAdditions: targetFont.otFeatureLabelAdditions
                )
                updated.fonts[index].otFeatureLabelOverrides = mergedOT.overrides
                updated.fonts[index].otFeatureLabelAdditions = mergedOT.additions
            }

            updated.fonts[index].dirty = true
        }

        guard failed < targetIDs.count else { return }

        updated.modified = Date()
        self.project = updated
        canSave = true
        regeneratePlan()
        let pushed = targetIDs.count - failed
        if failed == 0 {
            postStatusMessage("Pushed shared names from master to \(pushed) file(s)")
        } else {
            postStatusMessage("Pushed shared names to \(pushed) file(s); \(failed) skipped")
        }
    }

    private func otFeatureInventory(fontID: String, sourcePath: String) async -> OTFeatureAnalysisResult? {
        if let cached = cachedOTFeatureAnalysis(fontID: fontID, sourcePath: sourcePath) {
            return cached
        }
        do {
            let result = try await analyzeOTFeatures(sourcePath: sourcePath, includeSuggestions: false)
            storeOTFeatureAnalysis(fontID: fontID, sourcePath: sourcePath, result: result)
            return result
        } catch {
            return nil
        }
    }
}
