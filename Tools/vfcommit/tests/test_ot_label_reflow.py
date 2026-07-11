"""Tests for OpenType label nameID reflow."""

from __future__ import annotations

import copy
import unittest
from pathlib import Path

from fontTools.ttLib import TTFont

from vfcommit_lib.ot_label_reflow import (
    apply_ot_reflow,
    build_ot_reflow_plan,
    build_reflow_pre_wipe_protected,
    classify_name_ids,
    detect_reflow_blockers,
    patch_ot_label_sites,
    pre_wipe_for_reflow,
    scan_ot_label_sites,
)
from vfcommit_lib.ot_label_scanner import scan_ot_label_nameids
from vfcommit_lib.request_bridge import axis_defs_from_request
from vfcommit_lib.stat_builder import _wipe_existing_table_data

from live_font_fixture import resolve_playfair_roman


class OTLabelReflowTests(unittest.TestCase):
    def _playfair(self) -> TTFont:
        path = resolve_playfair_roman()
        if path is None:
            self.skipTest("Playfair Roman VF not on disk")
        return TTFont(str(path), lazy=False)

    def test_grouped_scan_playfair(self) -> None:
        font = self._playfair()
        groups = scan_ot_label_sites(font)
        self.assertGreaterEqual(len(groups), 5)
        flat = scan_ot_label_nameids(font)
        self.assertEqual(len(groups), len({rec.name_id for rec in flat}))

    def test_build_plan_deterministic(self) -> None:
        groups = {763: [], 764: [], 765: []}
        first = build_ot_reflow_plan(groups)
        second = build_ot_reflow_plan(groups)
        self.assertEqual(first, {763: 256, 764: 257, 765: 258})
        self.assertEqual(first, second)

    def test_duplicate_registration_patch(self) -> None:
        font = self._playfair()
        groups = scan_ot_label_sites(font)
        first_key = next(iter(groups))
        sites = groups[first_key]
        duplicate = copy.deepcopy(sites[0].feature_record)
        font["GSUB"].table.FeatureList.FeatureRecord.append(duplicate)
        groups = scan_ot_label_sites(font)
        self.assertGreater(len(groups[first_key]), 1)
        mapping = build_ot_reflow_plan(groups)
        pre_wipe_for_reflow(
            font,
            build_reflow_pre_wipe_protected(font, groups, []),
        )
        apply_ot_reflow(font, mapping, groups)
        new_id = mapping[first_key]
        refreshed = scan_ot_label_sites(font)
        self.assertIn(new_id, refreshed)
        self.assertGreater(len(refreshed[new_id]), 1)
        for site in refreshed[new_id]:
            self.assertEqual(site.name_id, new_id)

    def test_pre_wipe_then_reflow_playfair(self) -> None:
        font = self._playfair()
        axes_json = [
            {
                "tag": "opsz",
                "display_name": "Optical size",
                "min": 5,
                "default": 5,
                "max": 1200,
                "role": "instance",
                "values": [
                    {"id": "o1", "value": 5, "name": "Micro", "elidable": False, "stat_format": 1},
                ],
            }
        ]
        axis_defs = axis_defs_from_request(axes_json)
        groups = scan_ot_label_sites(font)
        former_763 = font["name"].getDebugName(763)
        self.assertIsNotNone(former_763)
        pre_wipe_for_reflow(
            font,
            build_reflow_pre_wipe_protected(font, groups, axis_defs),
        )
        self.assertIsNone(font["name"].getDebugName(256))
        mapping = build_ot_reflow_plan(groups)
        end = apply_ot_reflow(font, mapping, groups)
        self.assertEqual(font["name"].getDebugName(256), former_763)
        self.assertEqual(end, 260)
        ss05 = [
            rec
            for rec in font["GSUB"].table.FeatureList.FeatureRecord
            if rec.FeatureTag == "ss05"
        ][0]
        self.assertEqual(ss05.Feature.FeatureParams.UINameID, 256)

    def test_shared_id_blocker(self) -> None:
        classification = type(
            "C",
            (),
            {"ot_ids": {300}, "stat_fvar_ids": {300}},
        )()
        blockers = detect_reflow_blockers(classification)  # type: ignore[arg-type]
        self.assertTrue(blockers)


if __name__ == "__main__":
    unittest.main()
