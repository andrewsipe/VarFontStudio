import Foundation

public enum InstanceServiceError: Error, Equatable, Sendable {
    case helperNotFound
    case helperUnavailable(String)
    case helperFailed(String)
    case invalidHelperOutput(String)
}

/// Static-instancing bridge. Shells out to bundled `vfinstance` (same Python/fontTools as vfcommit).
public struct InstanceService: Sendable {
    public var helperURL: URL?
    public var pythonExecutable: String

    public init(helperURL: URL? = nil, pythonExecutable: String? = nil) {
        self.helperURL = helperURL
        self.pythonExecutable = pythonExecutable ?? CommitService.defaultPythonExecutable()
    }

    /// Bundled `vfinstance/vfinstance.py`, synced into the app cache in DEBUG. Resolved once per process.
    public static func defaultHelperURL() -> URL? {
        cachedDefaultHelperURL
    }

    private static let cachedDefaultHelperURL: URL? = resolveDefaultHelperURL()

    private static func resolveDefaultHelperURL() -> URL? {
        if let bundled = bundledHelperURL(),
           FileManager.default.fileExists(atPath: bundled.path) {
            #if !DEBUG
            return bundled
            #endif
            return installedHelperURL(preferredSource: bundled.deletingLastPathComponent())
        }

        let cached = cacheDirectory().appendingPathComponent("vfinstance.py")
        if FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        #if DEBUG
        let dev = developmentSourceDirectory()
        let devScript = dev.appendingPathComponent("vfinstance.py")
        if FileManager.default.fileExists(atPath: devScript.path) {
            return installedHelperURL(preferredSource: dev)
        }
        #endif

        return nil
    }

    private static func bundledHelperURL() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("vfinstance/vfinstance.py")
    }

    private static func developmentSourceDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Instance
            .deletingLastPathComponent() // VarFontCore
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // VarFontEditor
            .appendingPathComponent("Tools/vfinstance", isDirectory: true)
    }

    private static func cacheDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VarFontStudio/vfinstance", isDirectory: true)
    }

    /// Copy vfinstance into the app cache so the Python subprocess only reads container paths.
    private static func installedHelperURL(preferredSource: URL) -> URL? {
        let cacheDir = cacheDirectory()
        let helper = cacheDir.appendingPathComponent("vfinstance.py")
        do {
            try syncHelper(from: preferredSource, to: cacheDir)
            return helper
        } catch {
            return FileManager.default.fileExists(atPath: helper.path) ? helper : nil
        }
    }

    private static func syncHelper(from source: URL, to cache: URL) throws {
        let sourceScript = source.appendingPathComponent("vfinstance.py")
        guard FileManager.default.fileExists(atPath: sourceScript.path) else {
            throw InstanceServiceError.helperNotFound
        }

        let cacheScript = cache.appendingPathComponent("vfinstance.py")
        let sourceFingerprint = helperFingerprint(at: source)
        let cacheFingerprint = helperFingerprint(at: cache)
        if FileManager.default.fileExists(atPath: cacheScript.path),
           sourceFingerprint == cacheFingerprint {
            return
        }

        if FileManager.default.fileExists(atPath: cache.path) {
            try FileManager.default.removeItem(at: cache)
        }
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: cache)
        removePythonCaches(under: cache)
    }

    private static func helperFingerprint(at root: URL) -> String {
        let script = root.appendingPathComponent("vfinstance.py")
        let lib = root.appendingPathComponent("vfinstance_lib")
        var parts: [String] = []

        if let values = try? script.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
           let modified = values.contentModificationDate,
           let size = values.fileSize {
            parts.append("vfinstance.py:\(size):\(modified.timeIntervalSince1970)")
        }

        guard let enumerator = FileManager.default.enumerator(
            at: lib,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return parts.joined(separator: "|")
        }

        for case let url as URL in enumerator where url.pathExtension == "py" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modified = values.contentModificationDate,
                  let size = values.fileSize else { continue }
            parts.append("\(url.lastPathComponent):\(size):\(modified.timeIntervalSince1970)")
        }

        return parts.sorted().joined(separator: "|")
    }

    private static func removePythonCaches(under root: URL) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let url as URL in enumerator where url.lastPathComponent == "__pycache__" {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func instance(
        _ request: InstanceRequest,
        onProgress: (@Sendable (InstanceProgressEvent) -> Void)? = nil
    ) async throws -> InstanceResult {
        guard let helperURL = helperURL ?? Self.defaultHelperURL() else {
            throw InstanceServiceError.helperNotFound
        }
        guard FileManager.default.fileExists(atPath: helperURL.path) else {
            throw InstanceServiceError.helperUnavailable(helperURL.path)
        }
        return try await runOneShot(request, helperURL: helperURL, onProgress: onProgress)
    }

    private func runOneShot(
        _ request: InstanceRequest,
        helperURL: URL,
        onProgress: (@Sendable (InstanceProgressEvent) -> Void)?
    ) async throws -> InstanceResult {
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

        let progressState = StderrProgressState(onProgress: onProgress)
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            progressState.consume(chunk)
        }

        try process.run()
        stdinPipe.fileHandleForWriting.write(requestData)
        try stdinPipe.fileHandleForWriting.close()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        // Drain any final bytes left unread.
        let trailing = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if !trailing.isEmpty {
            progressState.consume(trailing)
        }
        progressState.flushRemainder()
        let stderrData = progressState.nonProgressData()

        guard process.terminationStatus == 0 || process.terminationStatus == 1 else {
            let detail = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "exit \(process.terminationStatus)"
            throw InstanceServiceError.helperFailed(detail)
        }

        do {
            return try VarFontJSON.decode(InstanceResult.self, from: stdoutData)
        } catch {
            let stderrText = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stdoutText = String(data: stdoutData.prefix(400), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail: String
            if !stdoutText.isEmpty {
                detail = stdoutText
            } else if !stderrText.isEmpty {
                detail = stderrText
            } else {
                detail = error.localizedDescription
            }
            throw InstanceServiceError.invalidHelperOutput(detail)
        }
    }
}

/// Parses line-delimited progress JSON from helper stderr while collecting other stderr text.
private final class StderrProgressState: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var other = Data()
    private let onProgress: (@Sendable (InstanceProgressEvent) -> Void)?
    private let decoder = JSONDecoder()

    init(onProgress: (@Sendable (InstanceProgressEvent) -> Void)?) {
        self.onProgress = onProgress
    }

    func consume(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            let next = buffer.index(after: newline)
            buffer = buffer.subdata(in: next..<buffer.endIndex)
            handleLine(line)
        }
    }

    func flushRemainder() {
        lock.lock()
        defer { lock.unlock() }
        if !buffer.isEmpty {
            handleLine(buffer)
            buffer.removeAll()
        }
    }

    func nonProgressData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return other
    }

    private func handleLine(_ line: Data) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let event = try? decoder.decode(InstanceProgressEvent.self, from: trimmed),
           event.event == "start" || event.event == "written" || event.event == "error" {
            onProgress?(event)
            return
        }
        other.append(line)
        other.append(0x0A)
    }
}

private extension Data {
    func trimmingCharacters(in set: CharacterSet) -> Data {
        guard let text = String(data: self, encoding: .utf8) else { return self }
        return Data(text.trimmingCharacters(in: set).utf8)
    }
}
