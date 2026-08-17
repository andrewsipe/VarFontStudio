import SwiftUI
import VarFontCore

/// Count + optional Snap + Format 1/2 preview for quick-filling axis stops.
///
/// Used by both the plan-issue resolver (fixing an empty instance axis) and the axis tree's
/// standalone "Fill stops…" tool. The axis tree tool can be reopened anytime to tweak a fill —
/// it replaces the axis's stops rather than requiring the axis to start empty.
struct AxisStopFillControls: View {
    let options: AxisStopFillOptions
    @Binding var stopCount: Double
    @Binding var snapOn: Bool
    @Binding var statFormat: Int

    var plan: AxisStopFillPlan {
        AxisStopFillPlanner.plan(
            options: options,
            count: Int(stopCount.rounded()),
            snap: snapOn,
            statFormat: statFormat
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            formatPicker
            countControls
            Text(caption)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            AxisStopFillPreview(plan: plan)
        }
        .onChange(of: stopCount) { _, _ in
            if snapOn, !plan.snapFits {
                snapOn = false
            }
        }
    }

    private var caption: String {
        let base = AxisStopFillPlanner.caption(for: plan)
        if plan.statFormat == 2 {
            return base + " Format 2 ranges meet at midpoints between those noms."
        }
        return base + " Format 1 writes the noms only."
    }

    private var formatPicker: some View {
        HStack(spacing: StudioSpacing.instanceRowGap) {
            StudioSegmentButton(
                title: "Format 1",
                isSelected: statFormat != 2,
                expands: true
            ) {
                statFormat = 1
            }
            StudioSegmentButton(
                title: "Format 2",
                isSelected: statFormat == 2,
                expands: true
            ) {
                statFormat = 2
            }
        }
        .padding(StudioSpace.x0_5)
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.control))
        .accessibilityLabel("STAT format")
    }

    private var countControls: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            HStack {
                Text("Stop count")
                    .font(StudioTypography.caption)
                Spacer()
                if options.typicalStep != nil {
                    snapButton
                }
                Text("\(Int(stopCount.rounded()))")
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .trailing)
            }

            Slider(
                value: $stopCount,
                in: Double(options.countRange.lowerBound)...Double(options.countRange.upperBound),
                step: 1
            )
        }
    }

    private var snapButton: some View {
        let enabled = plan.snapFits
        let step = options.typicalStep.map { AxisStopSuggestions.formatValue($0) } ?? ""
        return Button {
            snapOn.toggle()
        } label: {
            Text("Snap")
                .font(StudioTypography.caption)
                .fontWeight(snapOn ? .semibold : .regular)
                .foregroundStyle(snapOn ? Color.white : (enabled ? Color.primary : Color.secondary.opacity(0.45)))
                .padding(.horizontal, StudioSpacing.contentInset)
                .padding(.vertical, StudioSpacing.instanceRowVertical)
                .background(
                    snapOn ? StudioColors.brand : StudioColors.surfaceLight,
                    in: RoundedRectangle.studio(StudioRadius.control)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(
            enabled
                ? "Snap noms to this axis’s \(step)-unit step"
                : "Only \(plan.tickCount) ticks on this axis’s \(step)-unit step"
        )
        .studioHoverFill(
            shape: .roundedRect(cornerRadius: StudioRadius.control),
            isEnabled: enabled && !snapOn
        )
    }
}

struct AxisStopFillPreview: View {
    let plan: AxisStopFillPlan

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            HStack(spacing: StudioSpacing.controlGap) {
                header("Name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if plan.statFormat == 2 {
                    header("Min")
                        .frame(width: 44, alignment: .trailing)
                }
                header("Nom")
                    .frame(width: 44, alignment: .trailing)
                if plan.statFormat == 2 {
                    header("Max")
                        .frame(width: 44, alignment: .trailing)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: StudioSpace.x1) {
                    ForEach(plan.stops) { stop in
                        HStack(spacing: StudioSpacing.controlGap) {
                            Text(stop.name)
                                .font(StudioTypography.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if plan.statFormat == 2 {
                                mono(stop.rangeMin)
                            }
                            mono(stop.value)
                            if plan.statFormat == 2 {
                                mono(stop.rangeMax)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(StudioSpacing.contentInset)
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.control))
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(StudioTypography.columnLabel)
            .foregroundStyle(StudioColors.sectionHeading)
    }

    private func mono(_ value: Double) -> some View {
        Text(AxisStopSuggestions.formatValue(value))
            .font(StudioTypography.monoMeta)
            .foregroundStyle(.secondary)
            .frame(width: 44, alignment: .trailing)
    }
}
