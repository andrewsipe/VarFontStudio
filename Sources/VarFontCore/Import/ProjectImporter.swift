import Foundation

public enum ProjectImporter {
  public static func openFont(at url: URL) throws -> (ProjectDocument, FvarStopSeeder.Report) {
    let analysis = try FontAnalysisReader.analyzeForCommitDiff(url: url)
    return newProject(from: analysis, sourceURL: url)
  }

  public static func newProject(from analysis: FontAnalysis, sourceURL: URL) -> (ProjectDocument, FvarStopSeeder.Report) {
    let (font, seedReport) = fontDocument(from: analysis, sourceURL: sourceURL, isMaster: true, masterFontID: nil)
    let familyLabel = FilenameFamily.preferred(
      filenameOrPath: sourceURL.path,
      recordedFamily: analysis.source.familyName
    ) ?? sourceURL.deletingPathExtension().lastPathComponent

    let axisOrder = SlopeAxisPolicy.effectiveNamingOrder(
      analysis.inferred.namingOrderSuggested,
      axes: font.axes
    )
    let elided = ElidedFallbackResolver.resolve(
      axes: font.axes,
      namingOrder: axisOrder,
      fileStatRegistration: font.fileStatRegistration,
      sourceElidedFallback: analysis.nameAudit.elidedFallbackName,
      fileRole: font.fileRole
    )
    var project = ProjectDocument(
      schemaVersion: 1,
      created: Date(),
      modified: Date(),
      familyLabel: familyLabel,
      naming: NamingPolicy(
        order: NamingPolicy.orderWithDefaultClarifiers(axisOrder: axisOrder),
        inferredOrder: axisOrder,
        elidedFallback: elided.value
      ),
      template: ProjectTemplate(syncRoles: true, axes: []),
      fonts: [font]
    )
    NameIDStrategyInference.applyDanglingReflow(
      to: &project,
      analysis: analysis,
      fontID: font.id
    )
    return (project, seedReport)
  }

  @discardableResult
  public static func addFont(
    _ analysis: FontAnalysis,
    sourceURL: URL,
    to project: inout ProjectDocument
  ) -> FvarStopSeeder.Report {
    let masterID = project.fonts.first { $0.fileRole?.kind == .master }?.id ?? project.fonts.first?.id
    let (font, seedReport) = fontDocument(
      from: analysis,
      sourceURL: sourceURL,
      isMaster: project.fonts.isEmpty,
      masterFontID: masterID
    )
    project.fonts.append(font)
    project.syncNameIDStrategyToFonts()
    NameIDStrategyInference.applyDanglingReflow(
      to: &project,
      analysis: analysis,
      fontID: font.id
    )
    SiblingStopNames.shareEmptyWeightNames(in: &project.fonts)
    SiblingStopNames.shareFamilyName(
      in: &project,
      incomingFamily: FilenameFamily.preferred(
        filenameOrPath: sourceURL.path,
        recordedFamily: analysis.source.familyName
      ),
      incomingFontID: font.id
    )
    if project.fonts.count > 1 {
      project.naming.order = NamingPolicy.orderWithDefaultClarifiers(axisOrder: project.naming.order)
    }
    project.modified = Date()
    return seedReport
  }

  // MARK: - Private

  public static func axisDefinition(
    from axis: FontAnalysis.AnalyzedAxis,
    fileIsItalic: Bool = false
  ) -> AxisDefinition {
    let isDesignRecordOnly = axis.roleInferred == .designRecordOnly
    var definition = AxisDefinition(
      tag: axis.tag,
      displayName: axis.displayName,
      min: isDesignRecordOnly ? nil : axis.min,
      default: isDesignRecordOnly ? nil : axis.default,
      max: isDesignRecordOnly ? nil : axis.max,
      role: axis.roleInferred,
      roleInferred: axis.roleInferred,
      values: axis.valuesExisting.map { stop in
        let value = resolvedStopValue(stop, axis: axis)
        let link = axis.tag == "ital"
          ? ItalicStopNaming.assumedStyleLink(
              recorded: stop.name,
              value: value,
              format: stop.format ?? 1,
              linkedValue: stop.linkedValue
            )
          : (format: stop.format ?? 1, linkedValue: stop.linkedValue)
        return AxisValue(
          id: "\(axis.tag)-\(UUID().uuidString.prefix(8))",
          value: value,
          name: importedStopName(stop, axis: axis, fileIsItalic: fileIsItalic),
          elidable: stop.elidable ?? false,
          olderSibling: stop.olderSibling ?? false,
          statFormat: link.format,
          rangeMin: link.format == 3 ? nil : stop.rangeMin,
          rangeMax: link.format == 3 ? nil : stop.rangeMax,
          linkedValue: link.linkedValue
        )
      }
    )
    let inferredMapping = AxisReferenceMapping.inferKind(for: definition)
    definition.referenceMappingInferred = inferredMapping
    definition.referenceMapping = inferredMapping
    definition.referenceAnchors = AxisReferenceMapping.inferAnchors(for: definition)
    if !AxisLadderAlignment.supportsAlignment(definition.tag) {
      definition.referenceMapping = .identity
      definition.referenceMappingInferred = .identity
      definition.referenceAnchors = []
    }
    definition.fvarHidden = axis.fvarHidden ?? false
    return definition
  }

