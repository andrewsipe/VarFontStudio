# VarFont Studio — Implementation decisions outline

Status: **approved direction** — awaiting explicit go to implement.

Clarification (2026-07-27): The **Instancer window remains** as a project-scoped auxiliary
window (like Review). We are **not** removing Instancer as a feature or window type. We **are**
removing standalone BYO file loading and limiting **how** users reach Instancer (via main app
project only, with clean-state rules for confidence and Generate — not a separate file manager).

Reference: `project-export-refresh.md`, `instancer-decisions.md` (legacy BYO assumptions superseded).

---

## 1. Product architecture (settled direction)

| Decision | Choice |
|----------|--------|
| Main app role | **File manager** — import, validate, edit policy, save `.varf` |
| Review role | **Export extension** — preview + write patched variable font |
| Instancer role | **Static generation extension** — project-scoped only; no parallel file manager |
| Ideal pipeline | Import → edit → Save `.varf` → Review/export → **project refresh** → recommend Instance |
| Instancing before export | **Allowed** when grid is healthy enough; not blocked at open |
| Instancing after export | **Recommended** with confidence (toast + Instance CTA) |

---

## 2. Already implemented (prior session — not part of pending approval)

These shipped before the file-management pivot:

- Main window shows full scaffold when empty (not blank drop-only screen)
- Main window reopen: `WindowGroup(id: "main")`, focus existing window, dock reopen
- Instancer empty = unpopulated chrome (not ContentUnavailable splash)
- Status bar chip during background generate (click reopens Instancer)
- Quit warning when instancing in progress
- `+ Add project…` / `+ Add file…` on project/file rows
- Window menu lists open projects (focus + activate tab)
- Shared empty-state copy (`StudioEmptyCopy`)
- Export does **not** yet mark project dirty; Instancer still reads import path only; no post-export refresh

---

## 3. Decisions pending implementation

### 3A — Instancer: project-only access (window stays)

| Decision | Choice |
|----------|--------|
| Instancer **window** | **Keep** — separate auxiliary window per project (like Review) |
| Standalone / empty Instancer | **Remove** — no “Instance without a project” window |
| Open / drag-drop **inside** Instancer | **Remove** — fonts enter only via main app |
| Entry points (toolbar, ⌃⌘5, File menu) | Open **project-scoped** Instancer when allowed |
| Access without project | **Disabled** — hard gate (no fonts loaded in Studio) |
| Access with dirty / unexported file | **Allowed** if sufficiently **clean** (see §3B) |
| Instancer window model | One window per project (`project\|{id}`), tabs per font |
| Custom Instancer rows | Keep session-local (unchanged) |
| “Fix in Studio” | Always available for project fonts |

**Removes:** BYO bookmarks, Instancer-local file picker, standalone lifecycle — **not** the Instancer window itself.

---

### 3B — “Clean enough” for Instancer access

| Decision | Choice |
|----------|--------|
| Require export before Instance **open** | **No** |
| Require `font.dirty == false` to **open** | **No** |
| Open Instancer | Requires project + font(s) via main app; **clean enough** = no grid state that would prevent *any* viable instancing (e.g. all included instances blocked / duplicate composed names among included rows) |
| Hard block **Generate** | Instancer rules: `willFail`, collisions on selection |
| After export + refresh | Recommend Instance with confidence (toast + CTA) |
| vfinstance strictness | Assume lax; don’t mirror full Studio preflight in Instancer |

---

### 3C — Instances panel vs Instancer (different data sources)

| Decision | Choice |
|----------|--------|
| Instances panel | Built from axis tree + naming policy (planned instances) |
| Instancer rows | Built from **fvar named instances** in binary on disk |
| UI indicator | Mark panel rows **“After export”** when included planned key ∉ fvar on working file |
| Filter | Optional “Pending export” chip in Instances panel |
| After export refresh | Badges clear when fvar matches plan |

---

### 3D — File pointers per font (schema)

| Field | Role |
|-------|------|
| `import_path` | **New (optional).** First file brought into project; never moved after sidecar promote |
| `source_path` | **Working binary** — what Studio re-analyzes, Review commits from, Instancer reads **after refresh** |
| `output_path` | Last successful export path; after refresh aligns with `source_path` |
| `dirty` | Project edits not yet reflected in working binary |

Legacy projects: no `import_path` → treat original import as implicit.

---

### 3E — Post-export project refresh (core new behavior)

**Trigger:** Review export succeeds → Review closes → main app → `refreshProjectAfterExport(...)`.

#### Mode A — In-place overwrite

- `source_path` unchanged (content on disk updated)
- `output_path` = `source_path`
- `dirty` = false
- Re-analyze, invalidate cache, reload Instancer sessions
- Mark `.varf` dirty (or auto-save)

#### Mode B — Sidecar / patched files

