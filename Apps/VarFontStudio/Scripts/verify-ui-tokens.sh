#!/usr/bin/env bash
# Regression grep for VarFontStudio Stable Chrome tokens (HIG polish + token propagation).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
FAIL=0

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

check "no raw .font(.system outside allowlist" \
  rg -q '\.font\(\.system' Views "${ALLOW_FONTS[@]}"

check "no primary.opacity surfaces outside allowlist" \
  rg -q 'primary\.opacity\(0\.' Views "${ALLOW_SURFACES[@]}"

exit "$FAIL"
