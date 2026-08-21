import AppKit

enum SaveReviewWindowLifecycle {
    static let identifier = "save-review"

    static func windowIdentifier(forProjectID projectID: String) -> NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier("\(identifier)|\(projectID)")
    }

    /// Close Save Review windows restored by macOS from a prior session.
    static func closeRestoredWindows() {
        for window in NSApplication.shared.windows where isSaveReviewWindow(window) {
            window.isRestorable = false
            window.close()
        }
    }

    /// macOS may restore auxiliary windows after `applicationDidFinishLaunching`; retry briefly.
    static func scheduleCloseRestoredWindows() {
        closeRestoredWindows()
        for delay in [0.05, 0.2, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                closeRestoredWindows()
            }
        }
    }

    static func isSaveReviewWindow(_ window: NSWindow) -> Bool {
        if let raw = window.identifier?.rawValue,
           raw == identifier || raw.hasPrefix("\(identifier)|") {
            return true
        }
        return window.title.lowercased().hasPrefix("review")
            || window.title.lowercased().hasPrefix("save review")
    }

    static func matches(_ window: NSWindow, projectID: String, title: String? = nil) -> Bool {
        guard isSaveReviewWindow(window) else { return false }
        if let raw = window.identifier?.rawValue, raw == "\(identifier)|\(projectID)" {
            return true
        }
        guard let title, !title.isEmpty else { return false }
        return window.title == title
    }

    static func existingWindows(projectID: String, title: String? = nil) -> [NSWindow] {
        NSApplication.shared.windows.filter { matches($0, projectID: projectID, title: title) }
    }

    /// Bring an existing Review window forward and close any duplicates.
    @discardableResult
    static func focusExisting(projectID: String, title: String? = nil) -> Bool {
        let windows = existingWindows(projectID: projectID, title: title)
        guard let keep = windows.first(where: \.isKeyWindow) ?? windows.first else { return false }
        for window in windows where window !== keep {
            window.isRestorable = false
            window.close()
        }
        if keep.isMiniaturized {
            keep.deminiaturize(nil)
        }
        keep.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
