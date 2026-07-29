import AppKit

enum InstancerWindowLifecycle {
    static let identifier = "instancer"

    static func closeRestoredWindows() {
        for window in NSApplication.shared.windows where isInstancerWindow(window) {
            window.isRestorable = false
            window.close()
        }
    }

    static func scheduleCloseRestoredWindows() {
        closeRestoredWindows()
        for delay in [0.05, 0.2, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                closeRestoredWindows()
            }
        }
    }

    static func isInstancerWindow(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == identifier {
            return true
        }
        let title = window.title.lowercased()
        return title.hasPrefix("instance —") || title.hasPrefix("instance -")
            || title == "instance static fonts"
    }
}
