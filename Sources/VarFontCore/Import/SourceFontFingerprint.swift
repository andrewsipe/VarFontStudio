import CoreText
import Foundation

/// Lightweight source-font identity for drift checks at Review / Export.
///
/// Stored on `FontDocument.analysisSnapshotID`. Format:
/// `v1;m=<mtime_ms>;s=<size>;f=<tag>:<min>:<def>:<max>,...`
///
/// `m`/`s` detect any on-disk change; `f` isolates fvar design-space changes
/// (the scales export does not rewrite).
public struct SourceFontFingerprint: Equatable, Sendable {
    public var modifiedMilliseconds: Int64
    public var fileSize: Int
    /// Ordered fvar axis scales: `tag:min:default:max`, comma-separated.
    public var fvarDesignSpace: String

    public init(modifiedMilliseconds: Int64, fileSize: Int, fvarDesignSpace: String) {
        self.modifiedMilliseconds = modifiedMilliseconds
        self.fileSize = fileSize
        self.fvarDesignSpace = fvarDesignSpace
    }

    public var serialized: String {
        "v1;m=\(modifiedMilliseconds);s=\(fileSize);f=\(fvarDesignSpace)"
    }

    public static func parse(_ raw: String?) -> SourceFontFingerprint? {
        guard let raw, !raw.isEmpty else { return nil }
        var modified: Int64?
        var size: Int?
        var fvar = ""
        for part in raw.split(separator: ";") {
            if part.hasPrefix("m="), let value = Int64(part.dropFirst(2)) {
                modified = value
            } else if part.hasPrefix("s="), let value = Int(part.dropFirst(2)) {
                size = value
            } else if part.hasPrefix("f=") {
                fvar = String(part.dropFirst(2))
            } else if part == "v1" {
                continue
            }
        }
        guard let modified, let size else { return nil }
        return SourceFontFingerprint(
            modifiedMilliseconds: modified,
            fileSize: size,
            fvarDesignSpace: fvar
        )
    }

    // MARK: - Capture

    public static func capture(url: URL, analysis: FontAnalysis) -> SourceFontFingerprint? {
        guard let identity = fileIdentity(of: url) else { return nil }
        return SourceFontFingerprint(
            modifiedMilliseconds: identity.modifiedMilliseconds,
            fileSize: identity.fileSize,
            fvarDesignSpace: fvarToken(from: analysis)
        )
    }

    /// Capture using a live fvar read (post-export refresh, no analysis in hand).
    public static func capture(url: URL) -> SourceFontFingerprint? {
        guard let identity = fileIdentity(of: url) else { return nil }
        return SourceFontFingerprint(
            modifiedMilliseconds: identity.modifiedMilliseconds,
            fileSize: identity.fileSize,
            fvarDesignSpace: fvarToken(reading: url) ?? ""
        )
    }

    public static func fileIdentity(of url: URL) -> (modifiedMilliseconds: Int64, fileSize: Int)? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let modified = values.contentModificationDate,
              let size = values.fileSize else {
            return nil
        }
        return (
            Int64((modified.timeIntervalSince1970 * 1000.0).rounded()),
            size
        )
    }

    public static func fvarToken(from analysis: FontAnalysis) -> String {
        fvarToken(
            axes: analysis.axes
                .filter { $0.roleInferred != .designRecordOnly }
                .map { ($0.tag, $0.min, $0.default, $0.max) }
        )
    }

    // MARK: - Probe

    public struct ProbeResult: Equatable, Sendable {
        /// No stored baseline (legacy project) — capture silently, do not warn.
        public var missingBaseline: Bool
        public var fileIdentityChanged: Bool
        public var designSpaceChanged: Bool
        public var current: SourceFontFingerprint?

        public var hasDrift: Bool { fileIdentityChanged || designSpaceChanged }

        public var warnings: [PlanWarning] {
            guard hasDrift else { return [] }
            var list: [PlanWarning] = []
            if designSpaceChanged {
                list.append(
                    PlanWarning(
                        code: "source_design_space_changed",
                        message: "Source font fvar design space changed on disk since this project last captured it.",
                        hint: "Export still patches naming/STAT/instances onto the live file and does not rewrite fvar min/default/max. Re-open the font if the plan should match the new design space."
                    )
                )
            } else if fileIdentityChanged {
                list.append(
                    PlanWarning(
                        code: "source_file_changed",
                        message: "Source font file changed on disk since this project last captured it.",
                        hint: "Outlines and variation data from the live file will be used; naming/STAT/instances from this project still overwrite on export."
                    )
                )
            }
            return list
        }

        public var notes: [String] {
            warnings.map { warning in
                if let hint = warning.hint {
                    return "\(warning.message) \(hint)"
                }
                return warning.message
            }
        }
    }

    /// Compare a stored snapshot to the live file + current analysis.
    public static func probe(
        stored: String?,
        url: URL,
        analysis: FontAnalysis
    ) -> ProbeResult {
        guard let current = capture(url: url, analysis: analysis) else {
            return ProbeResult(
                missingBaseline: stored == nil,
                fileIdentityChanged: false,
                designSpaceChanged: false,
                current: nil
            )
        }
        return compare(stored: stored, current: current)
    }

    /// Compare a previously captured fingerprint to a live capture (preferred when
    /// the live fingerprint was taken under a security-scoped read).
    public static func compare(stored: String?, current: SourceFontFingerprint) -> ProbeResult {
        guard let baseline = parse(stored) else {
            return ProbeResult(
                missingBaseline: true,
                fileIdentityChanged: false,
                designSpaceChanged: false,
                current: current
            )
        }
        let identityChanged = baseline.modifiedMilliseconds != current.modifiedMilliseconds
            || baseline.fileSize != current.fileSize
        let designChanged = baseline.fvarDesignSpace != current.fvarDesignSpace
        return ProbeResult(
            missingBaseline: false,
            fileIdentityChanged: identityChanged,
            designSpaceChanged: designChanged,
            current: current
        )
    }

    public static func mergeWarnings(into result: inout CommitResult, probe: ProbeResult) {
        for warning in probe.warnings.reversed() {
            guard !result.warnings.contains(where: { $0.code == warning.code }) else { continue }
            result.warnings.insert(warning, at: 0)
        }
    }

    // MARK: - Private

    private static func fvarToken(
        axes: [(tag: String, min: Double, default: Double, max: Double)]
    ) -> String {
        axes.map { axis in
            let min = AxisCoordinateFormat.format(axis.min)
            let def = AxisCoordinateFormat.format(axis.default)
            let max = AxisCoordinateFormat.format(axis.max)
            return "\(axis.tag):\(min):\(def):\(max)"
        }
        .joined(separator: ",")
    }

    private static func fvarToken(reading url: URL) -> String? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first else {
            return nil
        }
        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        guard let fvarData = CTFontCopyTable(font, OpenTypeBinary.tag("fvar"), []) as Data?,
              let parsed = FvarParser.parse(fvarData) else {
            return nil
        }
        return fvarToken(
            axes: parsed.axes.map { ($0.tag, $0.min, $0.defaultValue, $0.max) }
        )
    }
}
