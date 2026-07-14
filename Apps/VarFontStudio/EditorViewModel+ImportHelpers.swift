import Foundation
import VarFontCore

extension EditorViewModel {
    // MARK: - Import helpers

    enum FontImportError: LocalizedError {
        case notVariableFont

        var errorDescription: String? {
            switch self {
            case .notVariableFont:
                "Not a variable font — no variation axes found."
            }
        }
    }

    func validateVariableFont(_ analysis: FontAnalysis) throws {
        if analysis.axes.isEmpty {
            throw FontImportError.notVariableFont
        }
    }

    func findFont(normalizedPath: String) -> (projectID: String, fontID: String)? {
        for op in openProjects {
            for font in op.document.fonts {
                if Self.normalizedPath(font.sourcePath) == normalizedPath {
                    return (op.id, font.id)
                }
            }
        }
        return nil
    }

    static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    func refreshCanSave() {
        canSave = project?.fonts.contains(where: \.dirty) ?? false
    }

    func regeneratePlan() {
        guard project != nil, selectedFontID != nil else {
            instancePlan = nil
            instanceListDisplay = .empty
            return
        }
        backfillMissingInferredAxisRoles()
        guard let project else {
            instancePlan = nil
            return
        }
        instancePlan = InstancePlanner.plan(project: project, fontID: selectedFontID!)
        planRevision += 1
        if let key = selectedInstanceKey,
           instancePlan?.instances.contains(where: { $0.key == key }) != true {
            selectedInstanceKey = instancePlan?.instances.first?.key
        }
        refreshInstanceListDisplay()
    }

    func setInstanceIncluded(_ key: String, included: Bool) {
        guard var project, let fontIndex = project.fonts.firstIndex(where: { $0.id == selectedFontID }) else {
            return
        }
        var font = project.fonts[fontIndex]
        if included {
            font.excludedInstanceKeys.removeAll { $0 == key }
        } else if !font.excludedInstanceKeys.contains(key) {
            font.excludedInstanceKeys.append(key)
        }
        font.dirty = true
        project.fonts[fontIndex] = font
        project.modified = Date()
        self.project = project
        canSave = true
        regeneratePlan()
    }

    func setAxisInstanceGridEnabled(tag: String, enabled: Bool) {
        guard let axis = selectedFont?.axes.first(where: { $0.tag == tag }),
              !axis.isDesignRecordOnly else { return }
        updateAxisRole(tag: tag, role: enabled ? .instance : .statOnly)
    }

    func setAxisStatOnly(tag: String, statOnly: Bool) {
        setAxisInstanceGridEnabled(tag: tag, enabled: !statOnly)
    }

    func axisParticipatesInInstanceGrid(tag: String) -> Bool {
        if NamingToken.isClarifier(tag) { return false }
        return selectedFont?.axes.first(where: { $0.tag == tag })?.role == .instance
    }

    func isRegistrationNamingAxis(tag: String) -> Bool {
        selectedFont?.axes.first(where: { $0.tag == tag })?.isDesignRecordOnly == true
    }

    func clarifierCoveredByRegistration(category: FileClarifierCategory, for fontID: String) -> Bool {
        guard let font = font(forProjectID: activeProjectID ?? "", fontID: fontID) else { return false }
        return RegistrationAxisSupport.clarifierCategoriesCoveredByRegistration(font: font).contains(category)
    }
}
