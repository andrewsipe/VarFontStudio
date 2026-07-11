import Foundation

public enum CommitWorkerError: Error, Equatable, Sendable {
    case notStarted
    case processExited(String)
    case invalidResponse(String)
    case timedOut
}

/// Long-lived vfcommit NDJSON subprocess for interactive save previews.
actor CommitWorker {
    private let helperURL: URL
    private let pythonExecutable: String
    private let toolsDirectory: URL
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private let timeoutSeconds: TimeInterval = 60

    init(helperURL: URL, pythonExecutable: String) {
        self.helperURL = helperURL
        self.pythonExecutable = pythonExecutable
        self.toolsDirectory = helperURL.deletingLastPathComponent()
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

enum CommitWorkerManager {
    private static var worker: CommitWorker?
    private static var configurationKey: String?

    static func commit(
        _ request: CommitRequest,
        helperURL: URL,
        pythonExecutable: String
    ) async throws -> CommitResult {
        try await commitOnce(request, helperURL: helperURL, pythonExecutable: pythonExecutable)
    }

    private static func commitOnce(
        _ request: CommitRequest,
        helperURL: URL,
        pythonExecutable: String
    ) async throws -> CommitResult {
        let key = "\(helperURL.path)|\(pythonExecutable)"
        if configurationKey != key {
            if let worker {
                await worker.shutdown()
            }
            worker = CommitWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
            configurationKey = key
        }
        guard let worker else {
            throw CommitWorkerError.notStarted
        }

        do {
            return try await worker.commit(request)
        } catch {
            await worker.shutdown()
            self.worker = CommitWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
            configurationKey = key
            guard let restarted = self.worker else {
                throw CommitWorkerError.notStarted
            }
            return try await restarted.commit(request)
        }
    }

    static func ensureReady(helperURL: URL, pythonExecutable: String) async {
        do {
            let key = "\(helperURL.path)|\(pythonExecutable)"
            if configurationKey != key {
                if let worker {
                    await worker.shutdown()
                }
                worker = CommitWorker(helperURL: helperURL, pythonExecutable: pythonExecutable)
                configurationKey = key
            }
            guard let worker else { return }
            try await worker.ping()
        } catch {
            // Fall back to one-shot commits when the worker cannot start.
        }
    }

    static func shutdown() async {
        if let worker {
            await worker.shutdown()
        }
        worker = nil
        configurationKey = nil
    }
}
