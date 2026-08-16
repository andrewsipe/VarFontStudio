import Foundation

public enum CommitWorkerError: Error, Equatable, Sendable {
    case notStarted
    case processExited(String)
    case invalidResponse(String)
    case timedOut
}

/// Long-lived vfcommit NDJSON subprocess for interactive save previews.
///
/// Actors are reentrant across `await`, so overlapping `roundTrip` calls would
/// interleave stdin/stdout. `ioGate` makes write→read exclusive.
actor CommitWorker {
    private let helperURL: URL
    private let pythonExecutable: String
    private let toolsDirectory: URL
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private let timeoutSeconds: TimeInterval = 60
    private var ioBusy = false
    private var ioWaiters: [CheckedContinuation<Void, Never>] = []

    init(helperURL: URL, pythonExecutable: String) {
        self.helperURL = helperURL
        self.pythonExecutable = pythonExecutable
        self.toolsDirectory = helperURL.deletingLastPathComponent()
    }

    private func acquireIO() async {
        if !ioBusy {
            ioBusy = true
            return
        }
        await withCheckedContinuation { continuation in
            ioWaiters.append(continuation)
        }
    }

    private func releaseIO() {
        if ioWaiters.isEmpty {
            ioBusy = false
            return
        }
        let next = ioWaiters.removeFirst()
        next.resume()
    }

    func startIfNeeded() throws {
        if let process, process.isRunning {
            return
        }
        shutdown()

        let workerScript = toolsDirectory.appendingPathComponent("vfcommit_worker.py")
        guard FileManager.default.fileExists(atPath: workerScript.path) else {
            throw CommitServiceError.helperNotFound
        }

        let process = Process()
        if pythonExecutable.hasSuffix("env") {
            process.executableURL = URL(fileURLWithPath: pythonExecutable)
            process.arguments = ["python3", workerScript.path]
        } else {
            process.executableURL = URL(fileURLWithPath: pythonExecutable)
            process.arguments = [workerScript.path]
        }
        process.currentDirectoryURL = toolsDirectory

        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PYTHONPATH"] ?? ""
        let pythonPath = toolsDirectory.path
        environment["PYTHONPATH"] = existingPath.isEmpty ? pythonPath : "\(pythonPath):\(existingPath)"
        process.environment = environment

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        self.process = process
        stdinHandle = stdinPipe.fileHandleForWriting
        stdoutHandle = stdoutPipe.fileHandleForReading
        stderrHandle = stderrPipe.fileHandleForReading
        Self.startStderrDrain(stderrPipe.fileHandleForReading)
    }

    func ping() async throws {
        _ = try await roundTrip(line: Data("{\"op\":\"ping\"}\n".utf8))
    }

    func commit(_ request: CommitRequest) async throws -> CommitResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(request)
        var line = payload
        line.append(0x0A)
        let responseData = try await roundTrip(line: line)
        return try VarFontJSON.decode(CommitResult.self, from: responseData)
    }

    func analyzeOTFeatures(
        sourcePath: String,
        includeSuggestions: Bool = true
    ) async throws -> OTFeatureAnalysisResult {
        let payload: [String: Any] = [
            "op": "analyze_ot_features",
            "source_path": sourcePath,
            "request_id": UUID().uuidString.lowercased(),
            "include_suggestions": includeSuggestions,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        var line = data
        line.append(0x0A)
        let responseData = try await roundTrip(line: line)
        return try VarFontJSON.decode(OTFeatureAnalysisResult.self, from: responseData)
    }

    func shutdown() {
        stdinHandle?.closeFile()
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil
        stdoutHandle?.closeFile()
        stderrHandle?.closeFile()
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil
    }

    private func roundTrip(line: Data) async throws -> Data {
        await acquireIO()
        defer { releaseIO() }

        try startIfNeeded()
        guard let process, process.isRunning else {
            shutdown()
            throw CommitWorkerError.processExited("worker not running")
        }
        guard let stdinHandle, let stdoutHandle else {
            throw CommitWorkerError.notStarted
        }
        do {
            try stdinHandle.write(contentsOf: line)
            return try await Self.readLine(from: stdoutHandle, timeout: timeoutSeconds)
        } catch {
            shutdown()
            throw error
        }
    }

    private static func startStderrDrain(_ handle: FileHandle) {
        handle.readabilityHandler = { fileHandle in
            let chunk = fileHandle.availableData
            if chunk.isEmpty {
                fileHandle.readabilityHandler = nil
            }
        }
    }

    private static func readLine(from handle: FileHandle, timeout: TimeInterval) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let gate = NSLock()
            var finished = false

            func finish(with result: Result<Data, Error>) {
                gate.lock()
                defer { gate.unlock() }
                guard !finished else { return }
                finished = true
                handle.readabilityHandler = nil
                switch result {
                case let .success(data):
                    continuation.resume(returning: data)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }

            var buffer = Data()
            handle.readabilityHandler = { fileHandle in
                let chunk = fileHandle.availableData
                if chunk.isEmpty {
                    finish(with: .failure(CommitWorkerError.processExited("stdout closed")))
                    return
                }
                buffer.append(chunk)
                if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    finish(with: .success(Data(buffer[..<newlineIndex])))
                }
            }

            Task {
                let nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                finish(with: .failure(CommitWorkerError.timedOut))
            }
        }
    }
}

