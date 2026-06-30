#!/usr/bin/env bash
# Regression grep for VarFontStudio Stable Chrome tokens (HIG polish checklist).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
FAIL=0

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

exit "$FAIL"
