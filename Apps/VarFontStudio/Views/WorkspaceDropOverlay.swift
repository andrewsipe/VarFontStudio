import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drop handling (single delegate — avoids competing onDrop targets)

struct WorkspaceDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let globalOrigin: CGPoint
    let isBusy: Bool
    let activeProjectID: String?
    let isInternalDragActive: () -> Bool
    let coordinator: WorkspaceDragCoordinator
    let onDropURLs: ([URL], WorkspaceDropTarget) -> Void

    func dropEntered(info: DropInfo) {
        guard acceptsFileDrop(info) else { return }
        isTargeted = true
        let global = globalPoint(for: info)
        let count = info.itemProviders(for: EditorViewModel.fontDropTypes).count
        coordinator.beginExternalFileDrop(fileCount: count, at: global)
        coordinator.updateExternalFileDrop(at: global, activeProjectID: activeProjectID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard acceptsFileDrop(info) else {
            return DropProposal(operation: .forbidden)
        }
        let global = globalPoint(for: info)
        coordinator.updateExternalFileDrop(at: global, activeProjectID: activeProjectID)
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        coordinator.cancelExternalFileDrop()
    }

    func validateDrop(info: DropInfo) -> Bool {
        acceptsFileDrop(info)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard acceptsFileDrop(info) else { return false }

        let global = globalPoint(for: info)
        coordinator.updateExternalFileDrop(at: global, activeProjectID: activeProjectID)
        let target = coordinator.endExternalFileDrop() ?? .newProject
        isTargeted = false

        let providers = info.itemProviders(for: EditorViewModel.fontDropTypes)
        guard !providers.isEmpty else { return false }

        Task {
            var urls: [URL] = []
            for provider in providers {
                if let url = await loadDroppedURL(from: provider) {
                    urls.append(url)
                }
            }
            guard !urls.isEmpty else { return }
            await MainActor.run {
                onDropURLs(urls, target)
            }
        }
        return true
    }

    private func globalPoint(for info: DropInfo) -> CGPoint {
        CGPoint(
            x: info.location.x + globalOrigin.x,
            y: info.location.y + globalOrigin.y
        )
    }

    private func acceptsFileDrop(_ info: DropInfo) -> Bool {
        if isBusy || isInternalDragActive() {
            return false
        }
        return !info.itemProviders(for: EditorViewModel.fontDropTypes).isEmpty
    }

    private func loadDroppedURL(from provider: NSItemProvider) async -> URL? {
        if provider.canLoadObject(ofClass: URL.self) {
            let url: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { object, _ in
                    continuation.resume(returning: object)
                }
            }
            if let url { return url }
        }

        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                          let path = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: URL(fileURLWithPath: path))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Empty workspace hint (no full-sheet overlay)

struct EmptyWorkspaceView: View {
    var isDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isDropTargeted ? "plus.circle.fill" : "arrow.down.doc")
                .font(.system(size: 36))
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                .animation(.easeOut(duration: 0.12), value: isDropTargeted)

            Text(isDropTargeted ? "Drop to open" : "Drop variable fonts to begin")
                .font(StudioTypography.emphasis)
                .foregroundStyle(isDropTargeted ? Color.accentColor : .primary)

            Text(isDropTargeted
                ? "All files land in one project"
                : "Or use File → Open Font… · TTF, OTF, WOFF, WOFF2 · folders OK")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .workspaceDropZoneHighlight(
            isActive: isDropTargeted,
            tint: StudioColors.dropNewProject
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Drop zone highlight (5% fill + 1px bottom edge)

struct WorkspaceDropZoneHighlight: ViewModifier {
    let isActive: Bool
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background {
                if isActive {
                    tint.opacity(StudioColors.dropZoneFillOpacity)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? tint : .clear)
                    .frame(height: 1)
            }
            .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

extension View {
    func workspaceDropZoneHighlight(isActive: Bool, tint: Color) -> some View {
        modifier(WorkspaceDropZoneHighlight(isActive: isActive, tint: tint))
    }
}

/// Legacy edge-only accent — prefer `workspaceDropZoneHighlight` for panels and rows.
enum WorkspaceDropEdge {
    case top
    case bottom
    case leading
    case trailing
}

struct WorkspaceDropEdgeHighlight: View {
    let isActive: Bool
    var edge: WorkspaceDropEdge = .bottom
    var tint: Color = Color.accentColor
    var thickness: CGFloat = 1

    var body: some View {
        GeometryReader { _ in
            switch edge {
            case .top:
                edgeBar(alignment: .top)
            case .bottom:
                edgeBar(alignment: .bottom)
            case .leading:
                edgeBar(alignment: .leading, isHorizontal: false)
            case .trailing:
                edgeBar(alignment: .trailing, isHorizontal: false)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: isActive)
    }

    @ViewBuilder
    private func edgeBar(alignment: Alignment, isHorizontal: Bool = true) -> some View {
        Rectangle()
            .fill(isActive ? tint.opacity(0.4) : .clear)
            .frame(
                width: isHorizontal ? nil : thickness,
                height: isHorizontal ? thickness : nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}
