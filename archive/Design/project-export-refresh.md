# Project export refresh — design

Companion to `instancer-decisions.md`. Defines what happens when Review export succeeds,
the Review window closes, and the user returns to the main app.

## Principle

**Export is a project milestone, not just a file write.**

When export completes, the main app becomes the source of truth again. The project must
refresh so Studio, Instancer, and the saved `.varf` all agree on which binaries exist on disk
and which file each subsystem reads.

Instancer is an extension of the main app — not a parallel file manager. Confidence to
recommend instancing comes **after** this refresh, not before.

---

## Trigger

```
Review Export succeeds
  → Review window closes (single-font: closeReviewOnSuccess; batch: closeSaveReviewWindow)
  → Main app focused
  → refreshProjectAfterExport(projectID, exportedFontIDs, exportMode)
```

One orchestration hook in `SaveReviewStore` (or `EditorViewModel`) — not scattered UI callbacks.

---

## Export modes

### A — In-place (overwrite originals)

User chose Export to Original / wrote to the same path as `source_path`.

| Field | After refresh |
|-------|----------------|
| `source_path` | Unchanged (same path; new binary content) |
| `import_path` | Unchanged if already set; else set once from pre-export source |
| `output_path` | Same as `source_path` |
| `dirty` | `false` |

**Refresh actions**

1. Invalidate helper cache + re-register security-scoped bookmark for `source_path`.
2. Re-analyze exported font(s) (`FontAnalysisReader.analyze`) — fvar/STAT on disk now match project.
3. Regenerate instance plan; clear “pending until export” rows for those fonts.
4. Reload matching Instancer sessions (`projectID|fontID`) from refreshed paths.
5. Mark project file dirty (`projectFileDirty = true`) so Save Project persists `output_path` and snapshot state — or auto-save when `projectFileURL` is set.

**`.varf` on disk:** Same file, same paths, updated content reference. User Save Project (or auto-save) captures export metadata.

---

### B — Sidecar (patched / new files)

User exported to a new path (e.g. `Playfair-patched.woff2`, package folder, nested `Patched/`).

**Patched files become the project main** — the active working binaries for Studio and Instancer.

| Field | After refresh |
|-------|----------------|
| `import_path` | Set on first export if absent: previous `source_path` (original import anchor) |
| `source_path` | **Promoted** → patched export path |
| `output_path` | Same as new `source_path` (last published = working) |
| `dirty` | `false` |

**Refresh actions**

1. For each exported font: promote path, register bookmark for new `source_path`.
2. Re-analyze from new `source_path`.
3. Regenerate plan; reload Instancer sessions.
4. Mark project dirty / prompt save.

**`.varf` linkage (two explicit outcomes — user or policy chooses):**

| Policy | Behavior |
|--------|----------|
| **B1 — Update same project** (default) | Active session uses promoted paths. Save Project writes updated paths into the existing `.varf`. Original import paths preserved in `import_path`. |
| **B2 — Fork project file** | Save Project As `{name}-patched.varf` beside original; switch active document to fork. Original `.varf` on disk unchanged, still points at import files. |

Default **B1** for flow continuity. Offer **B2** in export success UI: “Save patched copy of project…” when `projectFileURL` already exists and user wants to preserve the pre-export project file literally.

---

## Post-export instancing recommendation

After `refreshProjectAfterExport` completes successfully:

1. **Status bar / toast:** “Export complete — ready to instance static fonts.”
2. **Primary action:** “Instance…” (opens project-scoped Instancer for exported font or whole project).
3. **Show when:**
   - Refresh succeeded (re-analyze OK).
   - At least one exported font has fvar instances Instancer can list.
   - No hard block on Generate for default selection (no all-selected collisions / willFail).

Do **not** block opening Instancer before export. After export, **recommend** with higher confidence because instance source = published binary aligned with project state.

---

## Instances panel — “pending until export”

Before export: mark included planned instances whose keys are absent from fvar on current working file.

After refresh: re-diff against new `source_path` — badges clear when fvar matches plan.

---

## Instancer source (post-pivot)

- Instancer reads **`source_path`** after refresh (promoted for sidecar; same path for in-place).
- Remove standalone BYO file manager; Instancer only via open project.
- `import_path` retained for audit / “re-export from original” (future explicit action).

---

## Schema addition (optional, v1.1)

```json
{
  "source_path": "/path/to/working.woff2",
  "import_path": "/path/to/original.woff2",
  "output_path": "/path/to/working.woff2"
}
```

- `import_path`: first import anchor; never updated after first sidecar promote.
- If omitted, treat first `source_path` at import as implicit import (legacy projects).

---

## Implementation checklist

- [ ] `refreshProjectAfterExport` in `EditorViewModel` / `SaveReviewStore`
- [ ] Sidecar promote paths + `import_path`
- [ ] `performSave` → call refresh hook before dismiss
- [ ] `markProjectFileDirty()` on every successful export
- [ ] Instancer session invalidate + reload
- [ ] Post-export toast + Instance CTA
- [ ] Instances panel pending-until-export badges
- [x] Remove Instancer BYO / standalone entry points (Phase 3)

---

## Open questions

- Auto-save `.varf` on export vs prompt only?
- Batch export: refresh all fonts in one pass; single toast?
- Package export (folder): canonical VF path inside package for promote?
