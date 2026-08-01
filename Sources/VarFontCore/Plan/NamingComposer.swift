import Foundation

public enum NamingComposer {
    public struct Link: Equatable, Sendable {
        public var kind: NamingChainLink.Kind
        public var tag: String
        public var name: String
        public var elided: Bool

        public init(kind: NamingChainLink.Kind = .axis, tag: String, name: String, elided: Bool) {
            self.kind = kind
            self.tag = tag
            self.name = name
            self.elided = elided
        }
    }

    /// Compose a style name from axis stops, Format 4 compounds, and per-file clarifiers.
    public static func compose(
        coords: [String: Double],
        axes: [AxisDefinition],
        naming: NamingPolicy,
        fileRole: FileRole? = nil,
        fileStatRegistration: [String: Double] = [:],
        compounds: [CompoundStatValue] = []
    ) -> (name: String, chain: [Link]) {
        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        let coveredClarifiers = RegistrationAxisSupport.clarifierCategoriesCoveredByRegistration(
            axes: axes,
            fileStatRegistration: fileStatRegistration
        )
        let selected = CompoundStatNaming.selectedMatches(compounds: compounds, coords: coords)
        let plan = CompoundStatNaming.emitPlan(selected: selected, namingOrder: naming.order)

        var chain: [Link] = []
        var parts: [String] = []

        for token in naming.order {
            if NamingToken.isPostscriptHyphen(token) {
                continue
            }
            if NamingToken.isCode(token) {
                if let code = InstanceCodeBuilder.compose(
                    axes: axes,
                    coords: coords,
                    fileStatRegistration: fileStatRegistration,
                    fileRole: fileRole,
                    namingOrder: naming.order
                ) {
                    chain.append(Link(kind: .code, tag: NamingPolicy.codeToken, name: code, elided: false))
                    parts.append(code)
                }
                continue
            }
            if NamingToken.isClarifier(token) {
                guard let category = NamingToken.clarifierCategory(for: token),
                      let label = fileRole?.label(for: category),
                      !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                if coveredClarifiers.contains(category) {
                    continue
                }
                chain.append(Link(kind: .clarifier, tag: token, name: label, elided: false))
                parts.append(label)
                continue
            }

            if let compound = plan.emitAtTag[token] {
                let name = compound.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let elided = compound.elidable
                chain.append(
                    Link(
                        kind: .compound,
                        tag: CompoundStatNaming.chainTag(for: compound),
                        name: name.isEmpty ? CompoundStatNaming.chainTag(for: compound) : name,
                        elided: elided
                    )
                )
                if !elided, !name.isEmpty {
                    parts.append(name)
                }
                continue
            }

            if plan.claimedTags.contains(token) {
                continue
            }

            if let axis = axisByTag[token], axis.isDesignRecordOnly {
                guard let resolved = RegistrationAxisSupport.registrationStopName(
                    tag: token,
                    axes: axes,
                    fileStatRegistration: fileStatRegistration
                ) else { continue }
                chain.append(Link(kind: .registration, tag: token, name: resolved.stop.name, elided: resolved.elided))
                if !resolved.elided {
                    parts.append(resolved.stop.name)
                }
                continue
            }

            guard let value = coords[token] else { continue }
            guard let axis = axisByTag[token] else { continue }
            guard axis.role == .instance else { continue }
            guard let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: value) else { continue }

            let elided = stop.elidable
            chain.append(Link(kind: .axis, tag: token, name: stop.name, elided: elided))
            if !elided {
                parts.append(stop.name)
            }
        }

        let fallback = fileRole?.elidedFallbackOverride ?? naming.elidedFallback
        let name = parts.isEmpty ? fallback : parts.joined(separator: " ")
        return (name, chain)
    }
}
