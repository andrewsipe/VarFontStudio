"""Tests for STAT DesignAxisRecord reordering on commit.

fvar / avar axis order is intentionally locked (variation data is index-parallel).
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from fontTools.ttLib import TTFont

from vfcommit_lib.axis_order_rewriter import reorder_axis_tables
from vfcommit_lib.engine import run_commit
from vfcommit_lib.post_write_validator import ValidationExpectations, validate_written_font

from live_font_fixture import resolve_playfair_roman

_FIXTURE = (
    Path(__file__).resolve().parents[3]
    / "fixtures"
    / "examples"
    / "playfair-roman-commit-request.json"
)


class AxisOrderRewriterTests(unittest.TestCase):
    def test_reorders_design_axes_but_leaves_fvar_order_alone(self) -> None:
        source = resolve_playfair_roman()
        if source is None:
            self.skipTest("Playfair Roman VF not on disk")
        font = TTFont(str(source))
        original_fvar = [ax.axisTag for ax in font["fvar"].axes]
        original_scales = {
            ax.axisTag: (ax.minValue, ax.defaultValue, ax.maxValue)
            for ax in font["fvar"].axes
        }
        design_tags = [ax.AxisTag for ax in font["STAT"].table.DesignAxisRecord.Axis]
        if len(design_tags) < 2:
            self.skipTest("fixture needs multiple axes")
        reversed_tags = list(reversed(design_tags))

        reorder_axis_tables(
            font,
            design_axis_tags=reversed_tags,
            fvar_axis_tags=list(reversed(original_fvar)),
        )

        self.assertEqual(
            [ax.AxisTag for ax in font["STAT"].table.DesignAxisRecord.Axis],
            reversed_tags,
        )
        self.assertEqual([ax.axisTag for ax in font["fvar"].axes], original_fvar)
        for tag, scales in original_scales.items():
            axis = next(ax for ax in font["fvar"].axes if ax.axisTag == tag)
            self.assertEqual(
                (axis.minValue, axis.defaultValue, axis.maxValue),
                scales,
            )

    def test_commit_honors_reordered_design_axis_tags_without_rewriting_fvar(self) -> None:
        if not _FIXTURE.is_file():
            self.skipTest("fixture missing")
        source = resolve_playfair_roman()
        if source is None:
            self.skipTest("Playfair Roman VF not on disk")
        source_font = TTFont(str(source))
        source_fvar = [ax.axisTag for ax in source_font["fvar"].axes]

        request = json.loads(_FIXTURE.read_text(encoding="utf-8"))
        request["source_path"] = str(source)
        design_tags = [axis["tag"] for axis in request["axes"]]
        request["stat_design_axis_tags"] = list(reversed(design_tags))
        request["axes"] = list(reversed(request["axes"]))

        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF-reordered.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            result = run_commit(request)
            self.assertTrue(result.get("ok"), result.get("errors"))
            font = TTFont(str(output))
            written = [ax.AxisTag for ax in font["STAT"].table.DesignAxisRecord.Axis]
            self.assertEqual(written, request["stat_design_axis_tags"])
            fvar_written = [ax.axisTag for ax in font["fvar"].axes]
            self.assertEqual(fvar_written, source_fvar)
            validation = validate_written_font(
                str(output),
                expectations=ValidationExpectations(
                    design_axis_tags=request["stat_design_axis_tags"],
                    fvar_axis_tags=source_fvar,
                ),
            )
            self.assertTrue(validation.ok, validation.issues)


if __name__ == "__main__":
    unittest.main()
