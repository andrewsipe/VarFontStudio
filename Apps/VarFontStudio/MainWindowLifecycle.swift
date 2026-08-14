import AppKit

enum MainWindowLifecycle {
    static let identifier = "main"

    static func isMainWindow(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == identifier {
            return true
        }
        // Fallback before the configurator tags a freshly created window.
        let title = window.title
        if title == "VarFont Studio" { return true }
        return false
    }

    static func existingMainWindow() -> NSWindow? {
        NSApplication.shared.windows.first { window in
            isMainWindow(window) && window.isVisible
        } ?? NSApplication.shared.windows.first(where: isMainWindow)
    }

    /// Bring an existing main window forward. Returns false when none exists.
    @discardableResult
    static func focusExistingMainWindow() -> Bool {
        guard let window = existingMainWindow() else { return false }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    /// Hide the Studio window without discarding open projects (same as the traffic light).
    static func closeExistingMainWindow() {
        existingMainWindow()?.close()
    }
}
