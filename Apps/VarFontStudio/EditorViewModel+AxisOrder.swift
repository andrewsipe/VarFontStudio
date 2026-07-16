import Foundation
import VarFontCore

extension EditorViewModel {
    // MARK: - Axis order (bidirectional with naming chain)

    /// Reorders axis blocks in the Axis Tree; syncs naming chips and sibling fonts in the project.
    func reorderAxisTree(moving draggedTag: String, toIndex insertBeforeIndex: Int) {
        guard let projectID = activeProjectID,
              let font = selectedFont else { return }

        let currentTags = font.axes.map(\.tag)
        guard currentTags.firstIndex(of: draggedTag) != nil else { return }
        let reorderedTags = Self.moveTag(currentTags, moving: draggedTag, toIndex: insertBeforeIndex)
        guard reorderedTags != currentTags else { return }

        pushUndoSnapshot()
        applyProjectAxisTagOrder(
            projectID: projectID,
            canonicalOrder: reorderedTags,
            sourceFontID: font.id,
            syncNamingFromCanonical: true
        )
    }

    /// Applies canonical axis tag order across all fonts in a project.
    func applyProjectAxisTagOrder(
        projectID: String,
        canonicalOrder: [String],
        sourceFontID: String? = nil,
        syncNamingFromCanonical: Bool
    ) {
        guard let pIdx = openProjects.firstIndex(where: { $0.id == projectID }) else { return }

        if syncNamingFromCanonical {
            let projectAxisTags = Set(
                openProjects[pIdx].document.fonts.flatMap { $0.axes.map(\.tag) }
            )
            let namingAxisTags = axisTagSubsequence(
                from: openProjects[pIdx].document.naming.order,
                axisTags: Array(projectAxisTags)
            )
            let canonicalAxisTags = canonicalOrder.filter { projectAxisTags.contains($0) }
            if namingAxisTags != canonicalAxisTags {
                openProjects[pIdx].document.naming.order = AxisOrderRealigner.permuteNamingAxisTags(
                    openProjects[pIdx].document.naming.order,
                    axisTags: projectAxisTags,
                    toAxisTagOrder: canonicalAxisTags
                )
            }
        }

        let namingOrder = openProjects[pIdx].document.naming.order
        for fontIndex in openProjects[pIdx].document.fonts.indices {
            var font = openProjects[pIdx].document.fonts[fontIndex]
            let fontCanonical = sourceFontID == font.id && syncNamingFromCanonical
                ? canonicalOrder
                : AxisOrderRealigner.canonicalAxisTagOrder(
                    namingOrder: namingOrder,
                    fontAxisTags: font.axes.map(\.tag)
                )
            AxisOrderRealigner.applyCanonicalOrder(to: &font, canonicalOrder: fontCanonical)
            font.dirty = true
            openProjects[pIdx].document.fonts[fontIndex] = font
        }

        openProjects[pIdx].document.modified = Date()
        markProjectFileDirty(projectID: projectID)
        publishOpenProjects()
        refreshCanSave()
        regeneratePlan()
        resortIncludedInstanceKeys(forProjectID: projectID)
        if syncNamingFromCanonical {
            postStatusMessage("Axis order updated")
        }
    }

    /// After naming-order changes, realign axis trees when axis-tag relative order changed.
    func realignAxesAfterNamingOrderChange(previousOrder: [String], newOrder: [String]) {
        guard let projectID = activeProjectID,
              let font = selectedFont else { return }

        let axisTags = Set(font.axes.map(\.tag))
        let previousAxisTags = axisTagSubsequence(from: previousOrder, axisTags: Array(axisTags))
        let newAxisTags = axisTagSubsequence(from: newOrder, axisTags: Array(axisTags))
        guard previousAxisTags != newAxisTags else { return }

        let canonical = AxisOrderRealigner.canonicalAxisTagOrder(
            namingOrder: newOrder,
            fontAxisTags: font.axes.map(\.tag)
        )
        applyProjectAxisTagOrder(
            projectID: projectID,
            canonicalOrder: canonical,
            syncNamingFromCanonical: false
        )
    }

