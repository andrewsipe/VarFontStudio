import AppKit
import SwiftUI
import VarFontCore

// MARK: - Inspector components

struct StudioInspectorBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            StudioSectionLabel(title: title)
            content
        }
    }
}


struct StudioInspectorConflictBadge: View {
    let count: Int
    var action: (() -> Void)?

    var body: some View {
        let label = Text("\(count) conflict\(count == 1 ? "" : "s")")
            .font(StudioTypography.caption.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(StudioColors.warningFill, in: Capsule())

        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .capsule)
                .help("Show conflict details")
        } else {
            label
        }
    }
}

struct StudioComposedNameCallout: View {
    let name: String
    var isDuplicate: Bool = false

    var body: some View {
        Text(name)
            .font(.system(size: 15, weight: .semibold))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            // Duplicate: keep a quiet leading mark only — full amber wash is reserved for
            // actionable banners / fix loci, not every affected name callout.
            .background(
                StudioColors.selectionFill.opacity(0.35),
                in: RoundedRectangle(cornerRadius: StudioRadius.row)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDuplicate ? StudioColors.warningForeground : StudioColors.brand)
                    .frame(width: 3)
            }
    }
}

struct StudioInstanceComposedName: View {
    let links: [NamingChainLink]
    let fallback: String
    var included: Bool = true
    var hideElided: Bool = false

    private var displayLinks: [NamingChainLink] {
        hideElided ? links.filter { !$0.elided } : links
    }

    private var showsCollapsedElidedFallback: Bool {
        hideElided && !links.isEmpty && displayLinks.isEmpty
    }

    var body: some View {
        Group {
            if links.isEmpty {
                Text(fallback)
                    .foregroundStyle(included ? .primary : .secondary)
            } else if showsCollapsedElidedFallback {
                Text(fallback)
                    .foregroundStyle(included ? .primary : .secondary)
            } else {
                composedText(from: displayLinks)
            }
        }
        .font(StudioTypography.bodyMedium)
        .lineLimit(1)
        .help(showsCollapsedElidedFallback ? "Elided fallback — all elidable segments hidden" : "")
    }

    private func composedText(from segments: [NamingChainLink]) -> Text {
        segments.enumerated().reduce(Text("")) { partial, item in
            let (index, link) = item
            var result = partial
            if index > 0 {
                result = result + Text(" ")
            }
            var segment = Text(link.name)
                .foregroundStyle(segmentColor(for: link))
            if link.elided {
                segment = segment.strikethrough(true, color: .secondary)
            }
            return result + segment
        }
    }

    private func segmentColor(for link: NamingChainLink) -> Color {
        if link.elided { return StudioColors.mutedForeground }
        return included ? Color.primary : Color.secondary
    }
}

struct InspectorInstanceNamingChain: View {
    let links: [NamingChainLink]
    var onLinkTap: ((String) -> Void)?

