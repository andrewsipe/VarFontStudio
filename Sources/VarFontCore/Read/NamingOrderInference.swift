import Foundation

enum NamingOrderInference {
    /// Preferred ordering for common instance axes when present in the font.
    static let canonicalAxisOrder = ["opsz", "wdth", "wght", "slnt", "ital"]

    static func suggest(
        designAxes: [StatDesignAxis],
        fvarAxisTags: [String] = []
    ) -> [String] {
        let knownTags = Set(designAxes.map(\.tag)).union(fvarAxisTags)
        var order: [String] = []
        var seen = Set<String>()

        for axis in designAxes.sorted(by: { $0.ordering < $1.ordering }) {
            guard knownTags.contains(axis.tag), seen.insert(axis.tag).inserted else { continue }
            order.append(axis.tag)
        }

        let fvarSet = Set(fvarAxisTags)
        let canonicalFvar = canonicalAxisOrder.filter { fvarSet.contains($0) }
        let otherFvar = fvarAxisTags.filter { !canonicalAxisOrder.contains($0) }.sorted()

        for tag in canonicalFvar + otherFvar where seen.insert(tag).inserted {
            order.append(tag)
        }

        return enforceSlntBeforeItal(order)
    }

    /// When both slope axes are present, prefer `slnt` before `ital`.
    private static func enforceSlntBeforeItal(_ order: [String]) -> [String] {
        guard let slntIndex = order.firstIndex(of: "slnt"),
              let italIndex = order.firstIndex(of: "ital"),
              slntIndex > italIndex else { return order }
        var result = order
        result.remove(at: slntIndex)
        result.insert("slnt", at: italIndex)
        return result
    }
}
