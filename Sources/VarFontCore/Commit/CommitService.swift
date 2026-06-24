import Foundation

public enum CommitServiceError: Error, Equatable, Sendable {
    case notImplemented
    case helperUnavailable(String)
    case helperFailed(String)
}

/// Save-time commit bridge. v0 returns a structured not-implemented result;
/// later this shells out to bundled `vfcommit`.
public struct CommitService: Sendable {
    public var helperURL: URL?

    public init(helperURL: URL? = nil) {
        self.helperURL = helperURL
    }

    public func commit(_ request: CommitRequest) async throws -> CommitResult {
        if request.dryRun {
            return CommitResult(
                schemaVersion: 1,
                requestID: request.requestID,
                ok: true,
                outputPath: nil,
                dryRun: true,
                summary: CommitSummary(
                    instancesWritten: request.includedInstanceKeys.count,
                    statValuesWritten: request.axes.flatMap(\.values).count,
                    nameIDsAllocated: [],
                    wipedInstanceCount: 0,
                    protectedNameIDs: []
                ),
                warnings: [],
                errors: []
            )
        }

        guard let helperURL else {
            throw CommitServiceError.notImplemented
        }

        throw CommitServiceError.helperUnavailable(helperURL.path)
    }
}
