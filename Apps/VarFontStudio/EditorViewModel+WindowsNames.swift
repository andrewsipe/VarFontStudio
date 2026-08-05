import Foundation
import VarFontCore

extension EditorViewModel {
    /// Effective Names-panel value (override / PS prefix / empty).
    func windowsNameValue(nameID: Int, analysis: FontAnalysis?) -> String {
        guard let font = selectedFont else { return "" }
        let rows = WindowsNameTableEditing.populatedRows(
            windowsNameTable: analysis?.windowsNameTable ?? [],
            overrides: font.windowsNameOverrides,
            familyPSPrefix: font.options.familyPSPrefix
        )
        return rows.first(where: { $0.nameID == nameID })?.value ?? ""
    }

    func setWindowsNameValue(nameID: Int, value: String) {
        guard let fontID = selectedFontID else { return }
        if nameID == 25 {
            setFamilyPSPrefix(value, for: fontID)
            return
        }
        guard OpenTypeNameTable.editableLowNameIDs.contains(nameID), nameID != 25 else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateFont(id: fontID) { font in
            font.windowsNameOverrides[key] = value
        }
    }

    func addWindowsNameID(_ nameID: Int) {
        guard let fontID = selectedFontID else { return }
        guard OpenTypeNameTable.editableLowNameIDs.contains(nameID), nameID != 25 else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateFont(id: fontID) { font in
            if font.windowsNameOverrides[key] == nil {
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
            overrides: font.windowsNameOverrides
        )
    }

    /// Discard the pending edit so the row shows the record currently in the font file.
    func revertWindowsName(nameID: Int) {
        guard let fontID = selectedFontID, nameID != 25 else { return }
        let key = WindowsNameTableEditing.overrideKey(nameID)
        mutateFont(id: fontID) { font in
            font.windowsNameOverrides.removeValue(forKey: key)
        }
    }
}
