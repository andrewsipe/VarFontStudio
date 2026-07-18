import SwiftUI
import VarFontCore

enum StopEditField: Equatable {
    case min
    case pin
    case max
    case code
    case name
}

struct AddAxisStopRequest: Identifiable {
    let axisTag: String
    var id: String { axisTag }
}

struct AddRegistrationAxisRequest: Identifiable {
    let id = UUID()
}

struct FillStopsRequest: Identifiable {
    let axisTag: String
    var id: String { axisTag }
}

struct StopFormatChangeRequest: Identifiable {
    let axisTag: String
    let stopID: String
    var id: String { stopID }
}

// MARK: - Axis block state spec
//
// Reachable axis-block states — check new UI against this table before bolting on another branch.
// Dimensions: lane × expanded × isDesignRecordOnly × values.isEmpty × hasConflict × hasAxisWarning × isInstanceAxis
//
// Collapsed (expanded = N): header only — subtitle always visible; table / Add Stop hidden.
//
// | Lane        | DesignRec | Empty | Inst | Header subtitle (merged)              | Table | Add Stop |
// |-------------|-----------|-------|------|---------------------------------------|-------|----------|
// | variation   | N         | N     | Y    | min – def – max                       | YES   | YES      |
// | variation   | N         | Y     | Y    | min – def – max                       | empty | YES      |
// | pinned      | N         | N     | N    | min – def – max · Pinned at X         | YES   | NO       |
// | pinned      | N         | Y     | N    | min – def – max · Pinned at X         | empty | NO       |
// | registration| Y         | N     | —    | No fvar scale · {stop}▾              | YES   | YES      |
// | registration| Y         | Y     | —    | No fvar scale · {stop?}▾             | empty | YES      |
// | registration| N         | *     | —    | No fvar scale [· {stop?}▾]           | *     | YES*     |
//
// hasConflict → warning icon + Resolve in header (all lanes). hasAxisWarning → warning icon in header;
// axis-scoped plan warnings do not repeat in the scroll banner (rollup only when 2+ axes need attention).
// Badge: highlighted count = in-grid stops (variation) or STAT values (registration); muted 0 = toggled off (pinned).

/// Plan-warning codes surfaced inline on the axis header (not repeated per-message in the scroll banner).
enum AxisTreePlanWarningCodes {
    static let axisInline: Set<String> = [
        "registration_mismatch",
        "registration_value_missing",
        "orphan_stat_link",
        "ital_value_name_mismatch",
        "ital_format1_upgrade",
        "wght_format1_upgrade",
        "fvar_missing_from_stat",
        "stat_missing_from_fvar",
        "multiple_elidable",
        "empty_instance_axis",
    ]
}

/// Vertical rhythm inside an expanded axis block — one constant per relationship.
enum AxisDetailSpacing {
    /// Design-record label row → stop table or empty-state message.
    static let metadataToTableGap: CGFloat = StudioSpacing.rowGap
    /// Column header + first data row read as one unit.
    static let tableHeaderToFirstRowGap: CGFloat = 1
    /// Last stop row → Add Stop CTA.
    static let lastStopToAddButtonGap: CGFloat = StudioSpacing.controlGap
}

// MARK: - Axis header reorder drag

struct AxisTreeAxisDragSession {
    var draggingTag: String?
    private(set) var originalTags: [String] = []
    private(set) var fromIndex: Int = 0
    var targetGapIndex: Int?
    /// Top-leading origin of the ghost in the reorder coordinate space.
    var ghostOrigin: CGPoint = .zero
    /// Pointer offset within the header when the drag began (keeps ghost under finger).
    var grabOffset: CGSize = .zero
    /// Header size captured at drag start so the ghost matches the live bar.
    var ghostSize: CGSize = .zero
    /// Header frames frozen at drag start so drop-gap insertion doesn't jitter hit-testing.
    var frozenHeaderFrames: [String: CGRect] = [:]
    /// After a completed drag, ignore the synthetic click that would toggle expansion.
    var suppressNextExpansionToggle = false

    var isDragging: Bool { draggingTag != nil }

    /// True when the pointer is over a gap that would actually move the axis.
    var showsDropGap: Bool {
        guard let gap = targetGapIndex else { return false }
        return gap != fromIndex && gap != fromIndex + 1
    }

    mutating func begin(
        tag: String,
        axisTags: [String],
        grabOffset: CGSize,
        ghostOrigin: CGPoint,
        ghostSize: CGSize,
        headerFrames: [String: CGRect]
    ) {
        draggingTag = tag
        originalTags = axisTags
        fromIndex = axisTags.firstIndex(of: tag) ?? 0
        targetGapIndex = nil
        self.grabOffset = grabOffset
        self.ghostOrigin = ghostOrigin
        self.ghostSize = ghostSize
        frozenHeaderFrames = headerFrames
        suppressNextExpansionToggle = true
    }

    mutating func updateGhost(at location: CGPoint) {
        ghostOrigin = CGPoint(
            x: location.x - grabOffset.width,
            y: location.y - grabOffset.height
        )
    }

    mutating func reset() {
        draggingTag = nil
        targetGapIndex = nil
        originalTags = []
        fromIndex = 0
        ghostOrigin = .zero
        grabOffset = .zero
        ghostSize = .zero
        frozenHeaderFrames = [:]
    }
}


// MARK: - Axis block layout

/// Shared horizontal metrics for the two-row adaptive stop table (layout K).
enum AxisBlockLayout {
    static let tagColumnWidth: CGFloat = 34
    static let tagNameSpacing: CGFloat = 8
    static let rowHorizontalPadding: CGFloat = 6

    /// Nests stop rows under the axis header without reserving remove-button space.
    static let stopIndentWidth: CGFloat = 18
    /// fvar-default marker column (square) before Fmt.
    static let defaultMarkWidth: CGFloat = 22
    /// Breathing room between the fvar-default marker and the Fmt badge.
    static let defaultMarkTrailingGap: CGFloat = 4
    static let fmtColumnWidth: CGFloat = 36
    static let valueColumnWidth: CGFloat = 52
    static let codeColumnWidth: CGFloat = 36
    static let codeGap: CGFloat = 6
    static let nameGap: CGFloat = 6
    static let elidableWidth: CGFloat = 26

    static func nameLeading(showDefaultMark: Bool, showCode: Bool = false) -> CGFloat {
        stopIndentWidth
            + (showDefaultMark ? defaultMarkWidth + defaultMarkTrailingGap : 0)
            + fmtColumnWidth
            + valueColumnWidth
            + (showCode ? codeGap + codeColumnWidth : 0)
            + nameGap
    }

    static func rangeSublineLeading(showDefaultMark: Bool, showCode: Bool = false) -> CGFloat {
        nameLeading(showDefaultMark: showDefaultMark, showCode: showCode)
    }

    static let stopCountBadgeWidth: CGFloat = 32
    static let removeButtonSize: CGFloat = StudioIncludeCheckbox.size
    /// Real reserved trailing column for the hover-remove button — small on
    /// purpose (button-sized, not a full column like Fmt/Value/Elid), but a
    /// genuine layout slot so the row's own background contains it without
    /// needing a separately hand-tuned offset to agree with it.
    static let removeSlotWidth: CGFloat = removeButtonSize + 4
    static let removeSlotLeadingGap: CGFloat = 6
}

struct AxisHeaderFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

