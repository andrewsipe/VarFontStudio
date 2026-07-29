import AppKit
import Foundation

/// Shared directory picker used by Review export and Instancer generate.
enum StudioOutputFolderPicker {
    @MainActor
    static func choose(title: String, message: String, startingDirectory: URL? = nil) async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.title = title
            panel.message = message
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.prompt = "Choose Folder"
            if let startingDirectory {
                panel.directoryURL = startingDirectory
            }
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
}
