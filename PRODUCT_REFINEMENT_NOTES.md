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
| `SCHEMA.md` | App ↔ vfcommit JSON contract (committed) |
| `docs/` | Short living notes (e.g. axis-naming) |
| `README.md` | Install / build |

## Product-pass refinements (deferred)

1. **Notarization / signing** — alpha 0.1.5; required for polished distribution.
2. **HANDOFF location** — now under `_misc/_archive/VarFontStudio/`; either restore a short `docs/HANDOFF.md` pointer in-repo for contributors, or keep archive-only.
3. **SCHEMA.md** — now committed (public contract).
4. **Overlap with Variable_Instancer** — CLI batch vs Studio GUI; shared naming policies via FontCore / Tools.
5. **`raw_github_urls.txt`** — PushCore noise.

## Status / known open items (2026-10 migration review)

- `swift test`: all pass except 2 **live-font** tests (`testRobotoFlexLiveImportProducesInstances`, `testRobotoFlexWriteRoundTrip`). They hard-code the grid for one Roboto Flex build (`[9, 1]` / 9 instances); the Roboto Flex found on the dev machine yields `[10, 2]` / 20. Pin a specific font version (or relax assertions) before relying on them. On a new machine they skip if no Roboto Flex is found (`fixtures/fonts/README.md`).
- `fixtures/` (JSON examples used by most tests) was accidentally removed in the declutter commit `6dc5ead`; restored.
- Fresh-machine build: `swift test` / `swift build` from repo root; Python helpers under `Tools/` are exercised via their own pytest paths in README. No FontCore dependency.
- Not started: signing/notarization, DMG pipeline beyond `scripts/build-release.sh`.

## Do not lose

- SCHEMA pipeline: FontAnalysis → ProjectDocument → InstancePlan → CommitRequest/Result.
- Tools pytest paths in README.
- Archive Design HTML / instance-coord presentation if iterating UI offline.
