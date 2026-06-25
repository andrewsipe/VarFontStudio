import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VarFontCore

struct NamingOrderChainFooter: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var isExpanded = true
    @State private var draggedTag: String?

    var body: some View {
        Group {
            if editor.selectedFont != nil, !editor.namingChainTags.isEmpty {
                disclosureContent
            }
        }
    }

    private var disclosureContent: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                Text("Reorder axes for composed style names. Toggle off to keep an axis in STAT only.")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                chainTrack

                HStack(spacing: StudioSpacing.rowGap) {
                    Text("Example")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)

                    Text(editor.namingChainPreviewName)
                        .font(StudioTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: StudioRadius.chip))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: StudioRadius.chip)
                                .fill(Color.accentColor.opacity(0.35))
                                .frame(width: 2)
                                .padding(.vertical, 2)
                        }

                    if editor.selectedInstance != nil {
                        Text("from selection")
                            .font(StudioTypography.meta)
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .padding(.top, StudioSpacing.rowGap)
            .padding(.bottom, StudioSpacing.toolbarVertical)
        } label: {
            HStack(spacing: StudioSpacing.controlGap) {
                Text("Naming order")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)

                if !isExpanded {
                    Text(editor.namingChainSummary)
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if !isExpanded {
                    Text(editor.namingChainPreviewName)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: 220, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, StudioSpacing.panelHorizontal + 4)
        .padding(.top, StudioSpacing.toolbarVertical)
        .padding(.bottom, isExpanded ? 0 : StudioSpacing.toolbarVertical)
    }

    private var chainTrack: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(editor.namingChainTags.enumerated()), id: \.element) { index, tag in
                    chainNode(tag: tag)
                        .opacity(draggedTag == tag ? 0.45 : 1)

                    if index < editor.namingChainTags.count - 1 {
                        chainLink(isActive: chainLinkActive(after: tag))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(.background.opacity(0.35), in: RoundedRectangle(cornerRadius: StudioRadius.row))
        .overlay {
            RoundedRectangle(cornerRadius: StudioRadius.row)
                .strokeBorder(.quaternary.opacity(0.55), lineWidth: 1)
        }
    }

    private func chainLinkActive(after tag: String) -> Bool {
        let tags = editor.namingChainTags
        guard let index = tags.firstIndex(of: tag), index + 1 < tags.count else { return false }
        return editor.axisParticipatesInInstanceGrid(tag: tag)
            && editor.axisParticipatesInInstanceGrid(tag: tags[index + 1])
    }

    private func chainLink(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.25))
            .frame(width: 14, height: 2)
            .padding(.horizontal, 1)
    }

    private func chainNode(tag: String) -> some View {
        let inGrid = editor.axisParticipatesInInstanceGrid(tag: tag)

        return HStack(spacing: 5) {
            StudioIncludeCheckbox(isOn: inGrid) {
                editor.setAxisInstanceGridEnabled(tag: tag, enabled: !inGrid)
            }

            StudioTagPill(text: tag, compact: true)

            Text(editor.axisDisplayName(for: tag))
                .font(StudioTypography.caption)
                .foregroundStyle(inGrid ? .primary : .secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            inGrid ? Color.primary.opacity(0.04) : Color.clear,
            in: RoundedRectangle(cornerRadius: StudioRadius.chip)
        )
        .overlay {
            if !inGrid {
                RoundedRectangle(cornerRadius: StudioRadius.chip)
                    .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: StudioRadius.chip))
        .onDrag {
            draggedTag = tag
            return NSItemProvider(object: tag as NSString)
        }
        .onDrop(
            of: [UTType.plainText],
            delegate: NamingChainDropDelegate(
                tag: tag,
                draggedTag: $draggedTag,
                onReorder: editor.reorderNamingChain
            )
        )
    }
}

private struct NamingChainDropDelegate: DropDelegate {
    let tag: String
    @Binding var draggedTag: String?
    let onReorder: (String, String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedTag != nil && draggedTag != tag
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedTag, dragged != tag else { return }
        onReorder(dragged, tag)
        draggedTag = dragged
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTag = nil
        return true
    }
}
