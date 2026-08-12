import AppKit
import SwiftUI
import VarFontCore

// MARK: - Shared window layouts (Save Review + Instancer)

enum SaveReviewLayout {
    static let horizontalPadding: CGFloat = StudioSpacing.contentInset
    static let summaryCardGap: CGFloat = StudioSpace.x2 // 8
    static let chromeSectionGap: CGFloat = StudioSpace.x3 // 12
    static let filterBadgeGap: CGFloat = StudioSpace.x1_5 // 6
    /// nameID slot column (right-aligned digits) — sits between field label and value.
    static let nameIDColumnWidth: CGFloat = 36
    /// Gap between field-label column and nameID.
    static let nameIDColumnLeadingGap: CGFloat = StudioSpace.x2 // 8
    /// Gap between nameID and value column.
    static let nameIDColumnTrailingGap: CGFloat = StudioSpace.x2 // 8
    /// Field label column — human row identifier (+ optional detail line).
    static let fieldColumnWidth: CGFloat = 200
    static let rowVerticalPadding: CGFloat = StudioSpace.x2 // 8
    /// Search row + tab headline band (shared so those toolbars stay the same height).
    static let toolRowMinHeight: CGFloat = StudioSpace.x9 // 36
    static let toolRowVerticalPadding: CGFloat = StudioSpace.x1_5 // 6
    static let gutterWidth: CGFloat = 3
    static let gutterLeadingPadding: CGFloat = StudioSpacing.contentInset
    static let gutterTrailingPadding: CGFloat = StudioSpacing.contentInset

    /// Sticky section band in the diff table — opaque so pinned headers fully
    /// cover scrolling rows (translucent `surfaceMuted` let content bleed through).
    static let phaseHeaderBackground = StudioColors.stickyHeaderFill
    /// Search / filter tool row — same opaque bake as pinned phase headers.
    static let toolRowBackground = StudioColors.stickyHeaderFill
}

/// Spacing tokens for the Instancer window — shares Review density where chrome matches.
enum InstancerLayout {
    static let horizontalPadding: CGFloat = SaveReviewLayout.horizontalPadding
    static let chromeSectionGap: CGFloat = SaveReviewLayout.chromeSectionGap
    static let filterBadgeGap: CGFloat = SaveReviewLayout.filterBadgeGap
    static let toolRowMinHeight: CGFloat = SaveReviewLayout.toolRowMinHeight
    static let toolRowVerticalPadding: CGFloat = SaveReviewLayout.toolRowVerticalPadding
    static let toolRowBackground = SaveReviewLayout.toolRowBackground
    static let statusBarHeight: CGFloat = StudioSpace.x7 // 28
    static let searchFieldWidth: CGFloat = 180

    /// Checkbox / progress column.
    static let selectColumnWidth: CGFloat = StudioIncludeCheckbox.hitSize
    /// Same track as Axis Tree Value — fits typical axis coords (e.g. 1000, 112.5).
    static let axisColumnWidth: CGFloat = StopTableLayout.valueColumnWidth
    /// Fits “Bold Italic” in caption.
    static let styleColumnWidth: CGFloat = 80
    /// Uniform gap between fixed columns (select, name, axes…).
    static let columnGap: CGFloat = StudioSpace.x2_5 // 10
    /// Extra lead into left-aligned text columns after numeric axes (matches Axis Tree `nameGap`).
    static let textColumnLeadingGap: CGFloat = StopTableLayout.nameGap
    static let flagColumnWidth: CGFloat = 140
    static let nameColumnMinWidth: CGFloat = 160
    static let outputColumnMinWidth: CGFloat = 200

    /// Shared Name / Output widths — both flex with the window; axes + Style stay fixed.
    struct ColumnWidths: Equatable {
        var name: CGFloat
        var output: CGFloat
    }

    static func columnWidths(totalWidth: CGFloat, axisCount: Int) -> ColumnWidths {
        let axes = max(axisCount, 0)
        let axisBlock = CGFloat(axes) * axisColumnWidth
        let axisGaps = CGFloat(max(axes - 1, 0)) * columnGap
        // Gaps: select→name, name→axes, axes→style (text lead), style→output (text lead), output→flags
        let fixed =
            horizontalPadding * 2
            + selectColumnWidth
            + axisBlock
            + axisGaps
            + styleColumnWidth
            + flagColumnWidth
            + columnGap * 3
            + textColumnLeadingGap * 2
        let flex = max(nameColumnMinWidth + outputColumnMinWidth, totalWidth - fixed)
        // Name ~42%, Output the rest — both grow on wide windows (no hard name cap).
        let name = max(nameColumnMinWidth, flex * 0.42)
        let output = max(outputColumnMinWidth, flex - name)
        return ColumnWidths(name: name, output: output)
    }
}
