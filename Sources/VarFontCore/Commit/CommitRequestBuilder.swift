import Foundation

/// Builds save payloads for vfcommit from live project state.
public enum CommitRequestBuilder {
    public static func make(
        font: FontDocument,
        naming: NamingPolicy,
        plan: InstancePlan,
        outputPath: String,
        dryRun: Bool
    ) -> CommitRequest {
        CommitRequest(
            schemaVersion: 1,
            requestID: UUID().uuidString.lowercased(),
            sourcePath: font.sourcePath,
            outputPath: outputPath,
            dryRun: dryRun,
            options: font.options,
            naming: namingForCommit(naming),
            axes: orderedAxes(font.axes, naming: naming),
            includedInstanceKeys: includedInstanceKeys(font: font, plan: plan)
        )
    }

    public static func suggestedOutputPath(for sourcePath: String) -> String {
        let source = URL(fileURLWithPath: sourcePath)
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        let suffix = ext.isEmpty ? "\(stem)-patched" : "\(stem)-patched.\(ext)"
        return source.deletingLastPathComponent().appendingPathComponent(suffix).path
    }

    public static func orderedAxes(_ axes: [AxisDefinition], naming: NamingPolicy) -> [AxisDefinition] {
        let byTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        var ordered: [AxisDefinition] = []
        for tag in naming.order {
            if let axis = byTag[tag] {
                ordered.append(axis)
            }
        }
        for axis in axes where !naming.order.contains(axis.tag) {
            ordered.append(axis)
        }
        return ordered
    }

    public static func includedInstanceKeys(font: FontDocument, plan: InstancePlan) -> [String] {
        if !font.includedInstanceKeys.isEmpty {
            return font.includedInstanceKeys
        }
        if !font.excludedInstanceKeys.isEmpty {
            return plan.instances.filter(\.included).map(\.key)
        }
        return []
    }

    private static func namingForCommit(_ naming: NamingPolicy) -> NamingPolicy {
        NamingPolicy(order: naming.order, elidedFallback: naming.elidedFallback)
    }
}
