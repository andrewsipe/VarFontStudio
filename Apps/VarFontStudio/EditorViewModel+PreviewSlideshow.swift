import Foundation

enum PreviewSlideshowDirection: String, Equatable {
    case up
    case down
}

enum PreviewSlideshowSpeed: Double, CaseIterable, Identifiable {
    case half = 0.5
    case one = 1
    case two = 2
    case three = 3
    case five = 5
    case ten = 10

    var id: Double { rawValue }

    /// How long to linger on each settled instance before cycling.
    /// Explicit steps so × tracks cycle rate predictably (×10 must beat ×5).
    var holdDuration: TimeInterval {
        switch self {
        case .half: 4.0
        case .one: 2.0
        case .two: 1.0
        case .three: 0.5
        case .five: 0.2
        case .ten: 0.05
        }
    }

    /// Short ease between poses. Kept well under hold at every speed so morph
    /// never becomes the bottleneck (that made ×10 feel slower than ×5).
    var morphDuration: TimeInterval {
        switch self {
        case .half, .one: 0.2
        case .two: 0.16
        case .three: 0.12
        case .five: 0.08
        case .ten: 0.04
        }
    }

    /// Skip list scroll animation while playing at faster rates.
    var prefersSmoothCycling: Bool { rawValue >= 3 }

    var label: String {
        switch self {
        case .half: "×0.5"
        case .one: "×1"
        case .two: "×2"
        case .three: "×3"
        case .five: "×5"
        case .ten: "×10"
        }
    }

    static func stored(from raw: Double) -> PreviewSlideshowSpeed {
        allCases.first { abs($0.rawValue - raw) < 0.01 } ?? .one
    }

    var next: PreviewSlideshowSpeed {
        let cases = Self.allCases
        guard let index = cases.firstIndex(of: self) else { return .one }
        return cases[(index + 1) % cases.count]
    }
}

extension EditorViewModel {
    private static let slideshowSpeedDefaultsKey = "studio.fontPreviewSlideshowSpeed"
    private static let slideshowFrameNanos: UInt64 = 16_666_667 // ~60fps

    // MARK: - Preview slideshow

    var canRunPreviewSlideshow: Bool {
        filteredInstances.count >= 2
    }

    var previewSlideshowSpeed: PreviewSlideshowSpeed {
        get {
            PreviewSlideshowSpeed.stored(
                from: UserDefaults.standard.double(forKey: Self.slideshowSpeedDefaultsKey).nonZeroOr(1)
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.slideshowSpeedDefaultsKey)
            objectWillChange.send()
            if isPreviewSlideshowPlaying {
                restartPreviewSlideshowTimer()
            }
        }
    }

    /// Instance list should not animate-scroll during fast morphing play.
    var previewSlideshowSuppressListScroll: Bool {
        isPreviewSlideshowPlaying && previewSlideshowSpeed.prefersSmoothCycling
    }

    func startPreviewSlideshow() {
        guard canRunPreviewSlideshow else {
            stopPreviewSlideshow()
            return
        }
        ensurePreviewSlideshowSelection()
        guard canRunPreviewSlideshow else { return }
        isPreviewSlideshowPlaying = true
        restartPreviewSlideshowTimer()
    }

    func stopPreviewSlideshow() {
        guard isPreviewSlideshowPlaying || previewSlideshowTask != nil else {
            isPreviewSlideshowPlaying = false
            previewInteraction.clearMorph()
            return
        }
        isPreviewSlideshowPlaying = false
        previewSlideshowTask?.cancel()
        previewSlideshowTask = nil

        let settleKey = previewInteraction.morphTargetKey
            ?? previewInteraction.hoverInstanceKey
            ?? selectedInstanceKey
        previewInteraction.clearMorph()
        if footerPanelMode == .preview, let settleKey {
            applySlideshowSelection(key: settleKey, pinPreview: true)
        }
    }

    /// Up/Down while playing: first press sets direction; press again in the same
    /// direction stops auto-play and steps once (manual). While stopped: step.
    func handlePreviewSlideshowDirection(_ direction: PreviewSlideshowDirection) {
        guard canRunPreviewSlideshow else { return }
        if isPreviewSlideshowPlaying {
            if previewSlideshowDirection == direction {
                stopPreviewSlideshow()
                stepPreviewSlideshowDiscrete(direction: direction)
            } else {
                previewSlideshowDirection = direction
            }
            return
        }
        previewSlideshowDirection = direction
        stepPreviewSlideshowDiscrete(direction: direction)
    }

