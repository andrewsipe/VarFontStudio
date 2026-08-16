import AppKit
import SwiftUI
import VarFontCore

struct AxisTreePanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @EnvironmentObject private var layout: EditorLayoutPreferences
    @State private var expandedAxes: Set<String> = []
    @State private var editingStop: (id: String, field: StopEditField)?
    @State private var addStopRequest: AddAxisStopRequest?
    @State private var addRegistrationRequest: AddRegistrationAxisRequest?
    @State private var fillStopsRequest: FillStopsRequest?
    @State private var formatChangeRequest: StopFormatChangeRequest?
    @State private var tabKeyMonitor: TabKeyMonitor?
    @State private var activeTabNavigation: ((Bool) -> Void)?
    @State private var activeTabStopID: String?
    @State private var axisDragSession = AxisTreeAxisDragSession()
    @State private var axisHeaderFrames: [String: CGRect] = [:]
    @State private var axisTreePanelHeight: CGFloat = 0
    @State private var combinationDrawerContentHeight: CGFloat = 0
    private let axisReorderCoordinateSpace = "axisTreeAxisReorder"

    var body: some View {
        VStack(spacing: 0) {
            StudioPanelHeader(title: "Axis tree") {
                HStack(spacing: StudioSpacing.controlGap) {
                    if let font = editor.selectedFont {
                        HStack(spacing: StudioSpacing.instanceRowVertical) {
                            Text("\(font.axes.count)")
                                .foregroundStyle(StudioColors.metricForeground)
                            Text("axes")
                                .foregroundStyle(.secondary)
                        }
                        .font(StudioTypography.caption)
                    }

                    StudioPanelCollapseButton(
                        edge: .leading,
                        help: "Collapse axis tree"
                    ) {
                        layout.axisTreeCollapsed = true
                    }
                }
            }

            axisTreeScopeBand
                .frame(height: StudioChromeBand.scope)
                .padding(.horizontal, StudioSpacing.contentInset)

            Divider()

            axisTreeContextBand
                .frame(height: StudioChromeBand.context)
                .padding(.horizontal, StudioSpacing.contentInset)
                .background(StudioColors.surfaceMuted)
                .overlay(alignment: .bottom) { Divider() }

            if editor.selectedFont != nil {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            axesContent(scrollProxy: scrollProxy)
                        }
                        .padding(.horizontal, StudioSpacing.contentInset)
                        .padding(.top, StudioSpacing.panelContentTop)
                        .padding(.bottom, StudioSpacing.panelVertical)
                    }
                    .transaction { $0.animation = nil }
                    .onChange(of: editor.inspectorFocus.axisTreeFocusRequest) { _, request in
                        guard let request else { return }
                        scrollToAxisStop(
                            scrollProxy: scrollProxy,
                            axisTag: request.axisTag,
                            stopID: request.stopID
                        )
                    }
                    .onChange(of: editor.inspectorFocus.focusedAxisTag) { _, tag in
                        if let tag {
                            expandedAxes.insert(tag)
                        }
                    }
                    .onChange(of: editor.selectedAxisStopID) { _, stopID in
                        guard let stopID, editor.inspectorFocus.axisTreeFocusRequest == nil else { return }
                        expandAxisContaining(stopID: stopID)
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollProxy.scrollTo(stopID, anchor: .center)
                            }
                        }
                    }
                }

                combinationStylesDrawer
            } else {
                ContentUnavailableView(
                    "No Axis Tree",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text(
                        editor.hasOpenProjects
                            ? "Select a file to view its axis tree."
                            : StudioEmptyCopy.openOrDropFont
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: AxisTreePanelHeightKey.self, value: geo.size.height)
            }
        }
        .onPreferenceChange(AxisTreePanelHeightKey.self) { height in
            axisTreePanelHeight = height
        }
        .onChange(of: editor.selectedFontID) {
            editingStop = nil
            resetExpansion()
            combinationDrawerContentHeight = 0
            layout.combinationStylesDrawerExpanded = false
        }
        .onChange(of: editingStop?.id) { _, stopID in
            if stopID == nil {
                tabKeyMonitor?.stop()
                tabKeyMonitor = nil
                activeTabNavigation = nil
                activeTabStopID = nil
            }
        }
        .onAppear {
            if expandedAxes.isEmpty {
                resetExpansion()
            }
        }
        .sheet(item: $addStopRequest) { request in
            if let axis = editor.selectedFont?.axes.first(where: { $0.tag == request.axisTag }) {
                AddAxisStopSheet(axis: axis) {
                    addStopRequest = nil
                }
                .environmentObject(editor)
            }
        }
        .sheet(item: $addRegistrationRequest) { _ in
            AddFileAxisSheet {
                addRegistrationRequest = nil
            }
            .environmentObject(editor)
        }
        .sheet(item: $fillStopsRequest) { request in
            if let axis = editor.selectedFont?.axes.first(where: { $0.tag == request.axisTag }) {
                FillAxisStopsSheet(axis: axis) {
                    fillStopsRequest = nil
                }
                .environmentObject(editor)
                .id(request.axisTag)
            }
        }
        .sheet(item: $formatChangeRequest) { request in
            if let axis = editor.selectedFont?.axes.first(where: { $0.tag == request.axisTag }),
               let stop = axis.values.first(where: { $0.id == request.stopID }) {
                ChangeAxisStopFormatSheet(axis: axis, stop: stop) {
                    formatChangeRequest = nil
                }
                .environmentObject(editor)
            }
        }
    }

    // MARK: - Sections

    /// Band 2 — project · file glance (peer to Instances/Names and Project/Instance tabs).
    private var axisTreeScopeBand: some View {
        HStack(spacing: StudioSpacing.rowGap) {
            if let project = editor.activeOpenProject {
                Text(editor.projectTabLabel(for: project))
                    .font(StudioTypography.rowName)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } else {
                Text("No project")
                    .font(StudioTypography.rowName)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if let font = editor.selectedFont {
                Text("·")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.quaternary)
                Text(editor.fontBasename(for: font))
                    .font(StudioTypography.rowName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: StudioSpacing.controlGap)

            if editor.isSelectedFontMaster, editor.projectHasMultipleFiles {
                StudioPlainLinkButton(
                    title: "Push Axis Tree",
                    role: .accent,
                    font: StudioTypography.caption,
                    help: "Copy matching axis stops from the master onto the other files. Axes the destination does not have are left off."
                ) {
                    editor.requestPushMasterAxisTree()
                }
            }

            if !editor.hasOpenProjects {
                StudioPlainLinkButton(
                    title: "+ Add project…",
                    role: .accent,
                    font: StudioTypography.caption,
                    help: "Open a variable font as a new project tab"
                ) {
                    editor.presentOpenPanel()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Band 3 — instance-grid summary (peer to Instances filter / Inspector project title).
    private var axisTreeContextBand: some View {
        Group {
            if let plan = editor.instancePlan, !plan.formula.parts.isEmpty {
                VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                    studioSummaryRow("Instance grid", value: gridFormulaText(plan))
                    studioSummaryRow("Generated", value: "\(plan.formula.totalGenerated)")
                }
            } else {
                VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                    studioSummaryRow("Instance grid", value: "—")
                    studioSummaryRow("Generated", value: "—")
                }
                .opacity(0.55)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func studioSummaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(StudioTypography.bodyMedium)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(StudioTypography.emphasis)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }

    private var conflictAlertMessage: String {
        let count = editor.unresolvedAxisConflictCount
        if count == 1, let bundle = editor.axisConflictBundles.first {
            return "Naming conflict on \(bundle.axisLabel) (\(bundle.axisTag))"
        }
        return "\(count) axes need attention"
    }

    @ViewBuilder
    private func planWarningsBand(scrollProxy: ScrollViewProxy) -> some View {
        let issueCount = editor.reviewIssueCount
        let infoWarnings = informationalPlanWarningsForBand
        let hasSummary = issueCount > 0
        let hasDetails = !infoWarnings.isEmpty
        let radius = StudioRadius.surface

        if hasSummary || hasDetails {
            // One card composed of uneven-rounded strips:
            // - summary alone → all four corners rounded
            // - summary + details → summary top-only, details bottom-only, hairline between
            // (Fully rounding both strips pinched a gap at the join.)
            VStack(alignment: .leading, spacing: 0) {
                if hasSummary {
                    HStack(spacing: StudioSpacing.controlGap) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(StudioTypography.caption)
                            .foregroundStyle(StudioColors.warningForeground)

                        Text(issueCount == 1 ? "1 issue to review" : "\(issueCount) issues to review")
                            .font(StudioTypography.caption)
                            .foregroundStyle(StudioColors.warningOnFillForeground)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        StudioFlatButton(
                            title: "Review issues…",
                            role: .warningAction,
                            size: .compact
                        ) {
                            editor.startReviewSession()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        StudioColors.warningFillStrong,
                        in: UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: radius,
                                bottomLeading: hasDetails ? 0 : radius,
                                bottomTrailing: hasDetails ? 0 : radius,
                                topTrailing: radius
                            ),
                            style: .continuous
                        )
                    )
                }

                if hasSummary, hasDetails {
                    Rectangle()
                        .fill(StudioColors.warningStroke)
                        .frame(height: 0.5)
                }

                if hasDetails {
                    VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                        ForEach(Array(infoWarnings.enumerated()), id: \.offset) { _, warning in
                            HStack(alignment: .top, spacing: StudioSpacing.controlGap) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(StudioTypography.caption)
                                    .foregroundStyle(StudioColors.warningForeground)
                                    .padding(.top, StudioSpacing.warningGlyphTopNudge)
                                Text(warning.message)
                                    .font(StudioTypography.caption)
                                    .foregroundStyle(StudioColors.warningOnFillForeground)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: StudioSpacing.controlGap)
                                if warning.code == "duplicate_composed_name" {
                                    StudioPlainLinkButton(
                                        title: "Show in list…",
                                        role: .accent,
                                        font: StudioTypography.caption
                                    ) {
                                        layout.showInstances = true
                                        if let name = warning.name {
                                            editor.showDuplicateInstances(matchingName: name)
                                        } else {
                                            editor.showAllDuplicateInstances()
                                        }
                                    }
                                }
                                if PlanIssueCodes.resolvable.contains(warning.code), hasSummary {
                                    StudioFlatButton(
                                        title: "Review…",
                                        role: .warningAction,
                                        size: .compact
                                    ) {
                                        editor.startReviewSession(jumpingTo: warning)
                                        if let axis = warning.axis {
                                            focusAxis(axis, scrollProxy: scrollProxy)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, StudioSpace.x2_5)
                    .padding(.vertical, StudioSpace.x2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        StudioColors.warningFill,
                        in: UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: hasSummary ? 0 : radius,
                                bottomLeading: radius,
                                bottomTrailing: radius,
                                topTrailing: hasSummary ? 0 : radius
                            ),
                            style: .continuous
                        )
                    )
                }
            }
            .padding(.bottom, StudioSpacing.controlGap)
        }
    }

    private var informationalPlanWarningsForBand: [PlanWarning] {
        summarizedComposedNameWarnings(editor.informationalPlanWarnings())
    }

    private func summarizedComposedNameWarnings(_ warnings: [PlanWarning]) -> [PlanWarning] {
        let duplicateComposed = warnings.filter { $0.code == "duplicate_composed_name" }
        let other = warnings.filter { $0.code != "duplicate_composed_name" }
        guard duplicateComposed.count > 3 else { return warnings }
        let summary = PlanWarning(
            code: "duplicate_composed_name",
            message: "\(duplicateComposed.count) composed names are duplicated.",
            hint: duplicateComposed[0].hint
        )
        return other + [summary]
    }

    private func axisPlanWarnings(for tag: String) -> [PlanWarning] {
        editor.instancePlan?.warnings.filter {
            $0.axis == tag && AxisTreePlanWarningCodes.axisInline.contains($0.code)
        } ?? []
    }

    private func focusAxis(_ tag: String, scrollProxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            expandedAxes.insert(tag)
            return ()
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy.scrollTo(tag, anchor: .top)
            }
        }
    }

    private var combinationStylesDrawer: some View {
        let compounds = editor.selectedFont?.compoundStatValues ?? []
        let suggestionCount = editor.compoundSuggestionsForSelectedFont.count
        let isExpanded = layout.combinationStylesDrawerExpanded

        return VStack(spacing: 0) {
            Divider()

            Button {
                // Instant open/close — animating measured body height looks like a genie resize.
                layout.combinationStylesDrawerExpanded.toggle()
            } label: {
                HStack(spacing: StudioSpacing.controlGap) {
                    StudioDisclosureChevron(isExpanded: isExpanded)

                    Text("Combinations")
                        .font(StudioTypography.emphasis)
                        .foregroundStyle(.primary)

                    Text("·")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)

                    Text("Format 4")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)

                    if suggestionCount > 0 {
                        Text(suggestionCount == 1
                              ? "1 suggested"
                              : "\(suggestionCount) suggested")
                            .font(StudioTypography.caption.weight(.medium))
                            .foregroundStyle(StudioColors.statFormat1)
                            .padding(.horizontal, StudioSpacing.contentInset)
                            .padding(.vertical, StudioSpace.x1)
                            .background(StudioColors.statFormat4Background, in: Capsule())
                            .help("\(suggestionCount) Format 4 suggestion\(suggestionCount == 1 ? "" : "s") from fvar")
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: StudioSpacing.instanceRowVertical) {
                        Text("\(compounds.count)")
                            .foregroundStyle(StudioColors.metricForeground)
                        Text(compounds.count == 1 ? "style" : "styles")
                            .foregroundStyle(.secondary)
                    }
                    .font(StudioTypography.caption)
                }
                .padding(.horizontal, StudioSpacing.contentInset)
                .frame(height: StudioChromeBand.header)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(StudioColors.surfaceMuted)
            .overlay(alignment: .bottom) {
                if isExpanded { Divider() }
            }
            .help("Format 4 combination names — multi-axis STAT points that do not multiply the instance grid.")

            if isExpanded, let font = editor.selectedFont {
                ScrollView {
                    CombinationStylesSection(
                        compounds: font.compoundStatValues,
                        axes: font.axes
                    )
                    // Ideal height, not the ScrollView viewport — keeps the drawer snug.
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: CombinationDrawerContentHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: combinationDrawerBodyHeight, alignment: .top)
                .clipped()
                .background(StudioColors.surfaceSubtle)
                .onPreferenceChange(CombinationDrawerContentHeightKey.self) { height in
                    guard height > 0, abs(height - combinationDrawerContentHeight) > 0.5 else { return }
                    // Height tracking must not inherit drawer open/close animations —
                    // interpolating measured height reads as a choppy "genie" resize.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        combinationDrawerContentHeight = height
                    }
                }
            }
        }
        .onChange(of: layout.combinationStylesDrawerExpanded) { _, expanded in
            if !expanded {
                combinationDrawerContentHeight = 0
            }
        }
    }

    /// Fit content when short; scroll once content needs more than ~60% of the Axis Tree.
    private var combinationDrawerBodyHeight: CGFloat {
        let maxBody: CGFloat = {
            guard axisTreePanelHeight > 0 else { return 400 }
            return min(560, max(280, axisTreePanelHeight * 0.62))
        }()
        guard combinationDrawerContentHeight > 0 else {
            return min(120, maxBody)
        }
        return min(combinationDrawerContentHeight.rounded(.up), maxBody)
    }

    @ViewBuilder
    private func axesContent(scrollProxy: ScrollViewProxy) -> some View {
        planWarningsBand(scrollProxy: scrollProxy)

        if editor.unresolvedAxisConflictCount > 0, editor.reviewIssueCount == 0 {
            StudioConflictAlert(
                message: conflictAlertMessage,
                actionTitle: "Resolve…"
            ) {
                editor.presentFirstConflictResolver()
            }
            .padding(.bottom, StudioSpacing.controlGap)
        }

        if let font = editor.selectedFont {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(font.axes.enumerated()), id: \.element.id) { index, axis in
                    if shouldShowAxisDropGap(before: index) {
                        axisReorderDropGap()
                            .padding(.vertical, StudioSpacing.rowGap)
                    } else if index > 0 {
                        Divider()
                            .padding(.vertical, StudioSpacing.rowGap)
                            .opacity(axisDragSession.draggingTag == axis.tag ? 0.2 : 1)
                    }
                    axisBlock(axis, axisIndex: index)
                        .id(axis.tag)
                }
                if shouldShowAxisDropGap(before: font.axes.count) {
                    axisReorderDropGap()
                        .padding(.top, StudioSpacing.rowGap)
                }

                StudioFlatButton(
                    title: "Add Naming Axis",
                    systemImage: "plus",
                    role: .tinted(
                        foreground: .primary,
                        background: StudioColors.registrationBackground
                    ),
                    size: .row,
                    help: "Add a naming axis for family identity across files (no fvar scale)"
                ) {
                    addRegistrationRequest = AddRegistrationAxisRequest()
                }
                .padding(.top, StudioSpacing.sectionGap)
            }
            .coordinateSpace(name: axisReorderCoordinateSpace)
            .onPreferenceChange(AxisHeaderFramePreferenceKey.self) { frames in
                axisHeaderFrames.merge(frames) { _, new in new }
            }
            .overlay(alignment: .topLeading) {
                axisReorderGhostOverlay
            }
            .animation(.easeOut(duration: 0.12), value: axisDragSession.targetGapIndex)
        }
    }

    @ViewBuilder
    private func axisBlock(_ axis: AxisDefinition, axisIndex: Int) -> some View {
        let isExpanded = expandedAxes.contains(axis.tag)
        let resolvableWarnings = axisPlanWarnings(for: axis.tag)
            .filter { PlanIssueCodes.resolvable.contains($0.code) }

        VStack(alignment: .leading, spacing: 0) {
            AxisTreeAxisHeader(
                axis: axis,
                isExpanded: isExpanded,
                hasConflict: editor.bundle(for: axis.tag) != nil,
                axisWarnings: axisPlanWarnings(for: axis.tag),
                resolvablePlanWarnings: resolvableWarnings,
                fileRegistrationLabel: axis.lane == .registration ? registrationLabel(for: axis) : nil,
                registrationStops: axis.lane == .registration ? axis.values : [],
                selectedRegistrationStopID: registrationStopID(for: axis),
                onSelectRegistrationStop: axis.lane == .registration ? { stopID in
                    guard let font = editor.selectedFont,
                          let stop = axis.values.first(where: { $0.id == stopID }) else { return }
                    editor.setFileStatRegistration(tag: axis.tag, value: stop.value, forFontID: font.id)
                } : nil,
                isInstanceAxis: instanceAxisBinding(for: axis.tag),
                onToggleExpansion: { toggleAxisExpansion(for: axis.tag) },
                onResolveConflict: {
                    editor.presentConflictResolver(for: axis.tag)
                },
                onReviewPlanIssue: {
                    editor.presentFirstResolvablePlanIssue(on: axis.tag)
                },
                onUpdateDisplayName: { name in
                    editor.updateAxisDisplayName(tag: axis.tag, name: name)
                }
            )
            .opacity(axisDragSession.draggingTag == axis.tag ? 0.28 : 1)
            .overlay {
                if axisDragSession.draggingTag == axis.tag {
                    StudioDragOutline.axisTreeRing(color: Color.secondary.opacity(0.35))
                }
            }
            .contentShape(Rectangle())
            .studioDragAffordances(
                // Suppress hover rings / grab cursor on every header while a reorder is active.
                isEnabled: !axisDragSession.isDragging,
                isDragging: axisDragSession.draggingTag == axis.tag,
                outlineHorizontalOutset: StudioDragOutline.axisTreeOutsetHorizontal,
                outlineVerticalOutset: StudioDragOutline.axisTreeOutsetVertical
            )
            // Keep the dragged header hittable so the active gesture isn't cancelled;
            // block other rows so their hover links / toggles don't light up under the pointer.
            .allowsHitTesting(
                !axisDragSession.isDragging || axisDragSession.draggingTag == axis.tag
            )
            .simultaneousGesture(axisReorderPressThenDragGesture(for: axis.tag))
            .help("Click to expand · click and hold to reorder")
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: AxisHeaderFramePreferenceKey.self,
                        value: [axis.tag: proxy.frame(in: .named(axisReorderCoordinateSpace))]
                    )
                }
            }

            if isExpanded, axisDragSession.draggingTag != axis.tag {
                axisDetail(axis)
                    .padding(.top, StudioSpacing.tightGap)
                    .padding(.leading, AxisBlockLayout.stopIndentWidth)
            }
        }
    }

    @ViewBuilder
    private var axisReorderGhostOverlay: some View {
        if let tag = axisDragSession.draggingTag,
           let axis = editor.selectedFont?.axes.first(where: { $0.tag == tag }) {
            let size = axisDragSession.ghostSize
            let width = max(size.width, 120)
            let height = max(size.height, 36)
            AxisTreeAxisHeader(
                axis: axis,
                isExpanded: false,
                hasConflict: false,
                axisWarnings: [],
                resolvablePlanWarnings: [],
                fileRegistrationLabel: axis.lane == .registration ? registrationLabel(for: axis) : nil,
                registrationStops: axis.lane == .registration ? axis.values : [],
                selectedRegistrationStopID: registrationStopID(for: axis),
                isInstanceAxis: .constant(axis.role == .instance),
                onToggleExpansion: {}
            )
            .frame(width: width, height: height, alignment: .leading)
            .background(
                StudioColors.surfaceInset,
                in: RoundedRectangle.studio(StudioDragOutline.cornerRadius)
            )
            .overlay {
                StudioDragOutline.axisTreeRing(
                    color: Color.secondary.opacity(0.45),
                    lineWidth: StudioStroke.strong
                )
            }
            .shadow(color: .black.opacity(0.22), radius: 8, y: 2)
            .offset(x: axisDragSession.ghostOrigin.x, y: axisDragSession.ghostOrigin.y)
            .allowsHitTesting(false)
        }
    }

    /// Empty drop slot matching the dragged header size + the same outset ring as the ghost.
    private func axisReorderDropGap() -> some View {
        let height = max(axisDragSession.ghostSize.height, 36)
        return Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Color.secondary.opacity(0.06),
                in: RoundedRectangle.studio(StudioDragOutline.cornerRadius)
            )
            .overlay {
                StudioDragOutline.axisTreeRing(
                    color: Color.secondary.opacity(0.45),
                    lineWidth: StudioStroke.emphasis
                )
            }
            .accessibilityLabel("Drop axis here")
    }

    private func shouldShowAxisDropGap(before index: Int) -> Bool {
        guard axisDragSession.showsDropGap,
              let gap = axisDragSession.targetGapIndex else { return false }
        return gap == index
    }

    /// Click-and-hold on the header starts a reorder drag; a short click still expands/collapses
    /// via the header button (suppressed after a drag).
    private func axisReorderPressThenDragGesture(for tag: String) -> some Gesture {
        LongPressGesture(minimumDuration: 0.18)
            .sequenced(before: DragGesture(
                // 0: ghost appears as soon as the long-press succeeds (no extra wiggle).
                minimumDistance: 0,
                coordinateSpace: .named(axisReorderCoordinateSpace)
            ))
            .onChanged { value in
                guard let font = editor.selectedFont else { return }
                switch value {
                case .second(true, let drag):
                    guard let drag else { return }
                    if axisDragSession.draggingTag == nil {
                        // Prefer a measured header frame; fall back to start location so a
                        // missing preference doesn't produce a zero-size / stuck ghost.
                        let headerFrame = axisHeaderFrames[tag] ?? CGRect(
                            x: drag.startLocation.x - 60,
                            y: drag.startLocation.y - 18,
                            width: 240,
                            height: 36
                        )
                        guard headerFrame.width > 1, headerFrame.height > 1 else { return }
                        let grabOffset = CGSize(
                            width: drag.startLocation.x - headerFrame.minX,
                            height: drag.startLocation.y - headerFrame.minY
                        )
                        axisDragSession.begin(
                            tag: tag,
                            axisTags: font.axes.map(\.tag),
                            grabOffset: grabOffset,
                            ghostOrigin: CGPoint(x: headerFrame.minX, y: headerFrame.minY),
                            ghostSize: headerFrame.size,
                            headerFrames: axisHeaderFrames
                        )
                    }
                    axisDragSession.updateGhost(at: drag.location)
                    axisDragSession.targetGapIndex = axisReorderTargetGap(at: drag.location.y)
                default:
                    break
                }
            }
            .onEnded { value in
                // Only commit if the long-press→drag sequence actually started a session.
                // A cancelled long-press still delivers onEnded; don't swallow the expand click.
                switch value {
                case .second(true, _):
                    commitAxisReorderOrCancel()
                default:
                    break
                }
            }
    }

    private func toggleAxisExpansion(for tag: String) {
        if axisDragSession.suppressNextExpansionToggle {
            axisDragSession.suppressNextExpansionToggle = false
            return
        }
        toggleExpansion(for: tag)
    }

    /// Gap index in the freeze-at-pickup header layout (`0...count`).
    /// Frozen frames avoid midY oscillation when inserting the drop gap shifts live rows.
    private func axisReorderTargetGap(at y: CGFloat) -> Int? {
        let tags = axisDragSession.originalTags
        guard !tags.isEmpty else { return nil }
        let frames = axisDragSession.frozenHeaderFrames
        for (index, tag) in tags.enumerated() {
            guard let frame = frames[tag] else { continue }
            if y < frame.midY {
                return index
            }
        }
        return tags.count
    }

    private func commitAxisReorderOrCancel() {
        defer {
            // Swallow the click that often follows a press-drag, then clear.
            if axisDragSession.suppressNextExpansionToggle {
                DispatchQueue.main.async {
                    axisDragSession.suppressNextExpansionToggle = false
                }
            }
        }
        guard let tag = axisDragSession.draggingTag,
              let gap = axisDragSession.targetGapIndex else {
            if axisDragSession.draggingTag != nil {
                axisDragSession.reset()
                axisDragSession.suppressNextExpansionToggle = true
            }
            return
        }
        let originalIndex = axisDragSession.fromIndex
        let landedSameSpot = gap == originalIndex || gap == originalIndex + 1
        axisDragSession.reset()
        axisDragSession.suppressNextExpansionToggle = true
        guard !landedSameSpot else { return }
        editor.reorderAxisTree(moving: tag, toIndex: gap)
    }

    // MARK: - Axis detail

    @ViewBuilder
    private func axisDetail(_ axis: AxisDefinition) -> some View {
        let showElidable = axis.role == .instance || axis.lane == .registration
        let axisHasConflict = axis.values.contains { editor.conflictStopIDs.contains($0.id) }

        VStack(alignment: .leading, spacing: 0) {
            if axis.values.isEmpty {
                Text(axis.isDesignRecordOnly
                    ? "No STAT axis values on this design axis"
                    : "No STAT stops on this axis")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            } else {
                AxisStopTableHeader(
                    showElidable: showElidable,
                    showDefaultMark: true,
                    showRemoveSlot: true,
                    showCode: editor.isCodeNamingEnabled,
                    showConflictColumn: axisHasConflict,
                    valueSortAscending: EditorViewModel.axisStopsValueSortAscending(axis.values),
                    onToggleValueSort: {
                        editor.toggleAxisStopsValueSort(axisTag: axis.tag)
                    }
                )
                .padding(.bottom, AxisDetailSpacing.tableHeaderToFirstRowGap)

                ForEach(axis.values) { stop in
                    axisStopRow(
                        axis: axis,
                        stop: stop,
                        showElidable: showElidable,
                        showConflictColumn: axisHasConflict
                    )
                    .id(stop.id)
                }
            }

            if axis.role == .instance || axis.isDesignRecordOnly {
                let showFill = axis.role == .instance && AxisStopFillPlanner.supportsFill(axis)
                HStack(spacing: StudioSpacing.controlGap) {
                    StudioFlatButton(
                        title: "Add Stop(s)",
                        systemImage: "plus",
                        size: .row,
                        expands: showFill,
                        help: AxisStopGapFill.proposal(for: axis) == nil
                            ? "Add a stop without replacing the ladder. Use Several to place more than one."
                            : "Add one or more stops without replacing the ladder. Missing grid values are suggested."
                    ) {
                        addStopRequest = AddAxisStopRequest(axisTag: axis.tag)
                    }

                    if showFill {
                        StudioFlatButton(
                            title: "Fill stops…",
                            systemImage: "square.grid.3x1.folder.badge.plus",
                            size: .row,
                            expands: true,
                            help: axis.values.isEmpty
                                ? "Evenly space or interval-fill stops across this axis's range."
                                : "Replace this axis's stops with an evenly spaced or interval fill. Reopen anytime to tweak."
                        ) {
                            fillStopsRequest = FillStopsRequest(axisTag: axis.tag)
                        }
                    }
                }
                .padding(.top, AxisDetailSpacing.lastStopToAddButtonGap)
            }
        }
        .padding(.vertical, StudioSpace.x0_5)
    }

    // MARK: - Bindings

    private func toggleExpansion(for tag: String) {
        if expandedAxes.contains(tag) {
            expandedAxes.remove(tag)
        } else {
            expandedAxes.insert(tag)
        }
    }

    private func instanceAxisBinding(for tag: String) -> Binding<Bool> {
        Binding(
            get: {
                editor.selectedFont?.axes.first(where: { $0.tag == tag })?.role == .instance
            },
            set: { editor.setAxisInstanceGridEnabled(tag: tag, enabled: $0) }
        )
    }

    private func registrationLabel(for axis: AxisDefinition) -> String? {
        guard let font = editor.selectedFont,
              let value = font.fileStatRegistration[axis.tag],
              let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: value) else {
            return axis.values.first?.name
        }
        return stop.name
    }

    private func registrationStopID(for axis: AxisDefinition) -> String? {
        guard let font = editor.selectedFont,
              let value = font.fileStatRegistration[axis.tag],
              let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: value) else {
            return axis.values.first?.id
        }
        return stop.id
    }

    private func isRegistrationStop(_ stop: AxisValue, axis: AxisDefinition) -> Bool {
        guard axis.lane == .registration,
              let font = editor.selectedFont,
              let value = font.fileStatRegistration[axis.tag],
              let registered = AxisCoordinate.matchingStop(in: axis.values, coordinate: value) else {
            return false
        }
        return registered.id == stop.id
    }

    private func linkedTargetName(for stop: AxisValue, in axis: AxisDefinition) -> String? {
        guard stop.statFormat == 3, let linkedValue = stop.linkedValue else { return nil }
        if let target = axis.values.first(where: {
            $0.id != stop.id && AxisCoordinate.valuesEqual($0.value, linkedValue)
        }) {
            return target.name
        }
        if let convention = StatFormat3Pairing.format3LinkedValue(for: stop.value, axis: axis),
           AxisCoordinate.valuesEqual(convention, linkedValue) {
            return StatFormat3Pairing.format3LinkedLabel(axis: axis, linkedValue: linkedValue)
        }
        return StudioFormatting.axisValue(linkedValue)
    }

    private func axisStopRow(
        axis: AxisDefinition,
        stop: AxisValue,
        showElidable: Bool,
        showConflictColumn: Bool = false
    ) -> some View {
        let isFvarDefault = axis.hasFvarScale
            && axis.default.map { AxisCoordinate.valuesEqual($0, stop.value) } == true
        return AxisTreeStopRow(
            stop: stop,
            linkedTargetName: linkedTargetName(for: stop, in: axis),
            isRegistrationStop: isRegistrationStop(stop, axis: axis),
            linkTargetCandidates: StatFormat3Pairing.linkTargets(
                for: axis,
                stopValue: stop.value,
                excludingStopID: stop.id
            ),
            isSelected: editor.selectedAxisStopID == stop.id,
            editingField: editingStop?.id == stop.id ? editingStop?.field : nil,
            showElidable: showElidable,
            showDefaultMark: true,
            showCode: editor.isCodeNamingEnabled,
            isFvarDefault: isFvarDefault,
            allowsRemove: true,
            valueEditable: axis.hasFvarScale || axis.isDesignRecordOnly,
            isElidable: stop.elidable,
            showConflictColumn: showConflictColumn,
            isConflicting: editor.conflictStopIDs.contains(stop.id),
            onResolveConflict: { editor.presentConflictResolver(for: axis.tag) },
            onSelect: {
                scheduleClearEdit()
                editor.toggleAxisStopSelection(stopID: stop.id)
            },
            onBeginEdit: { field in
                Task { @MainActor in
                    editor.selectedAxisStopID = stop.id
                    editingStop = (stop.id, field)
                }
            },
            onEndEdit: { scheduleClearEdit() },
            onChangeFormat: {
                formatChangeRequest = StopFormatChangeRequest(axisTag: axis.tag, stopID: stop.id)
            },
            onRegisterTabNavigation: { handler in
                registerTabNavigation(for: stop.id, handler: handler)
            },
            onTabForwardFromLastField: {
                advanceEditForward(axis: axis, afterStopID: stop.id)
            },
            onTabBackwardFromFirstField: {
                advanceEditBackward(axis: axis, beforeStopID: stop.id)
            },
            onRemove: { editor.removeAxisStop(axisTag: axis.tag, stopID: stop.id) },
            onCommitPin: { editor.updateAxisStopValue(axisTag: axis.tag, stopID: stop.id, value: $0) },
            onCommitMin: { editor.updateAxisStopRangeMin(axisTag: axis.tag, stopID: stop.id, rangeMin: $0) },
            onCommitMax: { editor.updateAxisStopRangeMax(axisTag: axis.tag, stopID: stop.id, rangeMax: $0) },
            onCommitCode: { editor.updateAxisStopCode(axisTag: axis.tag, stopID: stop.id, code: $0) },
            onCommitName: { editor.updateAxisStopName(axisTag: axis.tag, stopID: stop.id, name: $0) },
            onToggleElidable: { editor.toggleAxisStopElidable(axisTag: axis.tag, stopID: stop.id) },
            onSelectLinkTarget: { linkedValue in
                editor.updateAxisStopLinkedValue(axisTag: axis.tag, stopID: stop.id, linkedValue: linkedValue)
            }
        )
    }

    private func resetExpansion() {
        guard let font = editor.selectedFont else {
            expandedAxes = []
            return
        }
        expandedAxes = Set(
            font.axes.filter {
                $0.role == .instance || $0.isDesignRecordOnly || !$0.values.isEmpty
            }.map(\.tag)
        )
    }

    private func expandAxisContaining(stopID: String) {
        guard let font = editor.selectedFont else { return }
        for axis in font.axes where axis.values.contains(where: { $0.id == stopID }) {
            expandedAxes.insert(axis.tag)
            return
        }
    }

    private func scrollToAxisStop(scrollProxy: ScrollViewProxy, axisTag: String, stopID: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            expandedAxes.insert(axisTag)
            return ()
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy.scrollTo(axisTag, anchor: .top)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollProxy.scrollTo(stopID, anchor: .center)
                }
            }
        }
    }

    private func gridFormulaText(_ plan: InstancePlan) -> String {
        let parts = plan.formula.parts.map(String.init).joined(separator: " × ")
        let orthogonal = plan.formula.parts.reduce(1, *)
        let extras = plan.formula.totalGenerated - orthogonal
        if extras > 0 {
            return "\(parts) + \(extras) = \(plan.formula.totalGenerated)"
        }
        return "\(parts) = \(plan.formula.totalGenerated)"
    }

    private func scheduleEditingStop(stopID: String, field: StopEditField) {
        Task { @MainActor in
            editingStop = (stopID, field)
            editor.selectedAxisStopID = stopID
        }
    }

    private func scheduleClearEdit() {
        Task { @MainActor in
            editingStop = nil
            tabKeyMonitor?.stop()
            tabKeyMonitor = nil
            activeTabNavigation = nil
            activeTabStopID = nil
        }
    }

    private func registerTabNavigation(for stopID: String, handler: ((Bool) -> Void)?) {
        if let handler {
            guard editingStop?.id == stopID else { return }
            activeTabNavigation = handler
            activeTabStopID = stopID
            guard tabKeyMonitor == nil else { return }
            let monitor = TabKeyMonitor { shift in
                activeTabNavigation?(!shift)
            }
            monitor.start()
            tabKeyMonitor = monitor
        } else if activeTabStopID == stopID {
            activeTabNavigation = nil
            activeTabStopID = nil
        }
    }

    private func firstEditableField(for stop: AxisValue, axis: AxisDefinition) -> StopEditField {
        if axis.hasFvarScale || axis.isDesignRecordOnly { return .pin }
        if editor.isCodeNamingEnabled { return .code }
        return .name
    }

    private func lastEditableField(for stop: AxisValue, axis: AxisDefinition) -> StopEditField {
        .name
    }

    private func advanceEditForward(axis: AxisDefinition, afterStopID: String) {
        guard let font = editor.selectedFont else {
            scheduleClearEdit()
            return
        }

        let stops = axis.values
        if let index = stops.firstIndex(where: { $0.id == afterStopID }),
           index + 1 < stops.count {
            let next = stops[index + 1]
            scheduleEditingStop(stopID: next.id, field: firstEditableField(for: next, axis: axis))
            return
        }

        guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axis.tag }) else {
            scheduleClearEdit()
            return
        }

        for nextAxis in font.axes[(axisIndex + 1)...] where !nextAxis.values.isEmpty {
            let first = nextAxis.values[0]
            Task { @MainActor in
                expandedAxes.insert(nextAxis.tag)
                editingStop = (first.id, firstEditableField(for: first, axis: nextAxis))
                editor.selectedAxisStopID = first.id
            }
            return
        }

        scheduleClearEdit()
    }

    private func advanceEditBackward(axis: AxisDefinition, beforeStopID: String) {
        guard let font = editor.selectedFont else { return }

        let stops = axis.values
        if let index = stops.firstIndex(where: { $0.id == beforeStopID }),
           index > 0 {
            let previous = stops[index - 1]
            scheduleEditingStop(stopID: previous.id, field: lastEditableField(for: previous, axis: axis))
            return
        }

        guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axis.tag }),
              axisIndex > 0 else {
            return
        }

        for previousAxis in font.axes[..<axisIndex].reversed() where !previousAxis.values.isEmpty {
            let last = previousAxis.values[previousAxis.values.count - 1]
            Task { @MainActor in
                expandedAxes.insert(previousAxis.tag)
                editingStop = (last.id, lastEditableField(for: last, axis: previousAxis))
                editor.selectedAxisStopID = last.id
            }
            return
        }
    }
}

