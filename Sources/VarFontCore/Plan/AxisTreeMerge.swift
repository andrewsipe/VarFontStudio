import Foundation

/// Merges a master font's axis tree into sibling project files (Push to tree).
public enum AxisTreeMerge {
    public static func mergeAxesFromMaster(
        master: [AxisDefinition],
        into target: [AxisDefinition],
        syncRoles: Bool,
        targetFileStatRegistration: [String: Double] = [:],
        targetIsItalicFile: Bool = false
    ) -> [AxisDefinition] {
        let targetByTag = Dictionary(uniqueKeysWithValues: target.map { ($0.tag, $0) })
        var merged: [AxisDefinition] = []
        for masterAxis in master {
            if var existing = targetByTag[masterAxis.tag] {
                existing.displayName = masterAxis.displayName
                if !existing.isDesignRecordOnly {
                    existing.values = copyStops(from: masterAxis)
                }
                if syncRoles, !existing.isDesignRecordOnly {
                    existing.role = masterAxis.role
                }
                existing.referenceMapping = masterAxis.referenceMapping
                existing.referenceMappingInferred = masterAxis.referenceMappingInferred
                existing.referenceAnchors = masterAxis.referenceAnchors
                merged.append(existing)
            } else {
                var imported = masterAxis
                imported.values = copyStops(from: masterAxis)
                merged.append(imported)
            }
        }
        for axis in target where !master.contains(where: { $0.tag == axis.tag }) {
            merged.append(axis)
        }

        if let masterItal = master.first(where: { $0.tag == "ital" }),
           let italIndex = merged.firstIndex(where: { $0.tag == "ital" && $0.isDesignRecordOnly }) {
            applyMirroredItalFormat3(
                masterItal: masterItal,
                targetItal: &merged[italIndex],
                targetFileStatRegistration: targetFileStatRegistration,
                targetIsItalicFile: targetIsItalicFile
            )
        }

        return merged
    }

    /// When the master uses `ital` Format 3 style linking, mirror it onto the variant's
    /// registered stop (Roman 0→1 on master, Italic 1→0 on italic variants).
    private static func applyMirroredItalFormat3(
        masterItal: AxisDefinition,
        targetItal: inout AxisDefinition,
        targetFileStatRegistration: [String: Double],
        targetIsItalicFile: Bool
    ) {
        guard masterUsesItalFormat3Convention(masterItal) else { return }

        guard let registrationValue = targetFileStatRegistration["ital"]
            ?? RegistrationAxisSupport.inferRegistrationValue(
                forTag: "ital",
                axes: [targetItal],
                inferredIsItalicFile: targetIsItalicFile
            ) else { return }

        guard let stopIndex = targetItal.values.firstIndex(where: {
            AxisCoordinate.valuesEqual($0.value, registrationValue)
        }) else { return }

        guard let linked = RegistrationAxisSupport.italFormat3LinkedValue(for: registrationValue) else {
            return
        }

        targetItal.values[stopIndex].statFormat = 3
        targetItal.values[stopIndex].linkedValue = linked
        targetItal.values[stopIndex].rangeMin = nil
        targetItal.values[stopIndex].rangeMax = nil
    }

    private static func masterUsesItalFormat3Convention(_ axis: AxisDefinition) -> Bool {
        axis.values.contains { stop in
            stop.statFormat == 3
                && StatFormat3Pairing.isConventionStyleLink(axis: axis, stop: stop)
        }
    }

    private static func copyStops(from axis: AxisDefinition) -> [AxisValue] {
        axis.values.map { stop in
            var copy = stop
            copy.id = "\(axis.tag)-\(UUID().uuidString.prefix(8))"
            return copy
        }
    }
}