actor CommitWorkerManager {
    private var worker: CommitWorker?
    private var configurationKey: String?
    /// Prevents restart/shutdown from racing another in-flight worker op (actor reentrancy).
    private var sessionBusy = false
    private var sessionWaiters: [CheckedContinuation<Void, Never>] = []

    static let shared = CommitWorkerManager()

    private func acquireSession() async {
        if !sessionBusy {
            sessionBusy = true
            return
        }
        await withCheckedContinuation { continuation in
            sessionWaiters.append(continuation)
        }
    }

    private func releaseSession() {
        if sessionWaiters.isEmpty {
            sessionBusy = false
            return
        }
        let next = sessionWaiters.removeFirst()
        next.resume()
    }

    func commit(
        _ request: CommitRequest,
        helperURL: URL,
        pythonExecutable: String
    ) async throws -> CommitResult {
        await acquireSession()
        defer { releaseSession() }
        let worker = try await readyWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
        do {
            return try await worker.commit(request)
        } catch {
            await worker.shutdown()
            self.worker = nil
            self.configurationKey = nil
            let restarted = try await readyWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
            return try await restarted.commit(request)
        }
    }

    func analyzeOTFeatures(
        sourcePath: String,
        helperURL: URL,
        pythonExecutable: String,
        includeSuggestions: Bool = true
    ) async throws -> OTFeatureAnalysisResult {
        await acquireSession()
        defer { releaseSession() }
        let worker = try await readyWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
        do {
            return try await worker.analyzeOTFeatures(
                sourcePath: sourcePath,
                includeSuggestions: includeSuggestions
            )
        } catch {
            await worker.shutdown()
            self.worker = nil
            self.configurationKey = nil
            let restarted = try await readyWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
            return try await restarted.analyzeOTFeatures(
                sourcePath: sourcePath,
                includeSuggestions: includeSuggestions
            )
        }
    }

    func ensureReady(helperURL: URL, pythonExecutable: String) async {
        await acquireSession()
        defer { releaseSession() }
        do {
            let worker = try await readyWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
            try await worker.ping()
        } catch {
            // Fall back to one-shot commits when the worker cannot start.
        }
    }

    func shutdown() async {
        await acquireSession()
        defer { releaseSession() }
        if let worker {
            await worker.shutdown()
        }
        worker = nil
        configurationKey = nil
    }

    private func readyWorker(helperURL: URL, pythonExecutable: String) async throws -> CommitWorker {
        let key = "\(helperURL.path)|\(pythonExecutable)"
        if configurationKey != key || worker == nil {
            if let worker {
                await worker.shutdown()
            }
            worker = CommitWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
            configurationKey = key
        }
        guard let worker else {
            throw CommitWorkerError.notStarted
        }
        return worker
    }
}
