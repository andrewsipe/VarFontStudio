import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import VarFontCore

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var project: ProjectDocument?
    @Published var selectedFontID: String?
    @Published var selectedInstanceKey: String?
    @Published var selectedAxisStopID: String?
    @Published var searchText = ""
    @Published var showExcludedOnly = false
    @Published var instancePlan: InstancePlan?
    @Published var statusMessage: String?
    @Published var isBusy = false

    @Published private(set) var canSave = false

    var selectedFont: FontDocument? {
        guard let project, let selectedFontID else { return nil }
        return project.fonts.first { $0.id == selectedFontID }
    }

    var filteredInstances: [PlannedInstance] {
        guard let instancePlan else { return [] }
        var rows = instancePlan.instances
        if showExcludedOnly {
            rows = rows.filter { !$0.included }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            rows = rows.filter {
                $0.composedName.localizedCaseInsensitiveContains(query)
                    || $0.key.localizedCaseInsensitiveContains(query)
            }
        }
        return rows
    }

    var selectedInstance: PlannedInstance? {
        guard let key = selectedInstanceKey, let instancePlan else { return nil }
        return instancePlan.instances.first { $0.key == key }
    }

    var axisPlanWarnings: [PlanWarning] {
        guard let instancePlan else { return [] }
        let axisCodes: Set<String> = ["multiple_elidable", "empty_instance_axis"]
        return instancePlan.warnings.filter { axisCodes.contains($0.code) }
    }

    func presentAddFontPanel() {
        let panel = NSOpenPanel()
        panel.title = "Add Font to Project"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.fontContentTypes
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self?.addFont(at: url)
            }
        }
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Variable Font"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.fontContentTypes
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self?.openFont(at: url)
            }
        }
    }

    func openFont(at url: URL) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let imported = try ProjectImporter.openFont(at: url)
            project = imported
            selectedFontID = imported.fonts.first?.id
            selectedInstanceKey = nil
            regeneratePlan()
            statusMessage = "Opened \(url.lastPathComponent)"
            canSave = false
        } catch {
            statusMessage = "Could not open font: \(error.localizedDescription)"
        }
    }

    func addFont(at url: URL) async {
        guard var project else {
            await openFont(at: url)
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let analysis = try FontAnalysisReader.analyze(url: url)
            ProjectImporter.addFont(analysis, sourceURL: url, to: &project)
            self.project = project
            selectedFontID = project.fonts.last?.id
            regeneratePlan()
            statusMessage = "Added \(url.lastPathComponent)"
        } catch {
            statusMessage = "Could not add font: \(error.localizedDescription)"
        }
    }

    func selectFont(id: String) {
        selectedFontID = id
        selectedInstanceKey = nil
        regeneratePlan()
    }

    func regeneratePlan() {
        guard let project, let selectedFontID else {
            instancePlan = nil
            return
        }
        instancePlan = InstancePlanner.plan(project: project, fontID: selectedFontID)
        if let key = selectedInstanceKey,
           instancePlan?.instances.contains(where: { $0.key == key }) != true {
            selectedInstanceKey = instancePlan?.instances.first?.key
        }
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

    func setAxisStatOnly(tag: String, statOnly: Bool) {
        updateAxisRole(tag: tag, role: statOnly ? .statOnly : .instance)
    }

    func axisParticipatesInInstanceGrid(tag: String) -> Bool {
        selectedFont?.axes.first(where: { $0.tag == tag })?.role == .instance
    }

    func updateAxisRole(tag: String, role: AxisRole) {
        mutateSelectedFont { font in
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == tag }) else { return }
            font.axes[axisIndex].role = role
        }
    }

    func updateAxisStopName(axisTag: String, stopID: String, name: String) {
        mutateSelectedFont { font in
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }),
                  let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else { return }
            font.axes[axisIndex].values[stopIndex].name = name
        }
    }

    func updateAxisStopElidable(axisTag: String, stopID: String, elidable: Bool) {
        mutateSelectedFont { font in
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }),
                  let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else { return }
            if elidable {
                for index in font.axes[axisIndex].values.indices {
                    font.axes[axisIndex].values[index].elidable = font.axes[axisIndex].values[index].id == stopID
                }
            } else {
                font.axes[axisIndex].values[stopIndex].elidable = false
            }
        }
    }

    func addAxisStop(axisTag: String) {
        mutateSelectedFont { font in
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }) else { return }
            let axis = font.axes[axisIndex]
            let value = suggestedNewStopValue(for: axis)
            let stop = AxisValue(
                id: "\(axisTag)-\(UUID().uuidString.prefix(8))",
                value: value,
                name: "New Stop",
                elidable: false,
                statFormat: 1
            )
            font.axes[axisIndex].values.append(stop)
            font.axes[axisIndex].values.sort { $0.value < $1.value }
        }
        selectedAxisStopID = nil
    }

    private func suggestedNewStopValue(for axis: AxisDefinition) -> Double {
        if let max = axis.max, let min = axis.min {
            if let last = axis.values.map(\.value).max() {
                return Swift.min(last + 1, max)
            }
            return axis.default ?? min
        }
        if let last = axis.values.last?.value {
            return last + 1
        }
        return axis.default ?? 0
    }

    private func mutateSelectedFont(_ mutate: (inout FontDocument) -> Void) {
        guard var project, let fontIndex = project.fonts.firstIndex(where: { $0.id == selectedFontID }) else {
            return
        }
        mutate(&project.fonts[fontIndex])
        project.fonts[fontIndex].dirty = true
        project.modified = Date()
        self.project = project
        canSave = true
        regeneratePlan()
    }

    func saveCopy() {
        statusMessage = "Save is not wired yet — vfcommit helper coming next."
    }

    func importDroppedFonts(_ urls: [URL]) async {
        let valid = urls.filter { Self.isFontFile($0) }
        guard !valid.isEmpty else {
            statusMessage = "No supported font files (.ttf, .otf, .woff, .woff2)"
            return
        }
        if project == nil {
            await openFont(at: valid[0])
            for url in valid.dropFirst() {
                await addFont(at: url)
            }
        } else {
            for url in valid {
                await addFont(at: url)
            }
        }
    }

    static func isFontFile(_ url: URL) -> Bool {
        fontFileExtensions.contains(url.pathExtension.lowercased())
    }

    static let fontDropTypes: [UTType] = [.fileURL]

    private static let fontFileExtensions: Set<String> = ["ttf", "otf", "woff", "woff2"]
    private static let fontContentTypes: [UTType] = [
        UTType(filenameExtension: "ttf")!,
        UTType(filenameExtension: "otf")!,
        UTType(filenameExtension: "woff")!,
        UTType(filenameExtension: "woff2")!,
    ]
}
