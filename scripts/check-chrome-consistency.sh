#!/usr/bin/env bash
# Warn-only design-system drift checker for VarFont Studio chrome.
#
# Flags common regressions that reintroduce the visual inconsistencies the shared
# primitives in StudioDesign.swift were built to remove. This is advisory: it always
# exits 0 so it never blocks a build. Wire into CI/pre-commit as an informational step.
#
# Contract (see StudioDesign.swift style-guide blocks):
#   - Dismiss/remove -> StudioDismissButton (never a naked `xmark`)
#   - Overflow menu  -> StudioOverflowMenu   (never the deprecated StudioToolbarIconMenu)
#   - Horizontal chrome insets -> named density tokens (no `panelHorizontal + N`)
#   - Chrome type    -> StudioTypography tokens (avoid ad-hoc text `.font(.system(size:`)
#   - Spacing scale  -> StudioSpacing aliases (or StudioSpace steps). No raw lattice
#     literals (4/6/8/10/12/14/16/20) for structural padding / stack spacing.
#     Micro nudges 0–3pt are allowed at call sites.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIEWS="$ROOT/Apps/VarFontStudio"
DESIGN="Views/StudioDesign.swift"   # primitives legitimately define the raw forms here

if ! command -v rg >/dev/null 2>&1; then
  echo "check-chrome-consistency: ripgrep (rg) not found; skipping." >&2
  exit 0
fi

found=0

report() {
  local title="$1"; shift
  local matches="$1"; shift
  if [[ -n "$matches" ]]; then
    found=1
    echo ""
    echo "WARN: $title"
    echo "$matches" | sed 's/^/  /'
  fi
}

# 1. Naked xmark used as a control (should be StudioDismissButton).
naked_xmark="$(rg -n 'systemName: "xmark"|systemImage: "xmark"' "$VIEWS" -g '*.swift' 2>/dev/null || true)"
report 'naked "xmark" dismiss - use StudioDismissButton(scale:style:)' "$naked_xmark"

# 2. Deprecated overflow menu (should be StudioOverflowMenu).
legacy_menu="$(rg -n 'StudioToolbarIconMenu' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'StudioToolbarIconMenu (deprecated) - use StudioOverflowMenu(scale:)' "$legacy_menu"

# 3. Ad-hoc horizontal chrome inset (should be a named density token).
adhoc_inset="$(rg -n 'panelHorizontal \+ [0-9]' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'panelHorizontal + N - use StudioSpacing.editorChromeInset / previewInset' "$adhoc_inset"

# 4. Ad-hoc TEXT font sizing in call sites (should be a StudioTypography token).
#    Only flags text typography: lines whose preceding non-blank line is NOT an
#    `Image(...)`. Glyph sizing on `Image` is a separate concern (StudioChromeScale
#    / content-specific icons) and is intentionally not flagged here.
adhoc_font="$(rg -l '\.font\(\.system\(size:' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" | while read -r f; do
  awk 'FNR==1{prev=""} /\.font\(\.system\(size:/ && prev !~ /Image\(/ {printf "%s:%d:%s\n", FILENAME, FNR, $0} {if ($0 ~ /[^[:space:]]/) prev=$0}' "$f"
done || true)"
report 'ad-hoc text .font(.system(size:) - prefer a StudioTypography token' "$adhoc_font"

# 5. Ad-hoc structural spacing on the 4pt lattice (should be StudioSpacing / StudioSpace).
#    Micro spacing (0–3pt optical nudges) is intentionally not flagged.
adhoc_sheet="$(rg -n '\.padding\(20\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report '.padding(20) - use StudioSpacing.sheetOuterPadding' "$adhoc_sheet"

adhoc_card="$(rg -n '\.padding\(10\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report '.padding(10) - use StudioSpacing.cardPadding' "$adhoc_card"

adhoc_list="$(rg -n '\.padding\(6\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report '.padding(6) - use StudioSpacing.listInset' "$adhoc_list"

adhoc_hpad="$(rg -n '\.padding\(\.horizontal, 8\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report '.padding(.horizontal, 8) - use StudioSpacing.panelHorizontal' "$adhoc_hpad"

# Directional lattice paddings (4/6/8/10/12/20).
adhoc_dir_pad="$(rg -n '\.padding\(\.(horizontal|vertical|top|bottom|leading|trailing), (4|6|8|10|12|14|16|20|24|28|32)\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'raw lattice directional .padding - use StudioSpacing.* or StudioSpace.xN' "$adhoc_dir_pad"

adhoc_large="$(rg -n '\.padding\((24|28|32)\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report '.padding(24/28/32) - use StudioSpace.x6 / x7 / x8' "$adhoc_large"

adhoc_gap8="$(rg -n 'spacing: 8\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'spacing: 8 - use StudioSpacing.controlGap' "$adhoc_gap8"

adhoc_gap6="$(rg -n 'spacing: 6\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'spacing: 6 - use StudioSpacing.rowGap' "$adhoc_gap6"

adhoc_gap4="$(rg -n 'spacing: 4\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'spacing: 4 - use StudioSpacing.tightGap' "$adhoc_gap4"

adhoc_gap10="$(rg -n 'spacing: 10\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'spacing: 10 - use StudioSpacing.sectionGap' "$adhoc_gap10"

adhoc_gap12="$(rg -n 'spacing: 12\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'spacing: 12 - use StudioSpace.x3 (or a semantic alias)' "$adhoc_gap12"

adhoc_pad5="$(rg -n '\.padding\(\.(horizontal|vertical|top|bottom|leading|trailing), 5\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'raw .padding(..., 5) - use tabChipVerticalPadding / tightGap / instanceRowVertical / toolbarVertical' "$adhoc_pad5"

adhoc_gap5="$(rg -n 'spacing: 5\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'spacing: 5 - use StudioSpacing.tightGap' "$adhoc_gap5"

adhoc_gap16="$(rg -n 'spacing: 16\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'spacing: 16 - use StudioSpace.x4 (or a semantic alias)' "$adhoc_gap16"

echo ""
if [[ "$found" -eq 0 ]]; then
  echo "check-chrome-consistency: clean."
else
  echo "check-chrome-consistency: advisory warnings above (non-blocking)."
fi
exit 0
