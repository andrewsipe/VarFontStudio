#!/usr/bin/env bash
# Warn-only design-system drift checker for VarFont Studio chrome.
#
# Flags common regressions that reintroduce the visual inconsistencies the shared
# primitives in StudioDesign.swift were built to remove. This is advisory: it always
# exits 0 so it never blocks a build. Wire into CI/pre-commit as an informational step.
#
# Contract (see the "Shared chrome contract" block in StudioDesign.swift):
#   - Dismiss/remove -> StudioDismissButton (never a naked `xmark`)
#   - Overflow menu  -> StudioOverflowMenu   (never the deprecated StudioToolbarIconMenu)
#   - Horizontal chrome insets -> named density tokens (no `panelHorizontal + N`)
#   - Chrome type    -> StudioTypography tokens (avoid ad-hoc `.font(.system(size:` in Views)
#   - Structural spacing -> StudioSpacing tokens (no raw 20/10/8 padding, spacing:8)

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

# 5. Ad-hoc structural spacing literals (should be a StudioSpacing token).
#    Structural = sheet outer (20), card content (10), panel horizontal inset (8),
#    inter-control gap (8). Micro spacing (1-5pt local nudges) is intentionally
#    not flagged here.
adhoc_sheet="$(rg -n '\.padding\(20\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report '.padding(20) - use StudioSpacing.sheetOuterPadding' "$adhoc_sheet"

adhoc_card="$(rg -n '\.padding\(10\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report '.padding(10) - use StudioSpacing.cardPadding' "$adhoc_card"

adhoc_hpad="$(rg -n '\.padding\(\.horizontal, 8\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report '.padding(.horizontal, 8) - use StudioSpacing.panelHorizontal' "$adhoc_hpad"

adhoc_gap="$(rg -n 'spacing: 8\)' "$VIEWS" -g '*.swift' 2>/dev/null | rg -v "$DESIGN" || true)"
report 'spacing: 8 - use StudioSpacing.controlGap' "$adhoc_gap"

echo ""
if [[ "$found" -eq 0 ]]; then
  echo "check-chrome-consistency: clean."
else
  echo "check-chrome-consistency: advisory warnings above (non-blocking)."
fi
exit 0
