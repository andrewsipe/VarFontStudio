import SwiftUI
import VarFontCore

private enum FvarStatConflictChoice: Equatable {
    case keepSTAT
    case takeFvar
    case custom
}

struct FvarStatConflictResolverSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let conflict: FvarStopSeeder.NameConflict
    let reviewPosition: Int?
    let reviewTotal: Int?

    @State private var choice: FvarStatConflictChoice = .keepSTAT
    @State private var customName = ""

    private var showsContinue: Bool {
        reviewPosition != nil && reviewTotal != nil && (reviewTotal ?? 0) > 1
    }

    private var resolvedCustomName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canApply: Bool {
        switch choice {
        case .keepSTAT, .takeFvar:
            return true
        case .custom:
            return !resolvedCustomName.isEmpty
        }
    }

    private var resolution: FvarStopSeeder.Resolution {
        switch choice {
        case .keepSTAT: return .keepSTAT
        case .takeFvar: return .takeFvar
        case .custom: return .custom(resolvedCustomName)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sheetSectionSpacing) {
            header
            summary
            choices
            if !conflict.sampleInstanceNames.isEmpty {
                samples
            }
            actionBar
        }
        .padding(StudioSpacing.contentInset)
        .frame(minWidth: 460)
        .onAppear {
            choice = .keepSTAT
            customName = conflict.fvarName
        }
        .onChange(of: conflict.id) { _, _ in
            choice = .keepSTAT
            customName = conflict.fvarName
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text("STAT / fvar name conflict")
                .font(StudioTypography.emphasis)
            if let reviewPosition, let reviewTotal {
                Text("Conflict \(reviewPosition) of \(reviewTotal)")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            Text("Axis \(conflict.axisLabel) (\(conflict.axisTag)) at \(AxisCoordinateFormat.format(conflict.value)) has different names in STAT and fvar.")
                .font(StudioTypography.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: StudioSpacing.controlGap) {
                labelChip(title: "STAT", value: conflict.existingName)
                labelChip(title: "fvar", value: conflict.fvarName)
            }
        }
    }

    private func labelChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text(title)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(StudioTypography.body)
                .foregroundStyle(StudioColors.warningOnFillForeground)
                .padding(.horizontal, StudioSpacing.tightGap)
                .padding(.vertical, StudioSpacing.instanceRowGap)
                .background(StudioColors.warningFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            choiceRow(
                title: "Keep STAT name",
                detail: "Leave “\(conflict.existingName)” unchanged.",
                selected: choice == .keepSTAT,
                recommended: true
            ) {
                choice = .keepSTAT
            }
            choiceRow(
                title: "Use fvar name",
                detail: "Rename stop to “\(conflict.fvarName)”.",
                selected: choice == .takeFvar,
                recommended: false
            ) {
                choice = .takeFvar
            }
            VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                choiceRow(
                    title: "Custom name",
                    detail: "Enter a different stop label.",
                    selected: choice == .custom,
                    recommended: false
                ) {
                    choice = .custom
                }
                if choice == .custom {
                    TextField("Stop name", text: $customName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                }
            }
        }
    }

    private func choiceRow(
        title: String,
        detail: String,
        selected: Bool,
        recommended: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: StudioSpacing.controlGap) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? StudioColors.brand : .secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                    HStack(spacing: StudioSpacing.tightGap) {
                        Text(title)
                            .font(StudioTypography.body)
                        if recommended {
                            Text("Recommended")
                                .font(StudioTypography.caption)
                                .foregroundStyle(StudioColors.brand)
                        }
                    }
                    Text(detail)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioSpacing.panelVertical)
        .background {
            StudioRowBackground(isSelected: selected, isHovered: false)
        }
    }

    private var samples: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text("From fvar instances")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
            Text(conflict.sampleInstanceNames.joined(separator: ", "))
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionBar: some View {
        HStack {
            StudioFlatButton(title: "Skip remaining") {
                editor.dismissFvarStatConflictResolver()
                dismiss()
            }
            Spacer()
            if showsContinue {
                StudioFlatButton(title: "Apply and continue", isEnabled: canApply) {
                    apply(andContinue: true)
                }
            }
            StudioFlatButton(
                title: showsContinue ? "Apply" : "Done",
                role: .primary,
                isEnabled: canApply,
                isDefaultAction: true
            ) {
                apply(andContinue: false)
            }
        }
    }

    private func apply(andContinue: Bool) {
        guard canApply else { return }
        editor.applyFvarStatConflictResolution(resolution, andContinue: andContinue)
        if !andContinue {
            dismiss()
        }
    }
}
