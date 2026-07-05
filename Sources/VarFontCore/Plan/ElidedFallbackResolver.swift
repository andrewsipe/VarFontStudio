import Foundation

public enum ElidedFallbackResolver {
    public struct Result: Equatable, Sendable {
        public var value: String
        public var inferred: Bool

        public init(value: String, inferred: Bool) {
            self.value = value
            self.inferred = inferred
        }
    }

    /// Resolve the table-level elided fallback per STAT §6 baseline rules.
    public static func resolve(
        axes: [AxisDefinition],
        namingOrder: [String],
        fileStatRegistration: [String: Double],
        sourceElidedFallback: String?,
        fileRole: FileRole?
    ) -> Result {
        if let override = fileRole?.elidedFallbackOverride?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return Result(value: override, inferred: false)
        }

        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        var parts: [String] = []

        for token in namingOrder {
            guard !NamingToken.isClarifier(token) else { continue }
            guard let axis = axisByTag[token] else { continue }

            if axis.isDesignRecordOnly {
                guard let regValue = fileStatRegistration[token],
                      let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: regValue),
                      !stop.elidable else { continue }
                parts.append(stop.name)
                continue
            }

            guard axis.role == .instance || axis.role == .statOnly || axis.role == .parametric else { continue }
            guard let baseline = axis.values.first(where: \.elidable),
                  let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: baseline.value),
                  !stop.elidable else { continue }
            parts.append(stop.name)
        }

        if parts.isEmpty {
            if let source = sourceElidedFallback?.trimmingCharacters(in: .whitespacesAndNewlines),
               !source.isEmpty {
                return Result(value: source, inferred: false)
            }
            return Result(value: "Regular", inferred: true)
        }

        return Result(value: parts.joined(separator: " "), inferred: false)
    }
}
