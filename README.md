# VarFont Editor

Native macOS variable font instance editor (**VarFont Studio**, alpha) and Swift planning engine (**VarFontCore**).

Plan axis stops → generate instance grids → tune naming → preview in **Save review** → write patched fonts via bundled **vfcommit**. Workspace projects save as **`.varf`** JSON (legacy **`.varfont`** still opens).

**Start here:** [HANDOFF.md](HANDOFF.md) — product intent, alpha status, what's done, what's outstanding, and how to run the app.

| Doc | Contents |
|-----|----------|
| [HANDOFF.md](HANDOFF.md) | Project status and handoff |
| [SCHEMA.md](SCHEMA.md) | JSON schema v1 (FontAnalysis → Project → Plan → Commit) |
| [EXPORT_DESIGN_NOTES.md](EXPORT_DESIGN_NOTES.md) | Export design notes; OT label reflow (partially shipped) |

**Run the app:** open `VarFontStudio.xcworkspace` → scheme **VarFontStudio** → My Mac.

**Tests:** `swift test` from this directory.

## Download (alpha)

Pre-built **VarFont Studio.app** zips are attached to [GitHub Releases](https://github.com/andrewsipe/VarFontEditor/releases). No Xcode required.

1. Download the latest `VarFontStudio-*.zip` (check the `arm64` or `x86_64` suffix matches your Mac).
2. Unzip and drag **VarFont Studio.app** to Applications.
3. **First launch:** if macOS says the app is from an unidentified developer, right-click the app → **Open** → **Open** again.
4. Requires **macOS 14+**. The release bundle includes Python + fontTools for Save; no separate install needed.

To build a release zip locally:

```bash
cd VarFontEditor
chmod +x scripts/build-release.sh scripts/bundle-python-runtime.sh
./scripts/build-release.sh
```

Output: `dist/VarFontStudio-<version>-*.zip`

Tag `v0.1.0` (etc.) on GitHub to trigger the release workflow automatically.
