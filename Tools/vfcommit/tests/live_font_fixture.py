"""Resolve live variable-font paths for vfcommit integration tests."""

from __future__ import annotations

import os
from pathlib import Path

_PLAYFAIR_ROMAN_ENV = "VFSTUDIO_PLAYFAIR_ROMAN"
_PLAYFAIR_ITALIC_ENV = "VFSTUDIO_PLAYFAIR_ITALIC"

_PLAYFAIR_ROMAN_CANDIDATES = [
    Path.home() / "Downloads" / "PlayfairRomanVF.woff2",
    Path.home() / "Downloads" / "~Untitled" / "PlayfairRomanVF.woff2",
    Path.home()
    / "Downloads"
    / "~Untitled"
    / "New Folder With Items"
    / "Playfair"
    / "Playfair-Variable-patched.woff2",
    Path.home()
    / "Downloads"
    / "~Untitled"
    / "New Folder With Items"
    / "Playfair"
    / "Playfair-Variable.woff2",
]

_PLAYFAIR_ITALIC_CANDIDATES = [
    Path.home() / "Downloads" / "PlayfairItalicVF.woff2",
    Path.home() / "Downloads" / "~Untitled" / "PlayfairItalicVF.woff2",
    Path.home()
    / "Downloads"
    / "~Untitled"
    / "New Folder With Items"
    / "Playfair"
    / "Playfair-VariableItalic-patched.woff2",
    Path.home()
    / "Downloads"
    / "~Untitled"
    / "New Folder With Items"
    / "Playfair"
    / "Playfair-VariableItalic.woff2",
]

_PLAYFAIR_ROMAN_GLOB_ROOTS = [
    Path.home() / "Downloads" / "~Untitled" / "New Folder With Items" / "Playfair",
    Path.home() / "Downloads" / "~Untitled",
    Path.home() / "Downloads",
]

_PLAYFAIR_ITALIC_GLOB_ROOTS = _PLAYFAIR_ROMAN_GLOB_ROOTS


def _resolve_from_env(env_var: str) -> Path | None:
    raw = os.environ.get(env_var, "").strip()
    if not raw:
        return None
    path = Path(raw).expanduser()
    return path if path.is_file() else None


def _resolve_from_candidates(candidates: list[Path]) -> Path | None:
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def _glob_playfair(root: Path, *, italic: bool) -> Path | None:
    if not root.is_dir():
        return None
    matches: list[Path] = []
    for path in root.rglob("*.woff2"):
        if not path.is_file():
            continue
        name = path.name.lower()
        if "playfair" not in name or "variable" not in name:
            continue
        is_italic = "italic" in name
        if italic != is_italic:
            continue
        matches.append(path)
    if not matches:
        return None
    # Prefer *-patched.woff2 (Studio-updated) over the original download.
    return sorted(matches, key=lambda p: ("-patched" not in p.name.lower(), p.name))[0]


def resolve_playfair_roman() -> Path | None:
    """Return Playfair Roman VF path, or None when not available locally."""
    from_env = _resolve_from_env(_PLAYFAIR_ROMAN_ENV)
    if from_env is not None:
        return from_env
    from_candidates = _resolve_from_candidates(_PLAYFAIR_ROMAN_CANDIDATES)
    if from_candidates is not None:
        return from_candidates
    for root in _PLAYFAIR_ROMAN_GLOB_ROOTS:
        match = _glob_playfair(root, italic=False)
        if match is not None:
            return match
    return None


def resolve_playfair_italic() -> Path | None:
    """Return Playfair Italic VF path, or None when not available locally."""
    from_env = _resolve_from_env(_PLAYFAIR_ITALIC_ENV)
    if from_env is not None:
        return from_env
    from_candidates = _resolve_from_candidates(_PLAYFAIR_ITALIC_CANDIDATES)
    if from_candidates is not None:
        return from_candidates
    for root in _PLAYFAIR_ITALIC_GLOB_ROOTS:
        match = _glob_playfair(root, italic=True)
        if match is not None:
            return match
    return None