    func resortIncludedInstanceKeys(forProjectID projectID: String) {
        guard let pIdx = openProjects.firstIndex(where: { $0.id == projectID }) else { return }
        for fontIndex in openProjects[pIdx].document.fonts.indices {
            var font = openProjects[pIdx].document.fonts[fontIndex]
            guard !font.includedInstanceKeys.isEmpty else { continue }
            let plan = InstancePlanner.plan(
                font: font,
                naming: openProjects[pIdx].document.naming
            )
            let planKeys = plan.instances.map(\.key)
            font.includedInstanceKeys = AxisOrderRealigner.resortIncludedInstanceKeys(
                currentKeys: font.includedInstanceKeys,
                planInstanceKeys: planKeys
            )
            openProjects[pIdx].document.fonts[fontIndex] = font
        }
        publishOpenProjects()
    }

    /// On open/import: Axis Tree is primary — permute naming axis chips to match,
    /// then realign sibling fonts from that naming subsequence.
    /// - Parameter markProjectDirty: when true (user-initiated add/import), persist the fix;
    ///   project file opens keep dirty false unless naming actually changed and we need a save hint.
    @discardableResult
    func reconcileNamingToAxisTreeOrder(
        projectID: String,
        authorityFontID: String? = nil,
        markProjectDirtyIfChanged: Bool = true
    ) -> Bool {
        guard let pIdx = openProjects.firstIndex(where: { $0.id == projectID }) else { return false }
        let fonts = openProjects[pIdx].document.fonts
        guard !fonts.isEmpty else { return false }

        let authority =
            fonts.first(where: { $0.id == authorityFontID })
            ?? fonts.first(where: { $0.id == openProjects[pIdx].selectedFontID })
            ?? fonts.first(where: { $0.fileRole?.kind == .master })
            ?? fonts[0]

        let treeOrder = authority.axes.map(\.tag)
        let projectAxisTags = Set(fonts.flatMap { $0.axes.map(\.tag) })
        let namingAxisTags = axisTagSubsequence(
            from: openProjects[pIdx].document.naming.order,
            axisTags: Array(projectAxisTags)
        )
        // Naming only tracks axis tags present in the authority tree + any chips for other fonts.
        let targetNamingAxisTags = AxisOrderRealigner.canonicalAxisTagOrder(
            namingOrder: treeOrder + namingAxisTags,
            fontAxisTags: Array(projectAxisTags)
        )
        let namingChanged = namingAxisTags != targetNamingAxisTags
        if namingChanged {
            openProjects[pIdx].document.naming.order = AxisOrderRealigner.permuteNamingAxisTags(
                openProjects[pIdx].document.naming.order,
                axisTags: projectAxisTags,
                toAxisTagOrder: targetNamingAxisTags
            )
        }

        let namingOrder = openProjects[pIdx].document.naming.order
        var fontsChanged = false
        for fontIndex in openProjects[pIdx].document.fonts.indices {
            var font = openProjects[pIdx].document.fonts[fontIndex]
            let beforeAxes = font.axes.map(\.tag)
            let beforeDesign = font.statDesignAxisTags
            let beforeCompounds = font.compoundStatValues
            let fontCanonical = font.id == authority.id
                ? AxisOrderRealigner.canonicalAxisTagOrder(
                    namingOrder: treeOrder,
                    fontAxisTags: font.axes.map(\.tag)
                )
                : AxisOrderRealigner.canonicalAxisTagOrder(
                    namingOrder: namingOrder,
                    fontAxisTags: font.axes.map(\.tag)
                )
            AxisOrderRealigner.applyCanonicalOrder(to: &font, canonicalOrder: fontCanonical)
            let changed =
                beforeAxes != font.axes.map(\.tag)
                || beforeDesign != font.statDesignAxisTags
                || beforeCompounds != font.compoundStatValues
            if changed {
                fontsChanged = true
                if markProjectDirtyIfChanged {
                    font.dirty = true
                }
                openProjects[pIdx].document.fonts[fontIndex] = font
            }
        }

        let changed = namingChanged || fontsChanged
        guard changed else { return false }

        openProjects[pIdx].document.modified = Date()
        if markProjectDirtyIfChanged {
            markProjectFileDirty(projectID: projectID)
        }
        publishOpenProjects()
        regeneratePlan()
        resortIncludedInstanceKeys(forProjectID: projectID)
        refreshCanSave()
        return true
    }

    private func axisTagSubsequence(from namingOrder: [String], axisTags: [String]) -> [String] {
        let tagSet = Set(axisTags)
        return namingOrder.filter { tagSet.contains($0) }
    }
}
