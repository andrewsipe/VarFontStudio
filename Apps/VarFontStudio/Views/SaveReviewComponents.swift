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
    let category: SaveReviewDisplayCategory
    let count: Int
    var isHidden: Bool
    var isIsolated: Bool
    let action: (_ commandClick: Bool) -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action(NSEvent.modifierFlags.contains(.command))
        } label: {
            Text("\(category.filterLabel.uppercased()) \(count)")
                .font(StudioTypography.filterBadgeLabel)
                .tracking(0.3)
                .foregroundStyle(isHidden ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.primary))
                .padding(.horizontal, StudioSpacing.pillHorizontalInset)
                .padding(.vertical, StudioSpacing.instanceRowVertical)
                .background {
                    ZStack {
                        if !isHidden {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(category.pillStyle.background)
                        }
                        if isHovered, !isHidden, !isIsolated {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(StudioColors.hoverFill)
                        }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isIsolated ? Color.primary.opacity(0.22) : (isHidden ? Color.clear : category.pillStyle.border),
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
        HStack(spacing: 3) {
            ForEach(tabs, id: \.tabID) { tab in
                let isSelected = selectedTab == tab.id
                let hasChanges = tab.changedCount > 0
                Button {
                    selectedTab = tab.id
                } label: {
                    HStack(spacing: 7) {
                        Text(tab.label)
                            .font(StudioTypography.bodyMedium.weight(isSelected ? .semibold : .regular))
                        Text("\(tab.changedCount) of \(tab.totalCount)")
                            .font(StudioTypography.columnLabel)
                            .monospacedDigit()
                            .foregroundStyle(
                                hasChanges
                                    ? StudioColors.warningOnFillForeground
                                    : Color.secondary.opacity(0.7)
                            )
                            .padding(.horizontal, StudioSpace.x1_5)
                            .padding(.vertical, StudioSpacing.instanceRowGap)
                            .background(
                                hasChanges ? StudioColors.warningFill : StudioColors.selectionNeutralFill,
                                in: Capsule()
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .background(
                        isSelected ? StudioColors.surfaceLight : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .shadow(color: isSelected ? StudioPalette.color(.ink, light: .s900, dark: .s900).opacity(0.2) : .clear, radius: 2, y: 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .studioHoverFill(
                    shape: .roundedRect(cornerRadius: 6),
                    isEnabled: !isSelected
                )
            }
        }
        .padding(3)
        .background(StudioColors.surfaceSubtle, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(StudioColors.surfaceStrokeStrong, lineWidth: 0.5)
        )
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
            .foregroundStyle(.primary)
            .padding(.horizontal, StudioSpacing.tagHorizontalInset)
            .padding(.vertical, StudioSpace.x0_5)
            .background(category.pillStyle.background, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(category.pillStyle.border, lineWidth: 0.5)
            }
    }
}

struct StudioStreamlinedDiffRow: View {
    let row: SaveReviewRowPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(gutterColor)
                .frame(width: SaveReviewLayout.gutterWidth)
                .padding(.leading, SaveReviewLayout.gutterLeadingPadding)
                .padding(.trailing, SaveReviewLayout.gutterTrailingPadding)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
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
                .frame(width: SaveReviewLayout.fieldColumnWidth, alignment: .leading)
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

                VStack(alignment: .leading, spacing: 3) {
                    if let afterValue = row.afterValue, !afterValue.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            StudioSaveReviewCategoryTag(category: row.category)
                            Text(afterValue)
                                .font(StudioTypography.monoValue)
                                .foregroundStyle(valueColor)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            // Trailing the composed name — same spot the Instances list marks
                            // an impacted row (statusAccessory follows the name).
                            if let conflictHint = row.conflictHint {
                                StudioWarningBadge(help: conflictHint)
                            }
                        }
                    } else if row.category == .removed {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            StudioSaveReviewCategoryTag(category: row.category)
                            Text("—")
                                .font(StudioTypography.monoValue)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if let secondaryLine {
                        Text(secondaryLine)
                            .font(row.noteLine != nil && row.wasLine == nil ? StudioTypography.caption : StudioTypography.monoValue)
                            .foregroundStyle(StudioColors.mutedForeground)
                            .italic(row.noteLine != nil && row.wasLine == nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, SaveReviewLayout.rowVerticalPadding)
        .padding(.trailing, SaveReviewLayout.horizontalPadding)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(StudioColors.surfaceStroke)
                .frame(height: 0.5)
                .padding(.leading, SaveReviewLayout.horizontalPadding)
        }
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
