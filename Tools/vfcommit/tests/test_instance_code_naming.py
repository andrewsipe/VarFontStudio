"""Tests for Univers-style @code naming composition."""

from __future__ import annotations

import unittest

from vfcommit_lib.nameid_allocator import (
    CODE_TOKEN,
    AxisValueDef,
    PSHYPHEN_TOKEN,
    compose_instance_code,
    compose_name_from_order,
    compose_postscript_style_from_order,
    sanitize_instance_code,
)
from vfcommit_lib.request_bridge import axis_defs_from_request


class InstanceCodeNamingTests(unittest.TestCase):
    def test_sanitize(self) -> None:
        self.assertEqual(sanitize_instance_code("341"), "34")
        self.assertEqual(sanitize_instance_code("W1!"), "W1")
        self.assertIsNone(sanitize_instance_code(""))
        self.assertIsNone(sanitize_instance_code("!!"))
        self.assertIsNone(sanitize_instance_code(None))

    def test_compose_univers_style_with_elided_width(self) -> None:
        axes_json = [
            {
                "tag": "wght",
                "role": "instance",
                "values": [
                    {"value": 700, "name": "Bold", "elidable": False, "code": "3"},
                ],
            },
            {
                "tag": "wdth",
                "role": "instance",
                "values": [
                    {"value": 100, "name": "Normal", "elidable": True, "code": "4"},
                ],
            },
            {
                "tag": "ital",
                "role": "design_record_only",
                "values": [
                    {"value": 1, "name": "Italic", "elidable": False, "code": "1"},
                ],
            },
        ]
        combo = {
            "wght": AxisValueDef(700, "Bold", False, code="3"),
            "wdth": AxisValueDef(100, "Normal", True, code="4"),
        }
        registration = {"ital": 1.0}
        self.assertEqual(compose_instance_code(axes_json, combo, registration), "341")

        name = compose_name_from_order(
            [PSHYPHEN_TOKEN, CODE_TOKEN, "wght", "wdth", "ital"],
            combo,
            {},
            elided_fallback_name="Regular",
            axes_json=axes_json,
            file_stat_registration=registration,
        )
        self.assertEqual(name, "341 Bold Italic")

    def test_postscript_places_code_relative_to_hyphen(self) -> None:
        axes_json = [
            {
                "tag": "wght",
                "role": "instance",
                "values": [{"value": 700, "name": "Bold", "elidable": False, "code": "3"}],
            }
        ]
        combo = {"wght": AxisValueDef(700, "Bold", False, code="3")}
        style = compose_postscript_style_from_order(
            [CODE_TOKEN, PSHYPHEN_TOKEN, "wght"],
            combo,
            {},
            axes_json=axes_json,
        )
        self.assertEqual(style, "3-Bold")

    def test_compose_file_split_slope_via_registration_ital(self) -> None:
        axes_json = [
            {
                "tag": "wdth",
                "role": "instance",
                "values": [{"value": 80, "name": "Condensed", "elidable": False, "code": "1"}],
            },
            {
                "tag": "wght",
                "role": "instance",
                "values": [{"value": 300, "name": "Light", "elidable": False, "code": "1"}],
            },
            {
                "tag": "ital",
                "role": "design_record_only",
                "values": [
                    {"value": 0, "name": "Roman", "elidable": True, "code": "0"},
                    {"value": 1, "name": "Italic", "elidable": False, "code": "1"},
                ],
            },
        ]
        combo = {
            "wdth": AxisValueDef(80, "Condensed", False, code="1"),
            "wght": AxisValueDef(300, "Light", False, code="1"),
        }
        order = ["@pshyphen", CODE_TOKEN, "wdth", "wght", "ital"]
        self.assertEqual(
            compose_instance_code(axes_json, combo, {"ital": 0.0}, naming_order=order),
            "110",
        )
        self.assertEqual(
            compose_instance_code(axes_json, combo, {"ital": 1.0}, naming_order=order),
            "111",
        )
        self.assertEqual(
            compose_name_from_order(
                order,
                combo,
                {},
                axes_json=axes_json,
                file_stat_registration={"ital": 1.0},
            ),
            "111 Condensed Light Italic",
        )

    def test_request_bridge_reads_code(self) -> None:
        defs = axis_defs_from_request(
            [
                {
                    "tag": "wght",
                    "min": 100,
                    "default": 400,
                    "max": 900,
                    "values": [
                        {"value": 400, "name": "Regular", "elidable": True, "code": "2"},
                    ],
                }
            ]
        )
        self.assertEqual(defs[0].values[0].code, "2")


if __name__ == "__main__":
    unittest.main()
