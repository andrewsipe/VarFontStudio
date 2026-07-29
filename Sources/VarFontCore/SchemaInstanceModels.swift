import Foundation

// MARK: - Instance (static output)

public struct InstanceRequest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var requestID: String
    public var sourcePath: String
    public var outputDir: String
    public var dryRun: Bool
    public var psPrefix: String?
    public var keepStat: Bool
    public var overwrite: Bool
    public var instances: [InstanceSpec]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case requestID = "request_id"
        case sourcePath = "source_path"
        case outputDir = "output_dir"
        case dryRun = "dry_run"
        case psPrefix = "ps_prefix"
        case keepStat = "keep_stat"
        case overwrite
        case instances
    }

    public init(
        schemaVersion: Int = 1,
        requestID: String = UUID().uuidString.lowercased(),
        sourcePath: String,
        outputDir: String,
        dryRun: Bool = false,
        psPrefix: String? = nil,
        keepStat: Bool = false,
        overwrite: Bool = false,
        instances: [InstanceSpec]
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.sourcePath = sourcePath
        self.outputDir = outputDir
        self.dryRun = dryRun
        self.psPrefix = psPrefix
        self.keepStat = keepStat
        self.overwrite = overwrite
        self.instances = instances
    }
}

public struct InstanceSpec: Codable, Equatable, Sendable {
    /// Row id from the Instancer UI — echoed in progress events.
    public var id: String?
    public var name: String?
    public var coordinates: [String: Double]
    public var postscriptName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case coordinates
        case postscriptName = "postscript_name"
    }

    public init(
        id: String? = nil,
        name: String? = nil,
        coordinates: [String: Double],
        postscriptName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinates = coordinates
        self.postscriptName = postscriptName
    }
}

public struct InstanceResult: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var requestID: String
    public var ok: Bool
    public var dryRun: Bool
    public var outputDir: String?
    public var written: [InstanceWrittenFile]
    public var warnings: [InstanceIssue]
    public var errors: [InstanceIssue]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case requestID = "request_id"
        case ok
        case dryRun = "dry_run"
        case outputDir = "output_dir"
        case written
        case warnings
        case errors
    }
}

public struct InstanceWrittenFile: Codable, Equatable, Sendable {
    public var id: String?
    public var path: String
    public var postscriptName: String?
    public var coordinates: [String: Double]
    public var name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case postscriptName = "postscript_name"
        case coordinates
        case name
    }
}

public struct InstanceIssue: Codable, Equatable, Sendable {
    public var code: String
    public var message: String
    public var id: String?
}

/// Line-delimited progress events emitted on helper stderr during a batch.
public struct InstanceProgressEvent: Codable, Equatable, Sendable {
    public var event: String
    public var id: String?
    public var index: Int
    public var total: Int
    public var name: String?
    public var path: String?
    public var message: String?
}
