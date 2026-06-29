# vfcommit

Self-contained Python helper for VarFontStudio save/export. Vendored from
FontCore (STAT/fvar/nameID modules only) so it can be bundled with PyInstaller
later without depending on the monorepo.

## Layout

```
vfcommit/
  vfcommit.py           CLI entry (stdin/stdout JSON)
  vfcommit_lib/
    ot_label_scanner.py   GSUB/GPOS UINameID scan
    nameid_allocator.py   NameID plan + collision check
    stat_builder.py       fvar/STAT/name write
    name_policies.py      PostScript + variable-token helpers (slim)
    string_utils.py       string helpers
    logging_config.py     minimal logging
    request_bridge.py     CommitRequest → AxisDef
    engine.py             dry-run + write orchestration
  tests/
  requirements.txt
```

## Usage

```bash
cd VarFontEditor/Tools/vfcommit
pip install -r requirements.txt

# Dry-run from fixture (source_path must exist on disk)
python vfcommit.py ../../fixtures/examples/playfair-roman-commit-request.json --pretty

# Pipe JSON
cat request.json | python vfcommit.py
```

## Contract

See `VarFontEditor/SCHEMA.md` for `CommitRequest` / `CommitResult` fields.

v0 supports `dry_run: true` (plan summary, no file write) and `dry_run: false`
(writes `output_path`).

## Not included (future)

- Full name-table reflow (low IDs, family renames) — see `EXPORT_DESIGN_NOTES.md`
- Interactive wipe prompts (`confirm_wipe_and_rebuild` is disabled)