    var body: some View {
        if links.isEmpty {
            Text("No naming chain entries")
                .font(StudioTypography.caption)
                .foregroundStyle(.tertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                        if index > 0 {
                            namingArrow
                        }
                        namingSegment(link)
                    }
                }
            }
        }
    }

    private var namingArrow: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(StudioColors.brand.opacity(0.3))
                .frame(width: 8, height: 1.5)
            Image(systemName: "chevron.right")
                .font(.system(size: 7, weight: .light))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func namingSegment(_ link: NamingChainLink) -> some View {
        Group {
            if link.kind == .clarifier {
                HStack(spacing: 5) {
                    StudioClarifierPill(
                        label: link.name,
                        showCategory: NamingToken.clarifierDisplayName[link.tag] ?? link.tag,
                        compact: true
                    )
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            } else if link.kind == .code {
                Text(link.name)
                    .font(StudioTypography.monoMeta.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(StudioColors.codeBackground, in: RoundedRectangle(cornerRadius: StudioRadius.chip))
            } else if link.kind == .compound {
                HStack(spacing: 5) {
                    Text("F4")
                        .font(StudioTypography.caption.weight(.semibold))
                        .foregroundStyle(StudioColors.statFormat1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(StudioColors.statFormat1.opacity(0.16), in: Capsule())
                    Text(link.tag)
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(.secondary)
                        .opacity(link.elided ? 0.55 : 1)
                    Text(link.name)
                        .font(StudioTypography.bodyMedium)
                        .foregroundStyle(segmentForeground(for: link))
                        .strikethrough(link.elided, color: Color.secondary.opacity(0.45))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            } else {
                Button {
                    onLinkTap?(link.tag)
                } label: {
                    HStack(spacing: 5) {
                        StudioTagPill(
                            text: link.tag,
                            compact: true,
                            role: link.kind == .registration ? .registration : .instance
                        )
                            .opacity(link.elided ? 0.55 : 1)

                        Text(link.name)
                            .font(StudioTypography.bodyMedium)
                            .foregroundStyle(segmentForeground(for: link))
                            .strikethrough(link.elided, color: Color.secondary.opacity(0.45))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.chip), isEnabled: onLinkTap != nil)
            }
        }
    }

    private func segmentForeground(for link: NamingChainLink) -> Color {
        link.elided ? StudioColors.mutedForeground : Color.primary
    }
}

/// Inspector axis-coordinate list columns (on-lattice).
/// `elisionWidth` fits the spelled-out “Elidable” header — wider than stop-table “Elided”.
enum InspectorAxisCoordLayout {
    static let badgeWidth: CGFloat = 34
    static let chainWidth: CGFloat = StudioSpace.x3 // 12
    static let valueWidth: CGFloat = 44
    static let elisionWidth: CGFloat = 52
}

struct InspectorAxisCoordinatesView: View {
    let rows: [InspectorAxisCoordRow]
    var selectedStopID: String?
    var onRowTap: ((InspectorAxisCoordRow) -> Void)?
    var onElisionToggle: ((InspectorAxisCoordRow) -> Void)?

    private var showsElisionColumn: Bool {
        rows.contains(where: \.showsElisionToggle)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                axisCoordRow(
                    row,
                    isFirst: index == 0,
                    isLast: index == rows.count - 1,
                    linkActiveToNext: chainLinkActive(at: index)
                )
            }
        }
    }

    private func chainLinkActive(at index: Int) -> Bool {
        guard index + 1 < rows.count else { return false }
        return rows[index].participatesInNaming && rows[index + 1].participatesInNaming
    }

    private func axisCoordRow(
        _ row: InspectorAxisCoordRow,
        isFirst: Bool,
        isLast: Bool,
        linkActiveToNext: Bool
    ) -> some View {
        InspectorAxisCoordRowView(
            row: row,
            isFirst: isFirst,
            isLast: isLast,
            linkActiveToNext: linkActiveToNext,
            isSelected: row.stopID == selectedStopID,
            showsElisionColumn: showsElisionColumn,
            onRowTap: onRowTap,
            onElisionToggle: onElisionToggle
        )
    }
}

private struct InspectorAxisCoordRowView: View {
    let row: InspectorAxisCoordRow
    let isFirst: Bool
    let isLast: Bool
    let linkActiveToNext: Bool
    let isSelected: Bool
    let showsElisionColumn: Bool
    var onRowTap: ((InspectorAxisCoordRow) -> Void)?
    var onElisionToggle: ((InspectorAxisCoordRow) -> Void)?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            Button {
                onRowTap?(row)
            } label: {
                HStack(spacing: StudioSpacing.controlGap) {
                    chainRail
                        .frame(width: InspectorAxisCoordLayout.chainWidth)

                    StudioAxisValueLabel(
                        text: StudioFormatting.axisValue(row.value),
                        muted: !row.participatesInNaming
                    )
                    .frame(width: InspectorAxisCoordLayout.valueWidth, alignment: .trailing)

                    StudioTagPill(text: row.tag, compact: true)
                        .opacity(row.participatesInNaming ? 1 : 0.5)
                        .frame(width: InspectorAxisCoordLayout.badgeWidth, alignment: .center)

                    Text(row.stopName)
                        .font(StudioTypography.body)
                        .foregroundStyle(nameColor)
                        .strikethrough(row.isElided, color: Color.secondary.opacity(0.45))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .frame(minHeight: StudioFieldMetrics.listRowMinHeight)
                .background {
                    StudioRowBackground(
                        isSelected: isSelected,
                        isHovered: isHovered && !isSelected
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(onRowTap == nil || row.stopID == nil)
            .onHover { isHovered = $0 }

            if showsElisionColumn {
                Group {
                    if row.showsElisionToggle {
                        StudioElidableRadio(isOn: row.isElided) {
                            onElisionToggle?(row)
                        }
                    }
                }
                .frame(width: InspectorAxisCoordLayout.elisionWidth, alignment: .center)
            }
        }
        .help(row.participatesInNaming
            ? (row.isElided ? "Elided from composed name — focus axis stop" : "Focus this axis stop")
            : "Not in the instance naming grid")
    }

    private var nameColor: Color {
        if !row.participatesInNaming { return Color.secondary }
        if row.isElided { return StudioColors.mutedForeground }
        return Color.primary
    }

    @ViewBuilder
    private var chainRail: some View {
        let dotColor: Color = {
            if isSelected { return StudioColors.brand }
            if row.participatesInNaming && !row.isElided { return StudioColors.registrationForeground }
            if row.isElided { return .secondary.opacity(0.35) }
            return .secondary.opacity(0.25)
        }()

        VStack(spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .frame(height: 6)
            }

            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            if !isLast {
                Rectangle()
                    .fill(linkActiveToNext ? StudioColors.brand.opacity(0.3) : Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct InspectorOpenTypeSourcePill: View {
    let source: InspectorOpenTypeSource

    var body: some View {
        Text(source.rawValue.uppercased())
            .font(StudioTypography.filterBadgeLabel)
            .tracking(0.3)
            .foregroundStyle(.primary)
            .padding(.horizontal, StudioSpacing.tagHorizontalInset)
            .padding(.vertical, StudioSpace.x0_5)
            .background(fill, in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(stroke, lineWidth: StudioStroke.hairline)
            }
    }

    private var fill: Color {
        switch source {
        case .stat: return StudioColors.registrationBackground
        case .fvar: return StudioColors.brand.opacity(0.16)
        case .name: return StudioColors.codeBackground
        case .planned: return StudioColors.pendingFill
        }
    }

    private var stroke: Color {
        switch source {
        case .stat: return StudioColors.registrationStroke
        case .fvar: return StudioColors.brand.opacity(0.35)
        case .name: return StudioColors.codeStroke
        case .planned: return StudioColors.pendingForeground.opacity(0.45)
        }
    }
}

struct InspectorOpenTypeTable: View {
    let rows: [InspectorOpenTypeRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Field")
                    .frame(width: SaveReviewLayout.fieldColumnWidth * 0.55, alignment: .leading)
                Text("ID")
                    .frame(width: SaveReviewLayout.nameIDColumnWidth, alignment: .trailing)
                    .padding(.leading, SaveReviewLayout.nameIDColumnLeadingGap)
                    .padding(.trailing, SaveReviewLayout.nameIDColumnTrailingGap)
                Text("Content")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(StudioTypography.columnLabel)
            .foregroundStyle(StudioColors.sectionHeading)
            .padding(.bottom, StudioSpace.x1)

            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    VStack(alignment: .leading, spacing: StudioSpace.x0_5) {
                        Text(row.field)
                            .font(StudioTypography.bodyMedium)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(row.table)
                            .font(StudioTypography.monoValue)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: SaveReviewLayout.fieldColumnWidth * 0.55, alignment: .leading)
                    .layoutPriority(1)

                    Group {
                        if let nameID = row.nameID {
                            Text("\(nameID)")
                                .font(StudioTypography.rowNameMono.weight(.medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                        } else {
                            Text("—")
                                .font(StudioTypography.caption)
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .frame(width: SaveReviewLayout.nameIDColumnWidth, alignment: .trailing)
                    .padding(.leading, SaveReviewLayout.nameIDColumnLeadingGap)
                    .padding(.trailing, SaveReviewLayout.nameIDColumnTrailingGap)
                    .layoutPriority(2)

                    VStack(alignment: .leading, spacing: StudioSpace.x1) {
                        Text(row.content)
                            .font(StudioTypography.monoValue)
                            .foregroundStyle(row.isDerived ? .secondary : .primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        if !row.sources.isEmpty {
                            HStack(spacing: StudioSpace.x1) {
                                ForEach(row.sources, id: \.rawValue) { source in
                                    InspectorOpenTypeSourcePill(source: source)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, StudioSpace.x2)

                if row.id != rows.last?.id {
                    Rectangle()
                        .fill(StudioColors.surfaceStroke)
                        .frame(height: StudioStroke.hairline)
                }
            }
        }
    }
}
