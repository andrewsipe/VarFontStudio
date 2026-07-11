import Foundation

public enum ProjectDocumentStoreError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case writeFailed(String)
}

/// VarFont Studio project file on disk (JSON).
public enum ProjectFileFormat {
    public static let preferredExtension = "varf"
    public static let legacyExtensions = ["varfont"]

    public static func isProjectFileURL(_ url: URL) -> Bool {
        matchesExtension(url.pathExtension)
    }

    public static func matchesExtension(_ pathExtension: String) -> Bool {
        let ext = pathExtension.lowercased()
        return ext == preferredExtension || legacyExtensions.contains(ext)
    }

    /// Append `.varf` when the URL has no recognized project extension.
    public static func normalizedProjectFileURL(_ url: URL) -> URL {
        if matchesExtension(url.pathExtension) {
            return url
        }
        return url.appendingPathExtension(preferredExtension)
    }

    public static func defaultFilename(stem: String) -> String {
        "\(stem).\(preferredExtension)"
    }
}

/// Resolve stored font paths relative to a project file location.
public enum ProjectPathResolver {
    public static func projectDirectory(for projectFileURL: URL) -> URL {
        projectFileURL.deletingLastPathComponent()
    }

    public static func resolveStoredPath(_ storedPath: String, relativeTo projectDirectory: URL) -> String {
        guard !storedPath.isEmpty else { return storedPath }
        if (storedPath as NSString).isAbsolutePath {
            return URL(fileURLWithPath: storedPath).standardizedFileURL.path
        }
        return projectDirectory
            .appendingPathComponent(storedPath)
            .standardizedFileURL
            .path
    }

    public static func storedPath(for absolutePath: String, relativeTo projectDirectory: URL) -> String {
        let absURL = URL(fileURLWithPath: absolutePath).standardizedFileURL
        let baseURL = projectDirectory.standardizedFileURL
        let absPath = absURL.path
        let basePath = baseURL.path
        if absPath.hasPrefix(basePath + "/") {
            return String(absPath.dropFirst(basePath.count + 1))
        }
        return absPath
    }

    public static func resolvePaths(in document: inout ProjectDocument, relativeTo projectDirectory: URL) {
        for index in document.fonts.indices {
            document.fonts[index].sourcePath = resolveStoredPath(
                document.fonts[index].sourcePath,
                relativeTo: projectDirectory
            )
            if let outputPath = document.fonts[index].outputPath {
                document.fonts[index].outputPath = resolveStoredPath(
                    outputPath,
                    relativeTo: projectDirectory
                )
            }
        }
    }

    public static func relativizePaths(in document: inout ProjectDocument, relativeTo projectDirectory: URL) {
        for index in document.fonts.indices {
            document.fonts[index].sourcePath = storedPath(
                for: document.fonts[index].sourcePath,
                relativeTo: projectDirectory
            )
            if let outputPath = document.fonts[index].outputPath {
                document.fonts[index].outputPath = storedPath(
                    for: outputPath,
                    relativeTo: projectDirectory
                )
            }
        }
    }
}

public enum ProjectDocumentStore {
    public static let supportedSchemaVersion = 1

    public static func load(from url: URL) throws -> ProjectDocument {
        var document = try VarFontJSON.decode(ProjectDocument.self, from: url)
        guard document.schemaVersion == supportedSchemaVersion else {
            throw ProjectDocumentStoreError.unsupportedSchemaVersion(document.schemaVersion)
        }
        let projectDirectory = ProjectPathResolver.projectDirectory(for: url)
        ProjectPathResolver.resolvePaths(in: &document, relativeTo: projectDirectory)
        return document
    }

    public static func encode(_ document: ProjectDocument) throws -> Data {
        try VarFontJSON.encode(document)
    }

    public static func save(_ document: ProjectDocument, to url: URL) throws {
        var copy = document
        copy.modified = Date()
        let projectDirectory = ProjectPathResolver.projectDirectory(for: url)
        ProjectPathResolver.relativizePaths(in: &copy, relativeTo: projectDirectory)
        let data = try encode(copy)

        let fileManager = FileManager.default
        let tempURL = projectDirectory.appendingPathComponent(".varf-save-\(UUID().uuidString).tmp")
        do {
            try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw ProjectDocumentStoreError.writeFailed(error.localizedDescription)
        }
    }
}
