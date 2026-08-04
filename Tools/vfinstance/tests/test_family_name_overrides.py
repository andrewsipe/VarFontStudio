#!/usr/bin/env python3
"""Unit tests for static family name overrides in vfinstance."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock

from vfinstance_lib.engine import (
    NAME_ID_FAMILY,
    NAME_ID_FULL,
    NAME_ID_SUBFAMILY,
    NAME_ID_TYPO_FAMILY,
    NAME_ID_TYPO_SUBFAMILY,
    _apply_name_overrides,
    _resolve_family_name,
    _strip_variable_tokens,
)


class StripVariableTokensTests(unittest.TestCase):
    def test_strips_variable_word(self) -> None:
        self.assertEqual(_strip_variable_tokens("Black Pack Niu Variable"), "Black Pack Niu")

    def test_strips_vf_token(self) -> None:
        self.assertEqual(_strip_variable_tokens("Playfair VF"), "Playfair")

    def test_empty_after_strip(self) -> None:
        self.assertIsNone(_strip_variable_tokens("Variable"))


class ApplyFamilyOverridesTests(unittest.TestCase):
    def _font(self, names: dict[int, str]) -> MagicMock:
        font = MagicMock()
        name = MagicMock()

        def get_name(name_id: int, *platform: int):
            value = names.get(name_id)
            if value is None:
                return None
            record = MagicMock()
            record.toUnicode.return_value = value
            return record

        def set_name(string: str, name_id: int, *platform: int) -> None:
            names[name_id] = string

        name.getName.side_effect = get_name
        name.setName.side_effect = set_name
        font.__getitem__.return_value = name
        return font

    def test_explicit_family_non_ribbi(self) -> None:
        names = {
            NAME_ID_FAMILY: "Black Pack Niu Variable Expanded Black Panic",
            NAME_ID_SUBFAMILY: "Regular",
            NAME_ID_TYPO_FAMILY: "Black Pack Niu Variable",
            NAME_ID_TYPO_SUBFAMILY: "Expanded Black Panic",
            NAME_ID_FULL: "Black Pack Niu Variable Expanded Black Panic",
        }
        font = self._font(names)
        _apply_name_overrides(
            font,
            display_name="Expanded Black Panic",
            postscript_name="BlackPackNiu-ExpandedBlackPanic",
            ps_prefix="BlackPackNiu",
            family_name="Black Pack Niu",
        )
        self.assertEqual(names[NAME_ID_TYPO_FAMILY], "Black Pack Niu")
        self.assertEqual(names[NAME_ID_FAMILY], "Black Pack Niu Expanded Black Panic")
        self.assertEqual(names[NAME_ID_TYPO_SUBFAMILY], "Expanded Black Panic")
        self.assertEqual(names[NAME_ID_FULL], "Black Pack Niu Expanded Black Panic")
        self.assertEqual(names[NAME_ID_SUBFAMILY], "Regular")

    def test_default_strips_variable_from_typo_family(self) -> None:
        names = {
            NAME_ID_FAMILY: "Black Pack Niu Variable",
            NAME_ID_SUBFAMILY: "Regular",
            NAME_ID_TYPO_FAMILY: "Black Pack Niu Variable",
            NAME_ID_TYPO_SUBFAMILY: "Regular",
            NAME_ID_FULL: "Black Pack Niu Variable Regular",
        }
        font = self._font(names)
        self.assertEqual(_resolve_family_name(font, None), "Black Pack Niu")
        _apply_name_overrides(
            font,
            display_name="Regular",
            postscript_name=None,
            ps_prefix="BlackPackNiu",
            family_name=None,
        )
        self.assertEqual(names[NAME_ID_TYPO_FAMILY], "Black Pack Niu")
        self.assertEqual(names[NAME_ID_FAMILY], "Black Pack Niu")
        self.assertEqual(names[NAME_ID_FULL], "Black Pack Niu Regular")


if __name__ == "__main__":
    unittest.main()
