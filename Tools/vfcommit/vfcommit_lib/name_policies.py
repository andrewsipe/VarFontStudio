"""PostScript and variable-token helpers (subset copied from FontCore)."""

from __future__ import annotations

import re

from vfcommit_lib.string_utils import is_empty, normalize_empty

RE_VARIABLE_TOKENS = re.compile(r"\b(Variable|VF|GX|Flex)\b", re.I)


def sanitize_postscript(name: str) -> str:
    """Sanitize PostScript-like names for fvar instance strings."""
    name = name.replace(" ", "")
    return re.sub(r"[^A-Za-z0-9\-\._\?\!\&\*]", "-", name)


def strip_variable_tokens(text: str | None) -> str | None:
    """Strip Variable/VF/GX/Flex tokens from family-like strings."""
    text = normalize_empty(text)
    if is_empty(text):
        return None

    s = str(text)
    s, _ = RE_VARIABLE_TOKENS.subn("", s)
    s = re.sub(r"(?i)(?:^|[-_\s])Variable(?:Italic)?(?=$|[-_\s])", " ", s)
    s = re.sub(r"(?i)(?:^|[-_\s])(VF|GX|Flex)(?=$|[-_\s])", " ", s)
    return normalize_empty(s)
