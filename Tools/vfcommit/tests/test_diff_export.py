"""Tests for dry-run diff export."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from vfcommit_lib.diff_export import build_commit_diff
from vfcommit_lib.engine import run_commit
from vfcommit_lib.nameid_allocator import (
    AxisDef,
    AxisValueDef,
    NameIDPlan,
)

_FIXTURE = (
    Path(__file__).resolve().parents[3]
    / "fixtures"
    / "examples"
    / "playfair-roman-commit-request.json"
)


class DiffExportTests(unittest.TestCase):
    def test_build_commit_diff_shapes(self) -> None:
        plan = NameIDPlan(
            protected={},
            axis_value_ids={("wght", 400.0): 280, ("wght", 700.0): 281},
            instance_ids={"Bold": 282},
            axis_name_ids={"wght": 279},
            axis_names={"wght": "Weight"},
            instance_postscript_names={"Bold": "FamilyVF-Bold"},
            instance_postscript_ids={"Bold": 283},
            family_ps_prefix="FamilyVF",
            elided_fallback_name="Regular",
            elided_fallback_id=284,
            free_start=279,
            free_end=284,
        )
        axis_defs = [
            AxisDef(
                tag="wght",
                display_name="Weight",
                min_value=400,
                default_value=400,
                max_value=700,
                values=[
                    AxisValueDef(value=400, name="Regular", elidable=True),
                    AxisValueDef(value=700, name="Bold", elidable=False),
                ],
            )
        ]
        diff = build_commit_diff(plan, axis_defs)
        self.assertEqual(diff["family_ps_prefix"], "FamilyVF")
        self.assertEqual(len(diff["stat_values_planned"]), 2)
        self.assertEqual(len(diff["instances_planned"]), 1)
        self.assertTrue(any(rec["role"] == "instance_subfamily" for rec in diff["name_records_planned"]))

    def test_build_commit_diff_includes_format4_compounds(self) -> None:
        plan = NameIDPlan(
            protected={},
            axis_value_ids={("wght", 400.0): 280},
            instance_ids={"Micro Light": 282},
            axis_name_ids={"wght": 279},
            axis_names={"wght": "Weight"},
            elided_fallback_name="Regular",
            elided_fallback_id=281,
            free_start=279,
            free_end=283,
            compound_value_ids={"micro-light": 283},
            compound_value_names={"micro-light": "Micro Light"},
        )
        axis_defs = [
            AxisDef(
                tag="wght",
                display_name="Weight",
                min_value=400,
                default_value=400,
                max_value=700,
                values=[AxisValueDef(value=400, name="Regular", elidable=True)],
            )
        ]
        diff = build_commit_diff(plan, axis_defs)
        format4 = [
            rec for rec in diff["name_records_planned"] if rec["role"] == "stat_format4"
        ]
        self.assertEqual(len(format4), 1)
        self.assertEqual(format4[0]["id"], 283)
        self.assertEqual(format4[0]["string"], "Micro Light")
        sequenced_roles = [rec["role"] for rec in diff["name_records_sequenced"]]
        self.assertIn("stat_format4", sequenced_roles)
        # Compounds appear before instance subfamily in write order.
        self.assertLess(
            sequenced_roles.index("stat_format4"),
            sequenced_roles.index("instance_subfamily"),
        )

    def test_name_records_sequenced_preserves_build_order(self) -> None:
        plan = NameIDPlan(
            protected={},
            axis_value_ids={("wght", 400.0): 280, ("wght", 700.0): 281},
            instance_ids={"Bold": 282},
            axis_name_ids={"wght": 279},
            axis_names={"wght": "Weight"},
            instance_postscript_names={"Bold": "FamilyVF-Bold"},
            instance_postscript_ids={"Bold": 283},
            family_ps_prefix="FamilyVF",
            elided_fallback_name="Regular",
            elided_fallback_id=284,
            free_start=279,
            free_end=284,
        )
        axis_defs = [
            AxisDef(
                tag="wght",
                display_name="Weight",
                min_value=400,
                default_value=400,
                max_value=700,
                values=[
                    AxisValueDef(value=400, name="Regular", elidable=True),
                    AxisValueDef(value=700, name="Bold", elidable=False),
                ],
            )
        ]
        diff = build_commit_diff(plan, axis_defs)
        sequenced = diff["name_records_sequenced"]
        planned = diff["name_records_planned"]
        self.assertEqual([rec["id"] for rec in sequenced], [279, 280, 281, 284, 282, 283])
        self.assertEqual([rec["id"] for rec in planned], sorted(rec["id"] for rec in sequenced))
        self.assertNotEqual([rec["id"] for rec in sequenced], [rec["id"] for rec in planned])

    def test_dry_run_includes_diff(self) -> None:
        if not _FIXTURE.is_file():
            self.skipTest("fixture missing")
        request = json.loads(_FIXTURE.read_text(encoding="utf-8"))
        if not Path(request["source_path"]).is_file():
            self.skipTest("source font not on disk")
        request["dry_run"] = True
        result = run_commit(request)
        self.assertTrue(result.get("ok"))
        self.assertIn("diff", result)
        diff = result["diff"]
        self.assertIn("name_records_planned", diff)
        self.assertIn("stat_values_planned", diff)
        self.assertIn("instances_planned", diff)


if __name__ == "__main__":
    unittest.main()
