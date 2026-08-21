# Product refinement notes — VarFontStudio

Captured during the 2026-08-21 declutter pass. Use for a later product/release pass. **Not** user-facing docs.

## What was decluttered

| Change | Why |
|--------|-----|
| Removed `dist/` (~33 MB) | Gitignored release zips; rebuild via `./scripts/build-release.sh` |
| Removed `.build/` (~228 MB) | Gitignored SwiftPM/Xcode build products |
| Removed `default.profraw` | Profiling junk |
| Moved former `archive/` → `_misc/_archive/VarFontStudio/` | Design HTML, HANDOFF, fixtures, export notes — already gitignored; consolidated with monorepo archive for backup-drive move |

## Active product tree (keep)

| Path | Role |
|------|------|
| `Apps/`, `Sources/`, `Tests/` | Swift app + packages |
| `Tools/` | `vfcommit` / `vfinstance` Python helpers |
| `Package.swift`, `VarFontStudio.xcworkspace` | Build |
| `scripts/`, `packaging/` | Release |
| `SCHEMA.md` | App ↔ vfcommit JSON contract (gitignored from remote push; keep locally) |
| `docs/` | Short living notes (e.g. axis-naming) |
| `README.md` | Install / build |

## Product-pass refinements (deferred)

1. **Notarization / signing** — alpha 0.1.5; required for polished distribution.
2. **HANDOFF location** — now under `_misc/_archive/VarFontStudio/`; either restore a short `docs/HANDOFF.md` pointer in-repo for contributors, or keep archive-only.
3. **SCHEMA.md** — gitignored today; decide if schema is public contract (commit it) or private.
4. **Overlap with Variable_Instancer** — CLI batch vs Studio GUI; shared naming policies via FontCore / Tools.
5. **`raw_github_urls.txt`** — PushCore noise.

## Do not lose

- SCHEMA pipeline: FontAnalysis → ProjectDocument → InstancePlan → CommitRequest/Result.
- Tools pytest paths in README.
- Archive Design HTML / instance-coord presentation if iterating UI offline.
