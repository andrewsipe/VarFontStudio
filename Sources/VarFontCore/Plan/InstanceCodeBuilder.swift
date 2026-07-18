import Foundation

/// Builds Univers-style classification codes from per-stop fragments on Axis Tree axes.
public enum InstanceCodeBuilder {
    public static let maxLength = 2

    /// Keep letters and digits only; cap at two characters. Empty → `nil`.
    public static func sanitize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let filtered = String(raw.filter { $0.isLetter || $0.isNumber }.prefix(maxLength))
        return filtered.isEmpty ? nil : filtered
    }

    /// Concatenate codes for instance-grid and design-record axes in Axis Tree order.
    /// Elided stops still contribute. Empty codes are skipped.
    public static func compose(
        axes: [AxisDefinition],
        coords: [String: Double],
        fileStatRegistration: [String: Double] = [:],
        fileRole: FileRole? = nil,
        namingOrder: [String] = []
    ) -> String? {
        _ = fileRole
        _ = namingOrder
        var parts: [String] = []
        for axis in axes {
            guard let stop = resolvedStop(
                axis: axis,
                coords: coords,
                fileStatRegistration: fileStatRegistration
            ),
            let code = sanitize(stop.code) else {
                continue
            }
            parts.append(code)
        }
        return parts.isEmpty ? nil : parts.joined()
    }

    private static func resolvedStop(
        axis: AxisDefinition,
        coords: [String: Double],
        fileStatRegistration: [String: Double]
    ) -> AxisValue? {
        switch axis.role {
        case .instance:
            guard let value = coords[axis.tag] else { return nil }
            return AxisCoordinate.matchingStop(in: axis.values, coordinate: value)
        case .designRecordOnly:
            guard let value = fileStatRegistration[axis.tag] else { return nil }
            return AxisCoordinate.matchingStop(in: axis.values, coordinate: value)
        case .statOnly, .parametric:
            return nil
        }
    }
}