  private static func fontDocument(
    from analysis: FontAnalysis,
    sourceURL: URL,
    isMaster: Bool,
    masterFontID: String?
  ) -> (FontDocument, FvarStopSeeder.Report) {
    let fileIsItalic = Self.fileIsItalic(analysis: analysis, sourceURL: sourceURL)
    let axes = analysis.axes.map { axisDefinition(from: $0, fileIsItalic: fileIsItalic) }

    let placeholder = FontDocument(
      id: UUID().uuidString,
      sourcePath: sourceURL.path,
      dirty: false,
      axes: axes
    )
    let fileRole: FileRole
    if isMaster {
      fileRole = .master()
    } else {
      // Clarifiers are manual-only (File naming → Infer). Auto-guessing on import was too
      // aggressive and often expanded filename tokens beyond what the font actually uses.
      fileRole = .variant(masterFontID: masterFontID ?? "")
    }

    let filenameNaming = FilenameFamily.importNaming(analysis: analysis, sourceURL: sourceURL)

    var font = FontDocument(
      id: placeholder.id,
      sourcePath: sourceURL.path,
      outputPath: nil,
      analysisSnapshotID: SourceFontFingerprint.capture(url: sourceURL, analysis: analysis)?.serialized,
      dirty: false,
      fileRole: fileRole,
      axes: axes,
      options: CommitOptions(
        familyPSPrefix: filenameNaming.familyPSPrefix,
        nameidStrategy: NameIDStrategyInference.prefersReflow(analysis: analysis) ? .reflow : .preserve
      ),
      includedInstanceKeys: [],
      excludedInstanceKeys: [],
      overrides: InstanceOverrides(),
      fileStatRegistration: RegistrationAxisSupport.inferFileStatRegistration(
        axes: axes,
        analysis: analysis,
        sourcePath: sourceURL.path
      ),
      inferredIsItalicFile: RegistrationAxisSupport.isItalicFile(
        analysis: analysis,
        sourcePath: sourceURL.path
      ),
      compoundStatValues: compoundStatValues(from: analysis),
      statDesignAxisTags: analysis.designAxisTags,
      windowsNameOverrides: filenameNaming.overrides
    )
    let seedReport = FvarStopSeeder.seed(into: &font, analysis: analysis)
    // Import preserves STAT formats from source (including ital Format 3). Safe auto-fixes
    // never downgrade format; Format 1 → 3 upgrades surface as plan issues for user review.
    _ = PlanIssueResolver.applySafeAutoFixes(to: &font, analysis: analysis)
    _ = SlopeAxisPolicy.applyPassiveItalElision(to: &font)
    return (font, seedReport)
  }

  private static func compoundStatValues(from analysis: FontAnalysis) -> [CompoundStatValue] {
    analysis.compoundStatValues.map { record in
      CompoundStatValue(
        id: record.id,
        coords: record.coords,
        axisIndices: record.axisIndices,
        axisValues: record.axisValues,
        name: NameFiller.meaningful(record.name) ?? "",
        elidable: record.elidable,
        olderSibling: record.olderSibling
      )
    }
  }

  private static func fileIsItalic(analysis: FontAnalysis, sourceURL: URL) -> Bool {
    if analysis.inferred.isItalicFont { return true }
    let stem = sourceURL.deletingPathExtension().lastPathComponent
    return stem.range(of: "italic", options: .caseInsensitive) != nil
      || stem.range(of: "oblique", options: .caseInsensitive) != nil
  }

  private static func importedStopName(
    _ stop: FontAnalysis.StatValueSnapshot,
    axis: FontAnalysis.AnalyzedAxis,
    fileIsItalic: Bool
  ) -> String {
    let value = resolvedStopValue(stop, axis: axis)
    if axis.tag == "ital" {
      return ItalicStopNaming.importedName(
        recorded: stop.name,
        value: value,
        fileIsItalic: fileIsItalic,
        stopCount: axis.valuesExisting.count
      )
    }
    return WeightStopNaming.importedName(recorded: stop.name, value: value, tag: axis.tag)
  }

  private static func resolvedStopValue(
    _ stop: FontAnalysis.StatValueSnapshot,
    axis: FontAnalysis.AnalyzedAxis
  ) -> Double {
    let raw: Double
    if let value = stop.value { raw = value }
    else if let nominal = stop.nominal { raw = nominal }
    else if axis.roleInferred == .designRecordOnly { raw = 0 }
    else { raw = axis.default }
    return AxisCoordinateFormat.canonical(raw)
  }
}
