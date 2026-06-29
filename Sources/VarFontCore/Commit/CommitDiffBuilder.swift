import Foundation

public enum CommitDiffBuilder {
    public static func build(
        analysis: FontAnalysis,
        font: FontDocument,
        plan: InstancePlan,
        result: CommitResult
    ) -> CommitDiffReport {
        CommitDiffReport(
            statRows: buildStatRows(analysis: analysis, font: font, diff: result.diff),
            instanceRows: buildInstanceRows(analysis: analysis, plan: plan, diff: result.diff),
            nameIDRows: buildNameIDRows(analysis: analysis, diff: result.diff)
        )
    }

    // MARK: - STAT

    private static func buildStatRows(
        analysis: FontAnalysis,
        font: FontDocument,
        diff: CommitDiff?
    ) -> [CommitDiffStatRow] {
        let projectTags = Set(font.axes.map(\.tag))
        var beforeByKey: [String: FontAnalysis.StatValueRecord] = [:]
        for record in analysis.statValues {
            let key = statKey(tag: record.tag, value: record.value ?? record.nominal ?? 0)
            beforeByKey[key] = record
        }

        var afterStops: [(tag: String, stop: AxisValue)] = []
        for axis in font.axes {
            for stop in axis.values {
                afterStops.append((axis.tag, stop))
            }
        }

        let plannedNameIDs = Dictionary(
            uniqueKeysWithValues: (diff?.statValuesPlanned ?? []).compactMap { item -> (String, Int)? in
                guard let nameID = item.nameID else { return nil }
                return (statKey(tag: item.tag, value: item.value), nameID)
            }
        )

        var keys = Set(afterStops.map { statKey(tag: $0.tag, value: $0.stop.value) })
        for (key, before) in beforeByKey where projectTags.contains(before.tag) {
            keys.insert(key)
        }

        return keys.sorted().map { key in
            let before = beforeByKey[key]
            let afterItem = afterStops.first { statKey(tag: $0.tag, value: $0.stop.value) == key }
            let afterName = afterItem?.stop.name
            let afterNameID = plannedNameIDs[key]
            let change = statChangeKind(
                beforeName: before?.name,
                beforeNameID: before?.nameID,
                afterName: afterName,
                afterNameID: afterNameID
            )
            let parts = key.split(separator: ":", maxSplits: 1)
            let tag = String(parts.first ?? "")
            let value = Double(parts.last ?? "0") ?? 0
            return CommitDiffStatRow(
                tag: tag,
                value: value,
                beforeName: before?.name,
                afterName: afterName,
                beforeNameID: before?.nameID,
                afterNameID: afterNameID,
                change: change
            )
        }
        .sorted { lhs, rhs in
            if lhs.tag != rhs.tag { return lhs.tag < rhs.tag }
            return lhs.value < rhs.value
        }
    }

    private static func statChangeKind(
        beforeName: String?,
        beforeNameID: Int?,
        afterName: String?,
        afterNameID: Int?
    ) -> CommitDiffChangeKind {
        guard let afterName else {
            return beforeName == nil ? .unchanged : .removed
        }
        guard let beforeName, !beforeName.isEmpty else {
            return .added
        }
        if beforeName == afterName {
            if beforeNameID != afterNameID {
                return .changed
            }
            return .unchanged
        }
        if beforeNameID == 2 || beforeName == "Regular" {
            return .changed
        }
        return .changed
    }

    // MARK: - Instances

    private static func buildInstanceRows(
        analysis: FontAnalysis,
        plan: InstancePlan,
        diff: CommitDiff?
    ) -> [CommitDiffInstanceRow] {
        let beforeByKey = Dictionary(
            uniqueKeysWithValues: analysis.instancesExisting.map { ($0.key, $0) }
        )
        let afterByKey = Dictionary(
            uniqueKeysWithValues: plan.instances.filter(\.included).map { ($0.key, $0) }
        )
        _ = diff

        var keys = Set(beforeByKey.keys)
        keys.formUnion(afterByKey.keys)

        return keys.sorted().map { key in
            let before = beforeByKey[key]
            let after = afterByKey[key]
            let change: CommitDiffChangeKind
            if before == nil {
                change = .added
            } else if after == nil {
                change = .removed
            } else if before?.composedName == after?.composedName {
                change = .unchanged
            } else {
                change = .changed
            }
            return CommitDiffInstanceRow(
                key: key,
                beforeName: before?.composedName,
                afterName: after?.composedName,
                coords: after?.coords ?? before?.coords,
                change: change
            )
        }
    }

    // MARK: - Name IDs

    private static func buildNameIDRows(
        analysis: FontAnalysis,
        diff: CommitDiff?
    ) -> [CommitDiffNameIDRow] {
        let beforeUses = analysis.nameAudit.used.filter { $0.id >= 256 }
        let afterRecords = diff?.nameRecordsPlanned ?? []

        var remainingBefore = beforeUses
        var rows: [CommitDiffNameIDRow] = []

        for after in afterRecords.sorted(by: { $0.id < $1.id }) {
            if let matchIndex = remainingBefore.firstIndex(where: {
                stringsMatch($0.string, after.string)
            }) {
                let before = remainingBefore.remove(at: matchIndex)
                let change: CommitDiffChangeKind = (before.string == after.string && before.id == after.id)
                    ? .unchanged
                    : .changed
                rows.append(
                    CommitDiffNameIDRow(
                        beforeID: before.id,
                        afterID: after.id,
                        beforeDescription: before.description,
                        beforeString: before.string,
                        afterString: after.string,
                        afterRole: after.role,
                        change: change
                    )
                )
            } else {
                rows.append(
                    CommitDiffNameIDRow(
                        beforeID: nil,
                        afterID: after.id,
                        beforeDescription: nil,
                        beforeString: nil,
                        afterString: after.string,
                        afterRole: after.role,
                        change: .added
                    )
                )
            }
        }

        for before in remainingBefore.sorted(by: { $0.id < $1.id }) {
            rows.append(
                CommitDiffNameIDRow(
                    beforeID: before.id,
                    afterID: nil,
                    beforeDescription: before.description,
                    beforeString: before.string,
                    afterString: nil,
                    afterRole: nil,
                    change: .removed
                )
            )
        }

        return rows.sorted { lhs, rhs in
            let left = lhs.afterID ?? lhs.beforeID ?? 0
            let right = rhs.afterID ?? rhs.beforeID ?? 0
            return left < right
        }
    }

    private static func stringsMatch(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs, !lhs.isEmpty else { return false }
        return lhs == rhs
    }

    private static func statKey(tag: String, value: Double) -> String {
        let formatted = value.rounded() == value ? String(Int(value)) : String(value)
        return "\(tag):\(formatted)"
    }
}
