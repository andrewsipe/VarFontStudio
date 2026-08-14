import AppKit
import SwiftUI

@main
struct VarFontStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var editor = EditorViewModel()
    @StateObject private var layout = EditorLayoutPreferences()
    @FocusedValue(\.studioFocus) private var studioFocus

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainEditorView()
                .environmentObject(editor)
                .environmentObject(layout)
                .environment(editor.workspaceDrag)
                .frame(minWidth: 960, minHeight: 620)
                .studioBrandTint()
                .onAppear {
                    appDelegate.editor = editor
                }
                .onOpenURL { url in
                    Task { @MainActor in
                        editor.ensureMainWindowVisible()
                        await editor.openProjectFile(at: url)
                    }
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            mainWindowCommands
        }
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Close Window") {
                    editor.closeKeyWindow(focus: studioFocus)
                }
                .disabled(!editor.canCloseKeyWindow)
            }
        }

        Settings {
            StudioSettingsView()
                .environmentObject(layout)
                .environmentObject(editor)
                .studioBrandTint()
        }

        WindowGroup(id: "save-review", for: String.self) { $projectID in
            if let projectID {
                SaveReviewWindow(projectID: projectID)
                    .environmentObject(editor)
                    .environmentObject(layout)
                    .studioBrandTint()
            }
        }
        .defaultSize(width: 960, height: 720)

        WindowGroup(id: "instancer", for: String.self) { $windowKey in
            if let windowKey {
                InstancerWindow(windowKey: windowKey)
                    .environmentObject(editor)
                    .environmentObject(layout)
                    .studioBrandTint()
            }
        }
        .defaultSize(width: 1080, height: 760)
    }

    @CommandsBuilder
    private var mainWindowCommands: some Commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Project…") {
                    editor.presentOpenProjectPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .option])

                Button("Open Font…") {
                    editor.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Add Font to Project…") {
                    editor.presentAddFontPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!editor.hasOpenProjects)

                Divider()

                Button("Save Project") {
                    editor.saveProject()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!editor.canSaveProject)

                Button("Save Project As…") {
                    editor.saveProjectAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!editor.hasOpenProjects)

                Button("Save All Projects") {
                    editor.saveAllProjects()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(!editor.canSaveAllProjects)

                Divider()

                if editor.canSaveToRememberedPathForSelection {
                    Button("Export As…") {
                        editor.saveCopy()
                    }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(!editor.canSave || editor.isSaveActionBlocked)
                    .help("Choose a new path for this font")

                    Button("Export") {
                        editor.save()
                    }
                    .disabled(!editor.canSave || editor.isSaveActionBlocked)
                    .help("Write to the last export path")
                } else {
                    Button("Export…") {
                        editor.saveCopy()
                    }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(!editor.canSave || editor.isSaveActionBlocked)
                }

                if let projectID = editor.activeProjectID,
                   editor.openProjects.first(where: { $0.id == projectID })?.document.fonts.count ?? 0 > 1 {
                    Button("Export All…") {
                        editor.saveAllFiles(inProjectID: projectID)
                    }
                    .disabled(!editor.canSave || editor.isSaveActionBlocked)
                    .help("Export every file in this project to a folder. Picking the source folder creates a Patched subfolder.")
                }

                Button("Export to Original…") {
                    editor.requestSaveToOriginal()
                }
                .disabled(!editor.canSave || editor.isSaveActionBlocked)
                .help("Overwrite the source font file after confirmation")

                Divider()

                Button("Close Project") {
                    editor.requestCloseActiveProject()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(!editor.hasOpenProjects)

                Button("Close All") {
                    editor.requestCloseAllProjects()
                }
                .keyboardShortcut("w", modifiers: [.command, .option])
                .disabled(!editor.hasOpenProjects)
            }

            // Suppress system Save / Close Window — those actions live in `.newItem` above.
            CommandGroup(replacing: .saveItem) {}

            CommandGroup(replacing: .help) {
                Button("VarFont Studio Shortcuts…") {
                    editor.presentShortcutsHelp()
                }
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    editor.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!editor.canUndo)

                Button("Redo") {
                    editor.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!editor.canRedo)
            }

            CommandGroup(after: .textEditing) {
                Button("Find Instances…") {
                    editor.requestInstanceSearchFocus()
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(editor.selectedFont == nil)
            }

            CommandGroup(replacing: .sidebar) {
                Toggle("Axis Tree", isOn: $layout.showAxisTree)
                    .keyboardShortcut("1", modifiers: [.command, .control])

                Toggle("Instances", isOn: $layout.showInstances)
                    .keyboardShortcut("2", modifiers: [.command, .control])

                Toggle("Inspector", isOn: $layout.showInspector)
                    .keyboardShortcut("3", modifiers: [.command, .control])

                Divider()

                Toggle("Review", isOn: Binding(
                    get: { editor.isActiveReviewWindowOpen },
                    set: { _ in editor.toggleSaveReviewWindow() }
                ))
                .keyboardShortcut("4", modifiers: [.command, .control])
                .disabled(!editor.canPreviewSaveReview && !editor.isActiveReviewWindowOpen)

                Toggle("Instancer", isOn: Binding(
                    get: { editor.isActiveInstancerWindowOpen },
                    set: { _ in editor.toggleInstancerWindow() }
                ))
                .keyboardShortcut("5", modifiers: [.command, .control])
                .disabled(!editor.canPresentInstancer && !editor.isActiveInstancerWindowOpen)
            }

            CommandGroup(after: .windowList) {
                Menu("Projects") {
                    ForEach(editor.openProjects) { project in
                        Button {
                            editor.focusProjectInMainWindow(projectID: project.id)
                        } label: {
                            if project.id == editor.activeProjectID {
                                Text("✓ \(editor.projectTabLabel(for: project))")
                            } else {
                                Text(editor.projectTabLabel(for: project))
                            }
                        }
                    }
                }
                .disabled(!editor.hasOpenProjects)
            }

            CommandMenu("Instances") {
                Button(InstanceInclusionCommands.includeAllShownTitle) {
                    editor.includeAllVisibleInstances()
                }
                .keyboardShortcut(InstanceInclusionCommands.includeAllShownShortcut)
                .disabled(editor.filteredInstances.isEmpty && !editor.isTrimmedToOriginals)

                Button(InstanceInclusionCommands.excludeAllShownTitle) {
                    editor.excludeAllVisibleInstances()
                }
                .keyboardShortcut(InstanceInclusionCommands.excludeAllShownShortcut)
                .disabled(editor.filteredInstances.isEmpty)

                if editor.showsTrimNonOriginalsAction {
                    Button(InstanceInclusionCommands.trimNonOriginalsTitle) {
                        editor.trimNonOriginalInstances()
                    }
                    .disabled(editor.instancePlan == nil)
                }

                Divider()

                Button(InstanceInclusionCommands.includeSelectionTitle) {
                    editor.setInstancesIncluded(keys: editor.activeInstanceSelection, included: true)
                }
                .keyboardShortcut(InstanceInclusionCommands.includeSelectionShortcut)
                .disabled(editor.activeInstanceSelection.isEmpty)

                Button(InstanceInclusionCommands.excludeSelectionTitle) {
                    editor.setInstancesIncluded(keys: editor.activeInstanceSelection, included: false)
                }
                .keyboardShortcut(InstanceInclusionCommands.excludeSelectionShortcut)
                .disabled(editor.activeInstanceSelection.isEmpty)

                Divider()

                Toggle(
                    "Code Naming",
                    isOn: Binding(
                        get: { editor.isCodeNamingEnabled },
                        set: { editor.setCodeNamingEnabled($0) }
                    )
                )
                .disabled(editor.project == nil)
            }

            CommandMenu("Review") {
                Button("Show Review") {
                    editor.presentSaveReviewWindow()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!editor.canPreviewSaveReview)

                Button("Close Review") {
                    editor.closeActiveReviewWindow()
                }
                .disabled(!editor.isActiveReviewWindowOpen)

                Divider()

                Button("Refresh") {
                    editor.refreshActiveReview(projectID: studioFocus?.reviewProjectID ?? editor.activeProjectID)
                }
                .disabled(!editor.canRefreshReview(projectID: studioFocus?.reviewProjectID ?? editor.activeProjectID))
            }

            CommandMenu("Instancer") {
                Button("Show Instancer") {
                    editor.presentInstancerWindow()
                }
                .disabled(!editor.canPresentInstancer)

                Button("Close Instancer") {
                    editor.closeActiveInstancerWindow()
                }
                .disabled(!editor.isActiveInstancerWindowOpen)

                Divider()

                Button("Generate This File…") {
                    editor.generateFocusedInstancerFile(
                        windowKey: studioFocus?.instancerWindowKey ?? editor.activeInstancerWindowKey
                    )
                }
                .disabled(!editor.canGenerateFocusedInstancerFile(
                    windowKey: studioFocus?.instancerWindowKey ?? editor.activeInstancerWindowKey
                ))

                Button("Generate All…") {
                    editor.generateAllFocusedInstancer(
                        windowKey: studioFocus?.instancerWindowKey ?? editor.activeInstancerWindowKey
                    )
                }
                .disabled(!editor.canGenerateAllFocusedInstancer(
                    windowKey: studioFocus?.instancerWindowKey ?? editor.activeInstancerWindowKey
                ))

                Button("Add Instance…") {
                    editor.beginAddFocusedInstancerInstance(
                        windowKey: studioFocus?.instancerWindowKey ?? editor.activeInstancerWindowKey
                    )
                }
                .disabled(!editor.canAddFocusedInstancerInstance(
                    windowKey: studioFocus?.instancerWindowKey ?? editor.activeInstancerWindowKey
                ))
            }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var editor: EditorViewModel?
    private var menuTrackingObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        SaveReviewWindowLifecycle.closeRestoredWindows()
        InstancerWindowLifecycle.closeRestoredWindows()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SaveReviewWindowLifecycle.scheduleCloseRestoredWindows()
        InstancerWindowLifecycle.scheduleCloseRestoredWindows()
        // Collapse accidental duplicate main windows from earlier openWindow races.
        DispatchQueue.main.async {
            let mains = NSApplication.shared.windows.filter(MainWindowLifecycle.isMainWindow)
            guard mains.count > 1 else { return }
            // Keep the key window if it's main; otherwise keep the first.
            let keep = mains.first(where: \.isKeyWindow) ?? mains[0]
            for window in mains where window !== keep {
                window.close()
            }
        }
        Self.stripSystemFileCloseItems()
        Self.stripAppleHelpFeedbackItems()
        menuTrackingObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let menu = note.object as? NSMenu else { return }
            let titles = menu.items.map(\.title)
            if titles.contains(where: {
                $0 == "Save All Projects" || $0 == "Open Font…" || $0 == "Open Font..."
            }) {
                Self.stripSystemFileCloseItems()
            }
            if titles.contains(where: {
                $0.contains("Shortcuts") || $0.localizedCaseInsensitiveContains("Feedback")
            }) {
                Self.stripAppleHelpFeedbackItems(from: menu)
            }
        }
    }

    /// Removes AppKit's File → Close / Close All Windows so only Close Project / Close All remain.
    private static func stripSystemFileCloseItems() {
        guard let fileMenu = NSApp.mainMenu?.items.first(where: { item in
            item.submenu?.items.contains(where: {
                $0.title == "Open Font…" || $0.title == "Open Font..." || $0.title == "Save All Projects"
            }) == true
        })?.submenu else { return }

        let systemCloseActions: Set<String> = [
            "performClose:",
            "closeAll:",
            "closeAllWindows:",
        ]
        let systemCloseTitles: Set<String> = [
            "Close Window",
            "Close All Windows",
        ]

        var removeIndexes: [Int] = []
        for (index, item) in fileMenu.items.enumerated() {
            let actionName = item.action.map { NSStringFromSelector($0) } ?? ""
            let isSystemCloseAction = systemCloseActions.contains(actionName)
            let isSystemCloseTitle = systemCloseTitles.contains(item.title)
            // Bare system "Close" usually has no key equivalent once we claimed ⌘W.
            let isOrphanSystemClose = item.title == "Close" && item.keyEquivalent.isEmpty
            if isSystemCloseAction || isSystemCloseTitle || isOrphanSystemClose {
                removeIndexes.append(index)
            }
        }

        for index in removeIndexes.reversed() {
            fileMenu.removeItem(at: index)
        }

        collapseExtraSeparators(in: fileMenu)
    }

    /// Removes the leftover Apple “Send … Feedback” item from Help.
    private static func stripAppleHelpFeedbackItems(from menu: NSMenu? = nil) {
        let helpMenu = menu ?? NSApp.mainMenu?.items.first(where: { item in
            item.submenu?.items.contains(where: {
                $0.title.contains("Shortcuts") || $0.title.localizedCaseInsensitiveContains("Feedback")
            }) == true
        })?.submenu
        guard let helpMenu else { return }

        var removeIndexes: [Int] = []
        for (index, item) in helpMenu.items.enumerated() {
            let actionName = item.action.map { NSStringFromSelector($0) } ?? ""
            let isFeedbackTitle = item.title.localizedCaseInsensitiveContains("Feedback to Apple")
                || (
                    item.title.localizedCaseInsensitiveContains("Feedback")
                    && item.title.localizedCaseInsensitiveContains("Apple")
                )
            let isFeedbackAction = actionName == "sendFeedback:"
            if isFeedbackTitle || isFeedbackAction {
                removeIndexes.append(index)
            }
        }

        for index in removeIndexes.reversed() {
            helpMenu.removeItem(at: index)
        }

        collapseExtraSeparators(in: helpMenu)
    }

    private static func collapseExtraSeparators(in menu: NSMenu) {
        while let last = menu.items.last, last.isSeparatorItem {
            menu.removeItem(last)
        }
        var i = menu.items.count - 1
        while i > 0 {
            if menu.items[i].isSeparatorItem, menu.items[i - 1].isSeparatorItem {
                menu.removeItem(at: i)
            }
            i -= 1
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        editor?.ensureMainWindowVisible()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let editor else { return .terminateNow }
        switch editor.handleApplicationTerminateRequest() {
        case .allow:
            editor.completeApplicationTermination()
            return .terminateLater
        case .deferToUI:
            return .terminateLater
        case .cancel:
            return .terminateCancel
        }
    }
}
