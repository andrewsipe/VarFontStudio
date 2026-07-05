import SwiftUI
import VarFontCore

struct PlanIssueResolverSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let warning: PlanWarning
    let reviewPosition: Int?
    let reviewTotal: Int?

    @State private var selectedProposalID: String = ""

    private var proposals: [PlanIssueProposal] {
        editor.planIssueProposals(for: warning)
    }

    private var selectedProposal: PlanIssueProposal? {
        proposals.first { $0.id == selectedProposalID }
    }

    private var showsContinue: Bool {
        reviewPosition != nil && reviewTotal != nil && (reviewTotal ?? 0) > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sheetSectionSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan issue")
                    .font(StudioTypography.emphasis)
                if let reviewPosition, let reviewTotal {
                    Text("Issue \(reviewPosition) of \(reviewTotal)")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                Text(warning.message)
                    .font(StudioTypography.body)
                if let hint = warning.hint {
                    Text(hint)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                Text("Choose a fix")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)

                ForEach(proposals) { proposal in
                    proposalRow(proposal)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    editor.dismissPlanIssueResolver()
                    dismiss()
                }
                if showsContinue {
                    Button("Apply & continue") {
                        applySelected(andContinue: true)
                    }
                    .disabled(selectedProposal == nil)
                }
                Button("Apply") {
                    applySelected(andContinue: false)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProposal == nil)
            }
        }
        .padding(StudioSpacing.sheetOuterPadding)
        .frame(minWidth: 420)
        .onAppear {
            if let recommended = proposals.first(where: \.isRecommended) {
                selectedProposalID = recommended.id
            } else {
                selectedProposalID = proposals.first?.id ?? ""
            }
        }
    }

    private func applySelected(andContinue: Bool) {
        guard let proposal = selectedProposal else { return }
        editor.applyPlanIssueFix(proposal.action, andContinue: andContinue)
        if !andContinue {
            dismiss()
        }
    }

    private func proposalRow(_ proposal: PlanIssueProposal) -> some View {
        Button {
            selectedProposalID = proposal.id
        } label: {
            HStack(alignment: .top, spacing: StudioSpacing.controlGap) {
                Image(systemName: selectedProposalID == proposal.id ? "largecircle.fill.circle" : "circle")
                    .font(StudioTypography.caption)
                    .foregroundStyle(selectedProposalID == proposal.id ? Color.accentColor : .secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(proposal.title)
                            .font(StudioTypography.bodyMedium)
                            .foregroundStyle(.primary)
                        if proposal.isRecommended {
                            Text("Recommended")
                                .font(StudioTypography.meta)
                                .foregroundStyle(StudioColors.registrationForeground)
                        }
                    }
                    Text(proposal.detail)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            selectedProposalID == proposal.id ? StudioColors.surfaceMuted : Color.clear,
            in: RoundedRectangle(cornerRadius: StudioRadius.row)
        )
    }
}
