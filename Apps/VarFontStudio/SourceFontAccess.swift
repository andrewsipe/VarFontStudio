import Foundation

/// Security-scoped bookmarks + sandbox-safe copies for vfcommit subprocess access.
enum SourceFontAccess {
    private static let cacheDirectory: URL = {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("VarFontStudio/source-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static func makeBookmark(for url: URL) -> Data? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolveURL(bookmark: Data) throws -> URL {
        var stale = false
        return try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }

    /// Read the source font in-process (Swift parsers).
    static func withReadableSourceURL<T>(
        bookmark: Data?,
        fallbackPath: String,
        _ work: (URL) throws -> T
    ) throws -> T {
        if let bookmark {
            let scopedURL = try resolveURL(bookmark: bookmark)
            let accessed = scopedURL.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    scopedURL.stopAccessingSecurityScopedResource()
                }
            }
            return try work(scopedURL)
        }
        return try work(URL(fileURLWithPath: fallbackPath))
    }

    /// Copy into the app temp dir so vfcommit (child process) can read the font without extra TCC prompts.
    static func helperSourcePath(
        bookmark: Data?,
        fallbackPath: String,
        fontID: String
    ) throws -> String {
        try withReadableSourceURL(bookmark: bookmark, fallbackPath: fallbackPath) { sourceURL in
            let cacheURL = cacheDirectory
                .appendingPathComponent("\(fontID).\(sourceURL.pathExtension)")
            try syncCache(from: sourceURL, to: cacheURL)
            return cacheURL.path
        }
    }

    private static func syncCache(from source: URL, to cache: URL) throws {
        let sourceValues = try source.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        if FileManager.default.fileExists(atPath: cache.path),
           let sourceDate = sourceValues.contentModificationDate,
           let cacheDate = try cache.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           cacheDate >= sourceDate {
            return
        }
        if FileManager.default.fileExists(atPath: cache.path) {
            try FileManager.default.removeItem(at: cache)
        }
        try FileManager.default.copyItem(at: source, to: cache)
    }
}
