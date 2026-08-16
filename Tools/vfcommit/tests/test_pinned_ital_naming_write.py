"""Regression: naming-axis ital that still exists in fvar must be filled on write."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fontTools.ttLib import TTFont

from vfcommit_lib.engine import run_commit

RESAN_ITALIC = Path(
    "/Users/skymacbook/Downloads/_Fonts/OTF/Type/ResanDisplay-VariableItalic.ttf"
)


class TestPinnedItalNamingAxisWrite(unittest.TestCase):
    def test_design_record_ital_still_in_fvar_writes_coordinates(self) -> None:
        if not RESAN_ITALIC.is_file():
            self.skipTest("ResanDisplay-VariableItalic.ttf not on disk")

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "ResanDisplay-VariableItalic-patched.ttf"
            request = {
                "source_path": str(RESAN_ITALIC),
                "output_path": str(out),
                "dry_run": False,
                "allow_in_place": False,
                "naming": {
                    "order": ["@pshyphen", "wght", "ital"],
                    "elided_fallback": "Regular",
                },
                "file_stat_registration": {"ital": -12.0},
                "stat_design_axis_tags": ["wght", "ital"],
                "included_instance_keys": [
                    "wght:300",
                    "wght:400",
                    "wght:600",
                    "wght:700",
                    "wght:900",
                ],
                "axes": [
                    {
                        "tag": "wght",
                        "min": 300,
                        "default": 300,
                        "max": 900,
                        "role": "instance",
                        "values": [
                            {
                                "value": 300,
                                "name": "Display Light",
                                "elidable": False,
                                "stat_format": 1,
                            },
                            {
                                "value": 400,
                                "name": "Display",
                                "elidable": False,
                                "stat_format": 3,
                                "linked_value": 700,
                            },
                            {
                                "value": 600,
                                "name": "Display Semibold",
                                "elidable": False,
                                "stat_format": 1,
                            },
                            {
                                "value": 700,
                                "name": "Display Bold",
                                "elidable": False,
                                "stat_format": 1,
                            },
                            {
                                "value": 900,
                                "name": "Display Black",
                                "elidable": False,
                                "stat_format": 1,
                            },
                        ],
                    },
                    {
                        "tag": "ital",
                        "min": -12,
                        "default": -12,
                        "max": -12,
                        "role": "design_record_only",
                        "values": [
                            {
                                "value": -12,
                                "name": "Italic",
                                "elidable": False,
                                "stat_format": 1,
                            }
                        ],
                    },
                ],
                "options": {"nameid_strategy": "preserve"},
            }

            result = run_commit(request)
            self.assertTrue(result.get("ok"), result.get("errors"))
            self.assertTrue(out.is_file())

            written = TTFont(str(out))
            self.assertEqual(
                [axis.axisTag for axis in written["fvar"].axes],
                ["wght", "ital"],
            )
            self.assertEqual(len(written["fvar"].instances), 5)
            for inst in written["fvar"].instances:
                self.assertIn("ital", inst.coordinates)
                self.assertEqual(inst.coordinates["ital"], -12.0)
                name = written["name"].getDebugName(inst.subfamilyNameID) or ""
                self.assertIn("Italic", name)


if __name__ == "__main__":
    unittest.main()
