"""Tests for name ID allocation starting at 256."""

from __future__ import annotations

import unittest
from pathlib import Path

from fontTools.ttLib import TTFont

from vfcommit_lib.nameid_allocator import (
    AxisDef,
    AxisValueDef,
    build_allocation_plan,
    compose_name_from_order,
    enumerate_instance_names,
)
from vfcommit_lib.ot_label_scanner import scan_ot_label_nameids
from vfcommit_lib.request_bridge import axis_defs_from_request

_MILGRAM = Path("/Users/skymacbook/Downloads/~Untitled/Milgram-Variable.ttf")


class NameIDAllocatorTests(unittest.TestCase):
    def test_reclaims_from_256_not_after_existing_vf_ids(self) -> None:
        if not _MILGRAM.is_file():
            self.skipTest("Milgram test font not on disk")

        font = TTFont(str(_MILGRAM), lazy=False)
        ot_labels = scan_ot_label_nameids(font)
        axes_json = [
            {
                "tag": "wght",
                "display_name": "Weight",
                "min": 300,
                "default": 400,
                "max": 900,
                "role": "instance",
                "values": [
                    {"id": "w1", "value": 300, "name": "Light", "elidable": False, "stat_format": 1},
                    {"id": "w2", "value": 400, "name": "Regular", "elidable": True, "stat_format": 1},
                    {"id": "w3", "value": 500, "name": "Medium", "elidable": False, "stat_format": 1},
                    {"id": "w4", "value": 700, "name": "Bold", "elidable": False, "stat_format": 1},
                    {"id": "w5", "value": 800, "name": "X-Bold", "elidable": False, "stat_format": 1},
                    {"id": "w6", "value": 900, "name": "Black", "elidable": False, "stat_format": 1},
                ],
            }
        ]
        axis_defs = axis_defs_from_request(axes_json)
        plan = build_allocation_plan(
            font,
            ot_labels,
            axis_defs,
            elided_fallback_name="Regular",
            allocate_postscript_names=True,
            instance_axis_defs=axis_defs,
        )

        self.assertEqual(plan.free_start, 256)
        self.assertGreaterEqual(plan.free_end, 256)
        self.assertLess(plan.free_start, 272, "should not start allocating after old VF name IDs")

        planned_ids = set(plan.axis_name_ids.values())
        planned_ids.update(plan.axis_value_ids.values())
        planned_ids.update(plan.instance_ids.values())
        planned_ids.update(plan.instance_postscript_ids.values())
        planned_ids.add(plan.elided_fallback_id)
        self.assertEqual(min(planned_ids), 256)

    def test_slope_clarifier_appends_to_instance_names(self) -> None:
        axes_json = [
            {
                "tag": "wght",
                "display_name": "Weight",
                "min": 300,
                "default": 400,
                "max": 900,
                "role": "instance",
                "values": [
                    {"id": "w1", "value": 300, "name": "Light", "elidable": False, "stat_format": 1},
                    {"id": "w2", "value": 400, "name": "Regular", "elidable": True, "stat_format": 1},
                    {"id": "w3", "value": 700, "name": "Bold", "elidable": False, "stat_format": 1},
                ],
            }
        ]
        axis_defs = axis_defs_from_request(axes_json)
        names = enumerate_instance_names(
            axis_defs,
            "Regular",
            naming_order=["wght", "@slope"],
            clarifiers={"slope": "Italic"},
        )
        self.assertIn("Light Italic", names)
        self.assertIn("Bold Italic", names)
        self.assertIn("Italic", names)

    def test_compose_name_from_order_interleaves_width_and_slope(self) -> None:
        label = compose_name_from_order(
            ["wght", "@width", "@slope"],
            {
                "wght": AxisValueDef(value=500, name="Medium", elidable=False),
            },
            {"width": "Condensed", "slope": "Italic"},
            "Regular",
        )
        self.assertEqual(label, "Medium Condensed Italic")

    def test_preserves_stat_only_design_axis_name_ids(self) -> None:
        nouveau = Path("/Users/skymacbook/Downloads/~Untitled/NouveauLED-Variable.ttf")
        if not nouveau.is_file():
            self.skipTest("Nouveau LED test font not on disk")

        font = TTFont(str(nouveau), lazy=False)
        ot_labels = scan_ot_label_nameids(font)
        stat = font["STAT"].table
        ital_axis = next(
            ax for ax in stat.DesignAxisRecord.Axis if ax.AxisTag == "ital"
        )
        ital_name_id = ital_axis.AxisNameID
        self.assertGreaterEqual(ital_name_id, 256)

        axes_json = [
            {
                "tag": "wght",
                "display_name": "Weight",
                "min": 0,
                "default": 0,
                "max": 1000,
                "role": "instance",
                "values": [
                    {"id": "w1", "value": 0, "name": "Hair", "elidable": False, "stat_format": 1},
                    {"id": "w2", "value": 400, "name": "Regular", "elidable": True, "stat_format": 1},
                ],
            },
            {
                "tag": "FLOR",
                "display_name": "Flora",
                "min": 0,
                "default": 0,
                "max": 1000,
                "role": "instance",
                "values": [
                    {"id": "f1", "value": 0, "name": "Crocus", "elidable": False, "stat_format": 1},
                ],
            },
        ]
        axis_defs = axis_defs_from_request(axes_json)
        plan = build_allocation_plan(
            font,
            ot_labels,
            axis_defs,
            elided_fallback_name="Regular",
            allocate_postscript_names=True,
            instance_axis_defs=axis_defs,
            family_ps_prefix="NouveauLEDVariable",
        )

        planned_ids = set(plan.axis_value_ids.values())
        planned_ids.update(plan.instance_ids.values())
        planned_ids.update(plan.instance_postscript_ids.values())
        planned_ids.add(plan.elided_fallback_id)
        self.assertNotIn(
            ital_name_id,
            planned_ids,
            "STAT-only ital axis name ID must not be reused for instances or PS names",
        )
        self.assertEqual(
            font["name"].getDebugName(ital_name_id),
            "Italic",
        )


if __name__ == "__main__":
    unittest.main()