    func previewSlideshowDirectionHelp(_ direction: PreviewSlideshowDirection) -> String {
        if isPreviewSlideshowPlaying {
            if previewSlideshowDirection == direction {
                return direction == .up
                    ? "Stop slideshow and step to previous instance"
                    : "Stop slideshow and step to next instance"
            }
            return direction == .up ? "Cycle upward" : "Cycle downward"
        }
        return direction == .up ? "Previous instance" : "Next instance"
    }

    func cyclePreviewSlideshowSpeed() {
        previewSlideshowSpeed = previewSlideshowSpeed.next
    }

    func previewSlideshowFilteredListDidChange() {
        let keys = filteredInstances.map(\.key)
        defer { previewSlideshowKnownKeys = keys }

        guard isPreviewSlideshowPlaying else {
            if !canRunPreviewSlideshow {
                stopPreviewSlideshow()
            }
            return
        }

        if keys.count < 2 {
            stopPreviewSlideshow()
            return
        }

        if let selected = selectedInstanceKey, keys.contains(selected) {
            return
        }

        stopPreviewSlideshow()
    }

    func notifyPreviewSlideshowUserSelect() {
        guard isPreviewSlideshowPlaying, !previewSlideshowIsAdvancing else { return }
        stopPreviewSlideshow()
    }

    func notifyPreviewSlideshowUserHover() {
        guard isPreviewSlideshowPlaying else { return }
        stopPreviewSlideshow()
    }

    func notifyPreviewSlideshowLeftPreviewMode() {
        stopPreviewSlideshow()
    }

    // MARK: Private

    private func ensurePreviewSlideshowSelection() {
        let rows = filteredInstances
        guard !rows.isEmpty else { return }
        if let selected = selectedInstanceKey, rows.contains(where: { $0.key == selected }) {
            if footerPanelMode == .preview {
                previewInteraction.pinToSelection(selected)
            }
            return
        }
        applySlideshowSelection(key: rows[0].key, pinPreview: true)
    }

    private func applySlideshowSelection(key: String, pinPreview: Bool) {
        previewSlideshowIsAdvancing = true
        defer { previewSlideshowIsAdvancing = false }
        if selectedInstanceKey != key || selectedInstanceKeys != [key] {
            selectedInstanceKeys = [key]
            selectedInstanceKey = key
        }
        if pinPreview, footerPanelMode == .preview {
            previewInteraction.pinToSelection(key)
        }
    }

    /// Manual step (stopped transport / same-direction stop): discrete pose, no morph.
    private func stepPreviewSlideshowDiscrete(direction: PreviewSlideshowDirection) {
        guard let neighbor = slideshowNeighbor(
            from: previewInteraction.hoverInstanceKey ?? selectedInstanceKey,
            direction: direction
        ) else {
            stopPreviewSlideshow()
            return
        }
        applySlideshowSelection(key: neighbor.key, pinPreview: true)
    }

    private struct SlideshowNeighbor {
        let key: String
        let coords: [String: Double]
        let index: Int
    }

    private func slideshowNeighbor(
        from currentKey: String?,
        direction: PreviewSlideshowDirection
    ) -> SlideshowNeighbor? {
        let rows = filteredInstances
        guard rows.count >= 2 else { return nil }
        let keys = rows.map(\.key)
        let currentIndex: Int = {
            if let currentKey, let index = keys.firstIndex(of: currentKey) {
                return index
            }
            return 0
        }()
        let nextIndex: Int
        switch direction {
        case .down:
            nextIndex = (currentIndex + 1) % keys.count
        case .up:
            nextIndex = (currentIndex - 1 + keys.count) % keys.count
        }
        let row = rows[nextIndex]
        return SlideshowNeighbor(key: row.key, coords: row.coords, index: nextIndex)
    }

    private func currentSlideshowCoords() -> [String: Double]? {
        let key = previewInteraction.hoverInstanceKey ?? selectedInstanceKey
        return filteredInstances.first(where: { $0.key == key })?.coords
            ?? filteredInstances.first?.coords
    }

