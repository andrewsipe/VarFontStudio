import AppKit
import Foundation

// MARK: - Tab key monitor

/// Intercepts Tab before AppKit text fields resign first responder (SwiftUI onKeyPress is too late).
@MainActor
final class TabKeyMonitor {
    private var monitor: Any?
    private let handler: (Bool) -> Void

    init(handler: @escaping (Bool) -> Void) {
        self.handler = handler
    }

    func start() {
        guard monitor == nil else { return }
        let tabHandler = handler
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 48 else { return event }
            tabHandler(event.modifierFlags.contains(.shift))
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
