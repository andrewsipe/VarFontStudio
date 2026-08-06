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
            mutateFont(id: fontID) { font in
                font.windowsNameOverrides.removeValue(forKey: WindowsNameTableEditing.overrideKey(25))
                font.windowsNameRemovals.removeAll { $0 == 25 }
            }
            setFamilyPSPrefix(value, for: fontID)
            return
        }
        guard OpenTypeNameTable.editableLowNameIDs.contains(nameID) else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateFont(id: fontID) { font in
            font.windowsNameOverrides[key] = value
            font.windowsNameRemovals.removeAll { $0 == nameID }
        }
    }

    func addWindowsNameID(_ nameID: Int) {
        guard let fontID = selectedFontID else { return }
        guard OpenTypeNameTable.editableLowNameIDs.contains(nameID) else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateFont(id: fontID) { font in
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
        guard let fontID = selectedFontID else { return }
        guard WindowsNameTableEditing.canRemove(nameID: nameID) else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateFont(id: fontID) { font in
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
        guard let fontID = selectedFontID else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateFont(id: fontID) { font in
            font.windowsNameOverrides.removeValue(forKey: key)
            font.windowsNameRemovals.removeAll { $0 == nameID }
        }
    }
}