    private func restartPreviewSlideshowTimer() {
        previewSlideshowTask?.cancel()
        previewSlideshowTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 40_000_000)
            while let self, !Task.isCancelled, self.isPreviewSlideshowPlaying {
                let ran = await self.runSlideshowMorphSegment()
                if !ran { break }
            }
            await MainActor.run {
                self?.previewInteraction.clearMorph()
            }
        }
    }

    /// Hold on the current instance, then cycle selection to the next and morph into it.
    /// Frames update the CATextLayer via `glyphBridge` — not `@Published` coords.
    private func runSlideshowMorphSegment() async -> Bool {
        guard isPreviewSlideshowPlaying, !Task.isCancelled else { return false }

        // × factor = dwell on the settled pose (not morph length).
        let holdNanos = UInt64(previewSlideshowSpeed.holdDuration * 1_000_000_000)
        try? await Task.sleep(nanoseconds: holdNanos)
        guard isPreviewSlideshowPlaying, !Task.isCancelled else { return false }

        // Capture the departure pose before selection advances.
        guard let fromCoords = currentSlideshowCoords(),
              let neighbor = slideshowNeighbor(
                from: previewInteraction.hoverInstanceKey ?? selectedInstanceKey,
                direction: previewSlideshowDirection
              ) else {
            stopPreviewSlideshow()
            return false
        }

        let toCoords = neighbor.coords
        let morphDuration = previewSlideshowSpeed.morphDuration
        let identical = Self.coordsApproximatelyEqual(fromCoords, toCoords)
        let sample = slideshowSampleText(for: neighbor.key)

        // Arm external glyph drive before selection moves, so SwiftUI doesn't flash
        // the destination pose and then jump back to the departure coords.
        previewInteraction.beginMorph(toward: neighbor.key)
        previewInteraction.glyphBridge.prepareMorphWidth(
            from: fromCoords,
            to: toCoords,
            sample: sample
        )
        previewInteraction.glyphBridge.applyCoords(fromCoords)

        // Cycle selection with the transition — list/caption match the destination
        // while the glyph eases from the previous pose into it.
        applySlideshowSelection(key: neighbor.key, pinPreview: false)
        previewInteraction.hoverInstanceKey = neighbor.key
        previewInteraction.isHoverActive = false

        if identical {
            // Naming-only / same pose: brief beat (scales with ×; no floor that caps ×10).
            let beatNanos = UInt64(max(morphDuration * 0.5, 0.015) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: beatNanos)
        } else {
            let start = DispatchTime.now()
            while isPreviewSlideshowPlaying, !Task.isCancelled {
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)
                    / 1_000_000_000
                let linearT = min(1, max(0, elapsed / morphDuration))
                let t = Self.smoothstep(linearT)
                let coords = Self.lerpCoords(from: fromCoords, to: toCoords, t: t)
                previewInteraction.glyphBridge.applyCoords(coords)
                if linearT >= 1 { break }
                try? await Task.sleep(nanoseconds: Self.slideshowFrameNanos)
            }
        }

        guard isPreviewSlideshowPlaying, !Task.isCancelled else { return false }

        previewInteraction.glyphBridge.applyCoords(toCoords)
        previewInteraction.clearMorph()
        previewInteraction.pinToSelection(neighbor.key)
        return true
    }

    private func slideshowSampleText(for targetKey: String) -> String {
        let defaults = UserDefaults.standard.string(forKey: "studio.fontPreviewSample") ?? ""
        let trimmed = defaults.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let name = filteredInstances.first(where: { $0.key == targetKey })?.composedName,
           !name.isEmpty {
            return name
        }
        return " "
    }

    private static func lerpCoords(
        from: [String: Double],
        to: [String: Double],
        t: Double
    ) -> [String: Double] {
        let keys = Set(from.keys).union(to.keys)
        var result: [String: Double] = [:]
        result.reserveCapacity(keys.count)
        for key in keys {
            let a = from[key] ?? to[key] ?? 0
            let b = to[key] ?? from[key] ?? 0
            result[key] = a + (b - a) * t
        }
        return result
    }

    private static func smoothstep(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }

    private static func coordsApproximatelyEqual(_ a: [String: Double], _ b: [String: Double]) -> Bool {
        let keys = Set(a.keys).union(b.keys)
        for key in keys {
            let av = a[key] ?? 0
            let bv = b[key] ?? 0
            if abs(av - bv) > 0.0005 { return false }
        }
        return true
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}
