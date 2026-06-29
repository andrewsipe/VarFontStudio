import Foundation

public enum CommitServiceError: Error, Equatable, Sendable {
    case helperNotFound
    case helperUnavailable(String)
    case helperFailed(String)
    case invalidHelperOutput(String)
}

/// Save-time commit bridge. Shells out to bundled `vfcommit` (Python + vendored FontCore subset).
public struct CommitService: Sendable {
    public var helperURL: URL?
    public var pythonExecutable: String

    public init(helperURL: URL? = nil, pythonExecutable: String = "/usr/bin/env") {
        self.helperURL = helperURL ?? Self.defaultHelperURL()
        self.pythonExecutable = pythonExecutable
    }

    /// Repo-relative `Tools/vfcommit/vfcommit.py` when running from a checkout.
    public static func defaultHelperURL() -> URL? {
        let candidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Commit
                .deletingLastPathComponent() // VarFontCore
                .deletingLastPathComponent() // Sources
                .deletingLastPathComponent() // VarFontEditor
                .appendingPathComponent("Tools/vfcommit/vfcommit.py"),
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Tools/vfcommit/vfcommit.py"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
            ?? candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    public func commit(_ request: CommitRequest) async throws -> CommitResult {
        guard let helperURL else {
            throw CommitServiceError.helperNotFound
        }
        guard FileManager.default.fileExists(atPath: helperURL.path) else {
            throw CommitServiceError.helperUnavailable(helperURL.path)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let requestData = try encoder.encode(request)

        let process = Process()
        if pythonExecutable.hasSuffix("env") {
            process.executableURL = URL(fileURLWithPath: pythonExecutable)
            process.arguments = ["python3", helperURL.path]
        } else {
            process.executableURL = URL(fileURLWithPath: pythonExecutable)
            process.arguments = [helperURL.path]
        }

        let toolsDir = helperURL.deletingLastPathComponent()
        process.currentDirectoryURL = toolsDir

        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PYTHONPATH"] ?? ""
        let pythonPath = toolsDir.path
        environment["PYTHONPATH"] = existingPath.isEmpty ? pythonPath : "\(pythonPath):\(existingPath)"
        process.environment = environment

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        stdinPipe.fileHandleForWriting.write(requestData)
        try stdinPipe.fileHandleForWriting.close()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 || process.terminationStatus == 1 else {
            let detail = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "exit \(process.terminationStatus)"
            throw CommitServiceError.helperFailed(detail)
        }

        do {
            return try JSONDecoder().decode(CommitResult.self, from: stdoutData)
        } catch {
            let snippet = String(data: stdoutData.prefix(400), encoding: .utf8) ?? ""
            throw CommitServiceError.invalidHelperOutput(
                snippet.isEmpty ? error.localizedDescription : snippet
            )
        }
    }
}
