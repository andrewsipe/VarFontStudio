import AppKit
import SwiftUI
import VarFontCore

// MARK: - Save Review components

extension SaveReviewDisplayCategory {
    var pillStyle: StudioDiffPillStyle {
        switch self {
        case .same: .unchanged
        case .protected: .protected
        case .reflow: .reflowed
        case .renamed: .changed
        case .added: .added
        case .removed: .removed
        }
    }
}

struct StudioFilterBadge: View {
    let title: String
    let count: Int
    var fill: Color
    var border: Color
    var labelColor: Color = .primary
    var markColor: Color? = nil
    var isHidden: Bool
    var isIsolated: Bool
    let action: (_ commandClick: Bool) -> Void
    @State private var isHovered = false

    init(
        title: String,
        count: Int,
        fill: Color,
        border: Color,
        labelColor: Color = .primary,
        markColor: Color? = nil,
        isHidden: Bool,
        isIsolated: Bool,
        action: @escaping (_ commandClick: Bool) -> Void
    ) {
        self.title = title
        self.count = count
        self.fill = fill
        self.border = border
        self.labelColor = labelColor
        self.markColor = markColor
        self.isHidden = isHidden
        self.isIsolated = isIsolated
        self.action = action
    }

    init(
        category: SaveReviewDisplayCategory,
        count: Int,
        isHidden: Bool,
        isIsolated: Bool,
        action: @escaping (_ commandClick: Bool) -> Void
    ) {
        self.init(
            title: category.filterLabel,
            count: count,
            fill: category.pillStyle.background,
            border: isIsolated ? Color.primary.opacity(0.35) : category.pillStyle.stroke,
            labelColor: StudioColors.chipLabel,
            isHidden: isHidden,
            isIsolated: isIsolated,
            action: action
        )
    }

    var body: some View {
        Button {
            action(NSEvent.modifierFlags.contains(.command))
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                if let markColor {
                    Text("◆")
                        .font(StudioTypography.filterBadgeLabel)
                        .foregroundStyle(isHidden ? AnyShapeStyle(.tertiary) : AnyShapeStyle(markColor))
                }
                Text("\(title.uppercased()) \(count)")
                    .font(StudioTypography.filterBadgeLabel)
                    .tracking(0.3)
            }
            .foregroundStyle(isHidden ? AnyShapeStyle(.tertiary) : AnyShapeStyle(labelColor))
            .padding(.horizontal, StudioSpacing.pillHorizontalInset)
            .padding(.vertical, StudioSpacing.instanceRowVertical)
            .background {
                ZStack {
                    if !isHidden {
                        RoundedRectangle.studio(StudioRadius.chip)
                            .fill(fill)
                    }
                    if isHovered, !isHidden, !isIsolated {
                        RoundedRectangle.studio(StudioRadius.chip)
                            .fill(StudioColors.hoverFill)
                    }
                }
            }
            .overlay {
                RoundedRectangle.studio(StudioRadius.chip)
                    .strokeBorder(
                        isHidden ? Color.clear : border,
                        lineWidth: isIsolated ? 1 : 0.5
                    )
            }
            .opacity(isHidden ? 0.32 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct StudioSaveReviewTabBar: View {
    let tabs: [SaveReviewTabPresentation]
    @Binding var selectedTab: SaveReviewTableTab

    var body: some View {
        HStack(spacing: StudioCompactControlChrome.trayInset) {
            ForEach(tabs, id: \.tabID) { tab in
                let hasChanges = tab.changedCount > 0
                StudioSegmentButton(
                    title: tab.label,
                    isSelected: selectedTab == tab.id,
                    expands: true,
                    font: StudioTypography.bodyMedium,
                    badge: "\(tab.changedCount) of \(tab.totalCount)",
                    badgeEmphasis: hasChanges ? .warning : .muted
                ) {
                    selectedTab = tab.id
                }
            }
        }
        .padding(StudioCompactControlChrome.trayInset)
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.control))
    }
}

struct StudioSaveReviewPhaseHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(StudioTypography.sectionLabel)
            .tracking(0.5)
            .foregroundStyle(StudioColors.sectionHeading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SaveReviewLayout.horizontalPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(SaveReviewLayout.phaseHeaderBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(StudioColors.surfaceStroke)
                    .frame(height: 0.5)
            }
            .zIndex(1)
    }
}

struct StudioSaveReviewCategoryTag: View {
    let category: SaveReviewDisplayCategory

    var body: some View {
        Text(category.filterLabel.uppercased())
            .font(StudioTypography.filterBadgeLabel)
            .tracking(0.3)
            .foregroundStyle(StudioColors.chipLabel)
            .padding(.horizontal, StudioSpacing.tagHorizontalInset)
            .padding(.vertical, StudioSpace.x0_5)
            .background(category.pillStyle.background, in: RoundedRectangle.studio(StudioRadius.chip))
            .overlay {
                RoundedRectangle.studio(StudioRadius.chip)
                    .strokeBorder(category.pillStyle.stroke, lineWidth: 0.5)
            }
    }
}

struct StudioSaveReviewColumnHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Field")
                .frame(width: SaveReviewLayout.fieldColumnWidth, alignment: .leading)
                .layoutPriority(1)

            Text("Name ID")
                .frame(width: SaveReviewLayout.nameIDColumnWidth, alignment: .trailing)
                .padding(.leading, SaveReviewLayout.nameIDColumnLeadingGap)
                .layoutPriority(2)
                .help("OpenType name table ID (≥256 for STAT / fvar labels)")

            Text("|")
                .foregroundStyle(StudioColors.mutedForeground)
                .frame(width: SaveReviewLayout.nameIDColumnTrailingGap, alignment: .center)

            Text("Change")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(StudioTypography.sectionLabel)
        .tracking(0.4)
        .foregroundStyle(StudioColors.sectionHeading)
        .textCase(.uppercase)
        .padding(.leading, SaveReviewLayout.gutterLeadingPadding + SaveReviewLayout.gutterWidth + SaveReviewLayout.gutterTrailingPadding)
        .padding(.trailing, SaveReviewLayout.horizontalPadding)
        .padding(.vertical, StudioSpace.x1_5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SaveReviewLayout.toolRowBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioColors.surfaceStroke)
                .frame(height: 0.5)
        }
    }
}

struct StudioStreamlinedDiffRow: View {
    let row: SaveReviewRowPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.fieldTitle)
                    .font(Self.fieldTitleFont(row.fieldTitle))
                    .lineLimit(2)
                if !row.fieldSubtitle.isEmpty {
                    Text(row.fieldSubtitle)
                        .font(Self.fieldDetailFont(row.fieldSubtitle))
                        .foregroundStyle(StudioColors.mutedForeground)
                        .lineLimit(2)
                }
            }
            .frame(width: SaveReviewLayout.fieldColumnWidth, alignment: .topLeading)
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
            .frame(width: SaveReviewLayout.nameIDColumnWidth, alignment: .topTrailing)
            .padding(.leading, SaveReviewLayout.nameIDColumnLeadingGap)
            .padding(.trailing, SaveReviewLayout.nameIDColumnTrailingGap)
            .layoutPriority(2)

            VStack(alignment: .leading, spacing: 3) {
                if let afterValue = row.afterValue, !afterValue.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        StudioSaveReviewCategoryTag(category: row.category)
                        Text(afterValue)
                            .font(StudioTypography.monoValue)
                            .foregroundStyle(valueColor)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if let conflictHint = row.conflictHint {
                            StudioWarningBadge(help: conflictHint)
                        }
                    }
                    if let secondaryLine {
                        Text(secondaryLine)
                            .font(row.noteLine != nil && row.wasLine == nil ? StudioTypography.caption : StudioTypography.monoValue)
                            .foregroundStyle(StudioColors.mutedForeground)
                            .italic(row.noteLine != nil && row.wasLine == nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if row.category == .removed {
                    // Keep removed rows to one value line: badge + was-text (no orphan "—").
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        StudioSaveReviewCategoryTag(category: row.category)
                        Text(row.wasLine ?? "—")
                            .font(StudioTypography.monoValue)
                            .foregroundStyle(StudioColors.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let note = row.noteLine, !note.isEmpty {
                        Text(note)
                            .font(StudioTypography.caption)
                            .foregroundStyle(StudioColors.mutedForeground)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let secondaryLine {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        StudioSaveReviewCategoryTag(category: row.category)
                        Text(secondaryLine)
                            .font(StudioTypography.monoValue)
                            .foregroundStyle(StudioColors.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    StudioSaveReviewCategoryTag(category: row.category)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.leading, SaveReviewLayout.gutterLeadingPadding + SaveReviewLayout.gutterWidth + SaveReviewLayout.gutterTrailingPadding)
        .padding(.vertical, SaveReviewLayout.rowVerticalPadding)
        .padding(.trailing, SaveReviewLayout.horizontalPadding)
        // Gutter as overlay so it cannot expand row height (LazyVStack + maxHeight:.infinity did).
        .overlay(alignment: .leading) {
            RoundedRectangle.studio(StudioRadius.hairline)
                .fill(gutterColor)
                .frame(width: SaveReviewLayout.gutterWidth)
                .padding(.leading, SaveReviewLayout.gutterLeadingPadding)
                .padding(.vertical, SaveReviewLayout.rowVerticalPadding)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(StudioColors.surfaceStroke)
                .frame(height: 0.5)
                .padding(.leading, SaveReviewLayout.horizontalPadding)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Row identifier when it is a file-native key (e.g. `wgth = 400`).
    private static func fieldTitleFont(_ title: String) -> Font {
        if title.range(of: #"^[a-zA-Z]{4} = "#, options: .regularExpression) != nil {
            return StudioTypography.rowNameMono.weight(.medium)
        }
        return StudioTypography.bodyMedium
    }

    /// Subtitle lines that carry coordinates / tags use mono; descriptive labels use sans.
    private static func fieldDetailFont(_ subtitle: String) -> Font {
        if subtitle.contains("=") || subtitle.hasPrefix("tag=") {
            return StudioTypography.monoValue
        }
        return StudioTypography.caption
    }

    /// Collapses `wasLine` + `noteLine` onto a single row so the value column
    /// never grows past badge/value + one secondary line (2 lines total).
    private var secondaryLine: String? {
        let parts = [row.wasLine, row.noteLine].compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private var gutterColor: Color {
        if row.category == .same {
            return StudioColors.surfaceStroke
        }
        return row.category.pillStyle.foreground
    }

    private var valueColor: Color {
        row.category == .same ? .secondary : .primary
    }
}
