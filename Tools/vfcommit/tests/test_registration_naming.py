"""Tests for registration-aware instance naming in vfcommit."""

from __future__ import annotations

import unittest

from vfcommit_lib.nameid_allocator import (
    AxisDef,
    AxisValueDef,
    compose_name_from_order,
    enumerate_instance_names,
)


def _playfair_roman_axes_json() -> list[dict]:
    return [
        {
            "tag": "wght",
            "display_name": "Weight",
            "min": 400,
            "default": 400,
            "max": 900,
            "role": "instance",
            "values": [
                {"id": "w1", "value": 400, "name": "Regular", "elidable": True, "stat_format": 1},
                {"id": "w2", "value": 700, "name": "Bold", "elidable": False, "stat_format": 3, "linked_value": 400},
                {"id": "w3", "value": 900, "name": "Black", "elidable": False, "stat_format": 1},
            ],
        },
        {
            "tag": "ital",
            "display_name": "Italic",
            "role": "design_record_only",
            "values": [
                {"id": "i0", "value": 0, "name": "Roman", "elidable": True, "stat_format": 1},
                {"id": "i1", "value": 1, "name": "Italic", "elidable": False, "stat_format": 1},
            ],
        },
    ]


class RegistrationNamingParityTests(unittest.TestCase):
    def test_roman_registration_skips_slope_clarifier(self) -> None:
        axes_json = _playfair_roman_axes_json()
        label = compose_name_from_order(
            ["ital", "wght", "@slope"],
            {"wght": AxisValueDef(value=700, name="Bold", elidable=False)},
            {"slope": "Italic"},
            "Regular",
            axes_json=axes_json,
            file_stat_registration={"ital": 0},
        )
        self.assertEqual(label, "Bold")

    def test_wdth_registration_skips_width_clarifier(self) -> None:
        axes_json = _playfair_roman_axes_json() + [
            {
                "tag": "wdth",
                "display_name": "Width",
                "role": "design_record_only",
                "values": [
                    {"id": "w75", "value": 75, "name": "Condensed", "elidable": False, "stat_format": 1},
                ],
            }
        ]
        label = compose_name_from_order(
            ["wght", "wdth", "@width"],
            {"wght": AxisValueDef(value=700, name="Bold", elidable=False)},
            {"width": "Narrow"},
            "Regular",
            axes_json=axes_json,
            file_stat_registration={"wdth": 75},
        )
        self.assertEqual(label, "Bold Condensed")

    def test_roman_enumerated_names_match_planner(self) -> None:
        axes_json = _playfair_roman_axes_json()
        axis_defs = [
            AxisDef(
                tag="wght",
                display_name="Weight",
                min_value=400,
                default_value=400,
                max_value=900,
                values=[
                    AxisValueDef(value=400, name="Regular", elidable=True),
                    AxisValueDef(value=700, name="Bold", elidable=False),
                    AxisValueDef(value=900, name="Black", elidable=False),
                ],
            )
        ]
        names = enumerate_instance_names(
            axis_defs,
            "Regular",
            naming_order=["ital", "wght", "@slope"],
            clarifiers={"slope": "Italic"},
            axes_json=axes_json,
            file_stat_registration={"ital": 0},
        )
        self.assertIn("Regular", names)
        self.assertIn("Bold", names)
        self.assertIn("Black", names)
        self.assertFalse(any("Italic" in name for name in names if name != "Regular"))


if __name__ == "__main__":
    unittest.main()
