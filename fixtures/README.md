# VarFont Editor fixtures

Example JSON for schema validation, Swift `Codable` tests, and future `vfcommit` round-trips.

See [`../SCHEMA.md`](../SCHEMA.md) for field definitions.

## Analysis snapshots (from real fonts)

| File | Instances (total) |
|------|-------------------|
| `examples/playfair-roman-analysis.json` | 252 |
| `examples/playfair-italic-analysis.json` | 252 |
| `examples/roboto-flex-analysis.json` | 20 |

Each file includes five sample `instances_existing` rows; use `instances_existing_meta.total` for the real count.

Regenerate after font paths change:

```bash
cd "/Users/skymacbook/Documents/Scripting/Good Font Scripts"
python3 VarFontEditor/fixtures/generate_analysis_fixtures.py
```

Edit `FONT_PATHS` at the top of that script if your fonts live elsewhere.

## Hand-authored examples

| File | Purpose |
|------|---------|
| `examples/playfair-family-project.json` | Multi-file Roman + Italic workspace |
| `examples/playfair-roman-instance-plan.json` | Derived preview (truncated) |
| `examples/playfair-roman-commit-request.json` | Commit input (`dry_run: true`) |
| `examples/commit-result-success.json` | Helper output |
| `examples/roboto-flex-project-snippet.json` | Axis roles for 13-axis font |

## Round-trip (planned)

```bash
# vfcommit < examples/playfair-roman-commit-request.json
# regenerate analysis on output path and diff
```
