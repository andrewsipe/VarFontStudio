import AppKit

enum InstancerWindowLifecycle {
    static let identifier = "instancer"

    static func windowIdentifier(forWindowKey windowKey: String) -> NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier("\(identifier)|\(windowKey)")
    }

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
        if let raw = window.identifier?.rawValue,
           raw == identifier || raw.hasPrefix("\(identifier)|") {
            return true
        }
        let title = window.title.lowercased()
        return title.hasPrefix("instance —") || title.hasPrefix("instance -")
            || title == "instance static fonts"
    }

    static func matches(_ window: NSWindow, windowKey: String, title: String? = nil) -> Bool {
        guard isInstancerWindow(window) else { return false }
        if let raw = window.identifier?.rawValue, raw == "\(identifier)|\(windowKey)" {
            return true
        }
        guard let title, !title.isEmpty else { return false }
        return window.title == title || window.title.hasPrefix(title)
    }

    static func existingWindows(windowKey: String, title: String? = nil) -> [NSWindow] {
        NSApplication.shared.windows.filter { matches($0, windowKey: windowKey, title: title) }
    }

    /// Bring an existing Instancer window forward and close any duplicates.
    @discardableResult
    static func focusExisting(windowKey: String, title: String? = nil) -> Bool {
        let windows = existingWindows(windowKey: windowKey, title: title)
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
