#!/usr/bin/env python3
"""Tests for pruning variable-font labels from static instances."""

from __future__ import annotations

import unittest

from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables import otTables

from vfinstance_lib.engine import _finalize_static_tables, _set_name_id


def _name_ids(font: TTFont) -> set[int]:
    return {record.nameID for record in font["name"].names}


class StaticNamePruningTests(unittest.TestCase):
    def _static_font_with_stat(self) -> TTFont:
        font = TTFont()
        font["name"] = newTable("name")
        for name_id, value in (
            (25, "ExampleVariable"),
            (256, "Weight"),
            (257, "Italic"),
            (264, "Ultra"),
            (265, "Roman"),
            (266, "Regular"),
            (300, "Stylistic Set 1"),
        ):
            font["name"].setName(value, name_id, 3, 1, 0x409)

        font["STAT"] = newTable("STAT")
        stat = otTables.STAT()
        stat.DesignAxisRecord = otTables.AxisRecordArray()
        stat.DesignAxisRecord.Axis = []
        for tag, name_id in (("wght", 256), ("ital", 257)):
            axis = otTables.AxisRecord()
            axis.AxisTag = tag
            axis.AxisNameID = name_id
            axis.AxisOrdering = len(stat.DesignAxisRecord.Axis)
            stat.DesignAxisRecord.Axis.append(axis)

        stat.AxisValueArray = otTables.AxisValueArray()
        stat.AxisValueArray.AxisValue = []
        for axis_index, name_id in ((0, 264), (1, 265)):
            value = otTables.AxisValue()
            value.Format = 1
            value.AxisIndex = axis_index
            value.Flags = 0
            value.ValueNameID = name_id
            value.Value = 0
            stat.AxisValueArray.AxisValue.append(value)
        stat.ElidedFallbackNameID = 266
        font["STAT"].table = stat
        return font

    def test_dropping_stat_prunes_only_its_labels_and_name_id_25(self) -> None:
        font = self._static_font_with_stat()

        _finalize_static_tables(font, keep_stat=False)

        self.assertNotIn("STAT", font)
        self.assertEqual(_name_ids(font), {300})

    def test_keeping_stat_preserves_its_labels_but_removes_name_id_25(self) -> None:
        font = self._static_font_with_stat()

        _finalize_static_tables(font, keep_stat=True)

        self.assertIn("STAT", font)
        self.assertEqual(_name_ids(font), {256, 257, 264, 265, 266, 300})

    def test_static_output_removes_mac_names_and_writes_only_windows_names(self) -> None:
        font = self._static_font_with_stat()
        font["name"].setName("Rocket Ultra", 1, 1, 0, 0)

        _finalize_static_tables(font, keep_stat=True)
        _set_name_id(font, 1, "Rocket Ultra")

        self.assertFalse(any(record.platformID == 1 for record in font["name"].names))
        windows_name = font["name"].getName(1, 3, 1, 0x409)
        self.assertIsNotNone(windows_name)
        self.assertEqual(windows_name.toUnicode(), "Rocket Ultra")


if __name__ == "__main__":
    unittest.main()
