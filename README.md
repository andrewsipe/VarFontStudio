# VarFont Studio

macOS app for planning variable-font instances, naming, and exporting patched fonts.

**Requires:** macOS 14 (Sonoma) or later, Apple Silicon or Intel.

## Install

Download the latest zip from [Releases](https://github.com/andrewsipe/VarFontStudio/releases), unzip, drag **VarFontStudio.app** into Applications, then run **Allow First Launch** (alpha builds are not notarized yet).

## Build from source

1. Clone this repo
2. Open `VarFontStudio.xcworkspace`
3. Select the **VarFontStudio** scheme and run (⌘R)

Tests:

```bash
swift test
cd Tools/vfcommit && python3 -m pytest tests -q
cd Tools/vfinstance && python3 -m pytest tests -q
```

Release zips: `./scripts/build-release.sh`

## Where things stand

Alpha **0.1.5**. Core workflow — instance grid, naming, Review, and STAT/fvar/name export — is in active use. Signed/notarized distribution is not set up yet.