- **Promote** patched export → `source_path` (project main)
- Set `import_path` once from previous `source_path`
- `output_path` = new `source_path`
- Same refresh actions as Mode A

#### `.varf` on disk after sidecar

| Policy | Default? | Behavior |
|--------|----------|----------|
| **B1 — Update same project** | **Yes** | Active session uses promoted paths; Save Project updates existing `.varf` |
| **B2 — Fork project file** | Optional UI | Save As `{name}-patched.varf`; original `.varf` file unchanged on disk |

#### Post-export UX

- Toast: “Export complete — ready to instance static fonts.”
- Prominent **Instance…** action when refresh OK and fvar instances exist

---

### 3F — Export persistence fix (bug / gap today)

| Decision | Choice |
|----------|--------|
| After successful export | **Mark `projectFileDirty = true`** (export updates `output_path` in memory today but often lost on quit) |
| Auto-save `.varf` on export | **Open question** (see §5) |

---

### 3G — Review commit input after sidecar promote

| Decision | Choice |
|----------|--------|
| vfcommit reads | **`source_path`** (after promote = patched file) |
| Re-export from original import | **Future** explicit action using `import_path`; not v1 |

---

## 4. Implementation phases (proposed order)

### Phase 1 — Export refresh + paths (highest value, enables pipeline story)

1. Add `import_path` to `FontDocument` + schema doc
2. `refreshProjectAfterExport` hook from `performSave`
3. In-place refresh (re-analyze, cache, Instancer reload, mark project dirty)
4. Sidecar promote + `import_path`
5. Post-export toast + Instance CTA

### Phase 2 — Instances panel pending badges

1. Diff planned included keys vs fvar on working file
2. Row badge + optional filter

### Phase 3 — Instancer project-only access

1. Remove BYO / standalone **entry** and Instancer-local file open + drop
2. Rewire menus, toolbar, shortcuts → project-scoped window
3. Gate open when no project/fonts; clean-state check per §3B
4. Update `instancer-decisions.md` §1 (BYO no longer first-class)

### Phase 4 — Polish

- [x] Status bar minimum height + “Ready” when empty
- Auto-save vs prompt after export (if decided) — deferred (mark dirty only)
- B2 “Save patched copy of project…” in export success UI (if decided) — deferred
- Batch export: single refresh pass + one toast — deferred
- [x] **Instancer visual design pass:** align chrome, typography, spacing, panels, and empty states with `StudioDesign` / Review / main app

---

## 5. Open questions — need your call before implement

| # | Question | Options |
|---|----------|---------|
| 1 | **Auto-save `.varf` on export?** | A) Mark dirty only — user Save Project · B) Auto-save when `projectFileURL` exists |
| 2 | **Sidecar default `.varf` policy** | Confirm **B1** default; add B2 button in export success UI now or later? |
| 3 | **Phase order** | OK to do Phase 1 before Phase 3 (refresh before removing BYO)? Recommended yes. |
| 4 | **Package/folder export** | Canonical single VF path inside package for promote — defer or handle in Phase 1? |
| 5 | **Persist Instancer selection on quit** | Still deferred? |
| 6 | **Block Instance open** when zero fonts / no project | **Hard disable** menu/toolbar (confirmed) |
| 7 | **Instancer window** | **Keep**; remove BYO loading only (confirmed) |

---

## 6. Explicitly out of scope (unless you expand)

- Merging Studio instance grid with Instancer row list
- Pushing custom Instancer rows into axis tree automatically
- Project-managed `fonts/` folder bundle (copy-on-import) — future packaging model
- Requiring full axis-conflict resolution before Instance open
- CLI / standalone Instancer outside the app

---

## 7. Files likely touched (estimate)

| Area | Files |
|------|-------|
| Schema | `SchemaProjectDocument.swift`, `SCHEMA.md`, `ProjectDocumentStore.swift` |
| Export refresh | `SaveReviewStore+Orchestration.swift`, new `EditorViewModel+ExportRefresh.swift` (or similar) |
| Instancer | `InstancerStore.swift`, `EditorViewModel+Instancer.swift`, `InstancerWindow.swift` |
| UI | `InstanceListPanel.swift`, `MainEditorView.swift`, `VarFontStudioApp.swift` |
| Docs | `instancer-decisions.md`, `project-export-refresh.md` |

---

## 8. Approval checklist

Before implementation, confirm:

- [ ] Architecture: main / Review / Instancer roles as §1
- [x] Remove standalone Instancer (§3A)
- [ ] Sidecar promote patched → `source_path` (§3E Mode B)
- [ ] In-place refresh without path change (§3E Mode A)
- [ ] B1 default for `.varf`; B2 optional/later
- [ ] `import_path` schema addition
- [ ] Mark project dirty on export (minimum); auto-save TBD
- [ ] Pending-until-export badges in Instances panel
- [ ] Phase order §4
- [ ] Answers to §5 open questions
