#!/usr/bin/env bash
# Regression grep for VarFontStudio Stable Chrome tokens (HIG polish + token propagation).
#
# Color system guidance: StudioDesign.swift → "Color system (semantic marks)".
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
FAIL=0

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) is not installed — every check below would silently report OK without checking anything." >&2
  echo "Install it first (e.g. 'brew install ripgrep' on macOS, 'apt-get install ripgrep' on Ubuntu)." >&2
  exit 2
fi
# Paths allowed to use raw system fonts / one-off literals (documented exceptions).
ALLOW_FONTS=(
  --glob '!StudioDesign.swift'
  --glob '!WorkspaceDropOverlay.swift'
  --glob '!AxisTreePanel.swift'
  --glob '!ProjectToolbar.swift'
  --glob '!NamingOrderChainFooter.swift'
)
ALLOW_SURFACES=(
  --glob '!StudioDesign.swift'
)

check() {
  local label="$1"
  shift
  if "$@"; then
    echo "FAIL: $label"
    FAIL=1
  else
    echo "OK: $label"
  fi
}

check "no roundedBorder outside StudioDesign" \
  rg -q 'roundedBorder' Views --glob '!StudioDesign.swift'

check "no raw TextField outside StudioDesign" \
  rg -q '\bTextField\(' Views --glob '!StudioDesign.swift'

check "no 1.5px strokes" \
  rg -q 'lineWidth: 1\.5' Views

check "no padding.top 1 hacks" \
  rg -q 'padding\(\.top, 1\)' Views --glob '!StudioDesign.swift'

check "no showsSelectionStroke" \
  rg -q 'showsSelectionStroke' Views

check "no Color(red: literals outside StudioDesign" \
  rg -q 'Color\(red:' Views --glob '!StudioDesign.swift'

check "no preferredColorScheme outside app root" \
  rg -q 'preferredColorScheme' Views

check "no raw accentColor outside StudioDesign" \
  rg -q 'Color\.accentColor' Views --glob '!StudioDesign.swift'

check "no raw .font(.system outside allowlist" \
  rg -q '\.font\(\.system' Views "${ALLOW_FONTS[@]}"

check "no primary.opacity surfaces outside allowlist" \
  rg -q 'primary\.opacity\(0\.' Views "${ALLOW_SURFACES[@]}"

check "no removed scrollGutter token" \
  rg -q 'scrollGutter' Views

check "no axisValue text color outside StudioDesign" \
  rg -q '\.foregroundStyle\(StudioColors\.axisValue\)' Views --glob '!StudioDesign.swift'

check "no codeForeground text color outside StudioDesign" \
  rg -q '\.foregroundStyle\(StudioColors\.codeForeground\)' Views --glob '!StudioDesign.swift'

check "no clarifierForeground text color outside StudioDesign" \
  rg -q '\.foregroundStyle\(StudioColors\.clarifierForeground\)' Views --glob '!StudioDesign.swift'

check "no canvas tokens outside FontPreviewPanel" \
  rg -q 'StudioColors\.canvas' Views --glob '!StudioDesign.swift' --glob '!FontPreviewPanel.swift'

check "no raw Color.red/green/orange/yellow text or fills outside StudioDesign" \
  rg -q '\b(?:foregroundStyle|foregroundColor|background)\(\s*Color\.(red|green|orange|yellow)\b' Views --glob '!StudioDesign.swift'

# --- Advisory: .tertiary/.quaternary foregroundStyle outside StudioDesign (Phase B backlog tracker) ---
# Not yet a hard gate. The contrast/hierarchy audit found ~30 pre-existing instances of
# .tertiary/.quaternary sitting on readable (non-decorative) Text — column headers, row
# captions, status chrome — pending the Phase B contrast pass. This regex is a coarse proxy
# (it can't distinguish Text from other views), so it stays informational until that pass
# lands. Once it does, convert this to a `check` gate with a small decorative allowlist
# (chevrons, separators, disabled-adjacent chrome — see COLOR_OUTLINE.md "Muted" row).
TERTIARY_COUNT="$(rg -c '\.foregroundStyle\(\.(tertiary|quaternary)\)' Views --glob '!StudioDesign.swift' 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')"
echo "INFO: ${TERTIARY_COUNT} occurrence(s) of .tertiary/.quaternary foregroundStyle outside StudioDesign.swift (Phase B backlog tracker — not gated yet)"

exit "$FAIL"
