"""Off-grid Format 4 coords must still allocate names and write fvar instances."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fontTools.ttLib import TTFont

from vfcommit_lib.engine import run_commit
from vfcommit_lib.nameid_allocator import (
    AxisDef,
    AxisValueDef,
    CompoundStatValueDef,
    enumerate_instance_names,
    resolve_axis_value_for_coord,
)
from vfcommit_lib.request_bridge import instance_key

from live_font_fixture import resolve_playfair_roman


class OffGridInstanceKeyTests(unittest.TestCase):
    def test_resolve_synthesizes_missing_format1_stop(self) -> None:
        values_by_tag = {
            "wght": {
                400.0: AxisValueDef(400, "Regular", True),
                700.0: AxisValueDef(700, "Bold", False),
            }
        }
        hit = resolve_axis_value_for_coord("wght", 400.0, values_by_tag)
        self.assertEqual(hit.name, "Regular")
        synth = resolve_axis_value_for_coord("wght", 1.0, values_by_tag)
        self.assertEqual(synth.value, 1.0)
        self.assertEqual(synth.name, "1")

    def test_enumerate_includes_off_grid_keys_with_compound_names(self) -> None:
        axis_defs = [
            AxisDef(
                tag="opsz",
                display_name="Optical size",
                min_value=1,
                default_value=1,
                max_value=100,
                values=[
                    AxisValueDef(1, "Micro", False),
                    AxisValueDef(100, "Poster", False),
                ],
            ),
            AxisDef(
                tag="wght",
                display_name="Weight",
                min_value=1,
                default_value=400,
                max_value=900,
                values=[
                    AxisValueDef(400, "Regular", True),
                    AxisValueDef(700, "Bold", False),
                ],
            ),
        ]
        keys = [
            instance_key({"opsz": 1, "wght": 400}),
            instance_key({"opsz": 1, "wght": 700}),
            instance_key({"opsz": 100, "wght": 400}),
            instance_key({"opsz": 100, "wght": 700}),
            instance_key({"opsz": 1, "wght": 1}),
        ]
        compounds = [
            CompoundStatValueDef(
                id="extrathin-micro",
                axis_indices=[0, 1],
                axis_values=[1.0, 1.0],
                name="Extrathin",
                elidable=False,
                coords={"opsz": 1.0, "wght": 1.0},
            )
        ]
        names = enumerate_instance_names(
            axis_defs,
            naming_order=["opsz", "wght"],
            included_instance_keys=keys,
            compounds=compounds,
        )
        self.assertEqual(len(names), 5)
        self.assertIn("Extrathin", names)

    def test_write_includes_off_grid_compound_instance(self) -> None:
        source = resolve_playfair_roman()
        if source is None:
            self.skipTest("Playfair Roman VF not on disk")

        # Minimal 2×2 grid plus one off-grid shear point (Format 4 style).
        axes = [
            {
                "tag": "opsz",
                "display_name": "Optical size",
                "min": 5,
                "default": 12,
                "max": 12,
                "role": "instance",
                "values": [
                    {"value": 5, "name": "Micro", "elidable": False, "stat_format": 1},
                    {"value": 12, "name": "Text", "elidable": True, "stat_format": 1},
                ],
            },
            {
                "tag": "wdth",
                "display_name": "Width",
                "min": 88,
                "default": 100,
                "max": 100,
                "role": "instance",
                "values": [
                    {"value": 88, "name": "Condensed", "elidable": False, "stat_format": 1},
                    {"value": 100, "name": "Normal", "elidable": True, "stat_format": 1},
                ],
            },
            {
                "tag": "wght",
                "display_name": "Weight",
                "min": 360,
                "default": 400,
                "max": 700,
                "role": "instance",
                "values": [
                    {"value": 400, "name": "Regular", "elidable": True, "stat_format": 1},
                    {"value": 700, "name": "Bold", "elidable": False, "stat_format": 1},
                ],
            },
        ]
        grid_keys = []
        for opsz in (5.0, 12.0):
            for wdth in (88.0, 100.0):
                for wght in (400.0, 700.0):
                    grid_keys.append(
                        instance_key({"opsz": opsz, "wdth": wdth, "wght": wght})
                    )
        # In-range for Playfair wght [360, 900], but not a Format 1 stop.
        off_grid = instance_key({"opsz": 5.0, "wdth": 100.0, "wght": 380.0})
        keys = grid_keys + [off_grid]

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "off-grid-patched.woff2"
            request = {
                "source_path": str(source),
                "output_path": str(out),
                "dry_run": False,
                "allow_in_place": False,
                "naming": {
                    "order": ["opsz", "wdth", "wght"],
                    "elided_fallback": "Regular",
                },
                "stat_design_axis_tags": ["opsz", "wdth", "wght", "ital"],
                "included_instance_keys": keys,
                "compound_stat_values": [
                    {
                        "id": "light-micro",
                        "name": "Micro Light",
                        "elidable": False,
                        "coords": {"opsz": 5.0, "wdth": 100.0, "wght": 380.0},
                        "axis_indices": [0, 1, 2],
                        "axis_values": [5.0, 100.0, 380.0],
                    }
                ],
                "axes": axes,
                "options": {"nameid_strategy": "preserve"},
            }
            result = run_commit(request)
            self.assertTrue(result.get("ok"), result.get("errors"))
            self.assertTrue(
                result.get("validation", {}).get("ok"),
                result.get("validation"),
            )
            font = TTFont(str(out))
            self.assertEqual(len(font["fvar"].instances), len(keys))
            coords_list = [dict(inst.coordinates) for inst in font["fvar"].instances]
            self.assertTrue(
                any(
                    abs(c.get("opsz", 0) - 5.0) < 0.01
                    and abs(c.get("wdth", 0) - 100.0) < 0.01
                    and abs(c.get("wght", 0) - 380.0) < 0.01
                    for c in coords_list
                ),
                coords_list,
            )
            names = {
                font["name"].getDebugName(inst.subfamilyNameID)
                for inst in font["fvar"].instances
            }
            self.assertIn("Micro Light", names)

            # Format 4 locations must survive round-trip (not empty AxisValueRecord).
            axes = [a.AxisTag for a in font["STAT"].table.DesignAxisRecord.Axis]
            format4 = [
                av
                for av in font["STAT"].table.AxisValueArray.AxisValue
                if av.Format == 4
            ]
            self.assertEqual(len(format4), 1)
            records = list(format4[0].AxisValueRecord or [])
            self.assertGreaterEqual(len(records), 2)
            got = {axes[r.AxisIndex]: r.Value for r in records}
            self.assertAlmostEqual(got["opsz"], 5.0, places=3)
            self.assertAlmostEqual(got["wdth"], 100.0, places=3)
            self.assertAlmostEqual(got["wght"], 380.0, places=3)

            format4_nid = int(format4[0].ValueNameID)

            # Dry-run against the patched file must advertise Format 4 name slots
            # (otherwise Save Review falsely shows combination styles as REMOVED).
            dry = dict(request)
            dry["source_path"] = str(out)
            dry["dry_run"] = True
            dry_result = run_commit(dry)
            self.assertTrue(dry_result.get("ok"), dry_result.get("errors"))
            format4_roles = [
                rec
                for rec in (dry_result.get("diff") or {}).get("name_records_planned", [])
                if rec.get("role") == "stat_format4"
            ]
            self.assertEqual(len(format4_roles), 1)
            self.assertEqual(format4_roles[0]["id"], format4_nid)

            # Re-export against the patched file must reuse the Format 4 nameID.
            out2 = Path(tmp) / "off-grid-repatched.woff2"
            request2 = dict(request)
            request2["source_path"] = str(out)
            request2["output_path"] = str(out2)
            result2 = run_commit(request2)
            self.assertTrue(result2.get("ok"), result2.get("errors"))
            font2 = TTFont(str(out2))
            format4_again = [
                av
                for av in font2["STAT"].table.AxisValueArray.AxisValue
                if av.Format == 4
            ]
            self.assertEqual(len(format4_again), 1)
            self.assertEqual(int(format4_again[0].ValueNameID), format4_nid)


if __name__ == "__main__":
    unittest.main()