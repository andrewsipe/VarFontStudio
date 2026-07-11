"""Post-write validation tests for vfcommit output fonts."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from fontTools.ttLib import TTFont

from vfcommit_lib.engine import run_commit
from vfcommit_lib.post_write_validator import ValidationExpectations, validate_written_font
from vfcommit_lib.request_bridge import instance_key

from live_font_fixture import resolve_playfair_roman

_FIXTURE = (
    Path(__file__).resolve().parents[3]
    / "fixtures"
    / "examples"
    / "playfair-roman-commit-request.json"
)


class PostWriteValidationTests(unittest.TestCase):
    def _base_request(self) -> dict:
        if not _FIXTURE.is_file():
            self.skipTest("fixture missing")
        source = resolve_playfair_roman()
        if source is None:
            self.skipTest("Playfair Roman VF not on disk — see fixtures/fonts/README.md")
        request = json.loads(_FIXTURE.read_text(encoding="utf-8"))
        request["source_path"] = str(source)
        return request

    def _assert_validation_ok(self, result: dict) -> None:
        self.assertTrue(result.get("ok"), result.get("errors"))
        validation = result.get("validation")
        self.assertIsNotNone(validation, "write commits should include validation payload")
        assert validation is not None
        self.assertTrue(validation.get("ok"), validation.get("issues"))

    def test_baseline_write_passes_validation(self) -> None:
        request = self._base_request()
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF-validated.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            result = run_commit(request)
            self._assert_validation_ok(result)
            self.assertTrue(output.is_file())

    def test_exclude_instances_still_validates(self) -> None:
        request = self._base_request()
        keys = []
        for opsz in [12]:
            for wdth in [88, 100]:
                for wght in [400, 700]:
                    keys.append(
                        instance_key(
                            {"opsz": float(opsz), "wdth": float(wdth), "wght": float(wght)}
                        )
                    )
        request["included_instance_keys"] = keys

        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF-pruned.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            result = run_commit(request)
            self._assert_validation_ok(result)
            self.assertEqual(len(TTFont(str(output))["fvar"].instances), len(keys))

    def test_rename_stop_passes_validation(self) -> None:
        request = self._base_request()
        for axis in request["axes"]:
            if axis["tag"] == "wght":
                for stop in axis["values"]:
                    if stop["value"] == 700:
                        stop["name"] = "Heavy"

        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF-renamed.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            result = run_commit(request)
            self._assert_validation_ok(result)

    def test_elided_fallback_string_matches(self) -> None:
        request = self._base_request()
        request["naming"]["elided_fallback"] = "Regular"

        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF-efb.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            result = run_commit(request)
            self._assert_validation_ok(result)

            font = TTFont(str(output))
            efb_id = font["STAT"].table.ElidedFallbackNameID
            name = font["name"].getDebugName(efb_id)
            self.assertEqual(name, "Regular")

    def test_dangling_nameid_detected(self) -> None:
        request = self._base_request()
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF-bad.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            result = run_commit(request)
            self.assertTrue(result.get("ok"), result.get("errors"))

            font = TTFont(str(output))
            font["fvar"].instances[0].subfamilyNameID = 65000
            bad_path = Path(tmp) / "PlayfairRomanVF-corrupt.woff2"
            font.save(str(bad_path))

            validation = validate_written_font(
                str(bad_path),
                expectations=ValidationExpectations(
                    instances_written=len(font["fvar"].instances),
                    elided_fallback_name="Regular",
                ),
            )
            self.assertFalse(validation.ok)
            self.assertTrue(
                any(issue.code == "dangling_nameid" for issue in validation.issues)
            )

    @unittest.skipUnless(shutil.which("python3"), "python3 required")
    def test_ttx_round_trip_reload(self) -> None:
        request = self._base_request()
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            result = run_commit(request)
            self._assert_validation_ok(result)

            ttx_path = Path(tmp) / "round.ttx"
            round_path = Path(tmp) / "round.woff2"
            subprocess.run(
                [sys.executable, "-m", "fontTools.ttx", "-o", str(ttx_path), str(output)],
                check=True,
                capture_output=True,
            )
            subprocess.run(
                [sys.executable, "-m", "fontTools.ttx", "-o", str(round_path), str(ttx_path)],
                check=True,
                capture_output=True,
            )

            validation = validate_written_font(
                str(round_path),
                expectations=ValidationExpectations(
                    instances_written=result["summary"]["instances_written"],
                    elided_fallback_name="Regular",
                ),
            )
            self.assertTrue(validation.ok, validation.issues)


    def test_reflow_mode_compacts_ot_labels(self) -> None:
        request = self._base_request()
        request.setdefault("options", {})["nameid_strategy"] = "reflow"
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF-reflow.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            result = run_commit(request)
            self._assert_validation_ok(result)

            font = TTFont(str(output))
            ss05 = [
                rec
                for rec in font["GSUB"].table.FeatureList.FeatureRecord
                if rec.FeatureTag == "ss05"
            ][0]
            self.assertEqual(ss05.Feature.FeatureParams.UINameID, 256)
            self.assertEqual(font["name"].getDebugName(256), "Alternate g")
            opsz_axis = next(ax for ax in font["fvar"].axes if ax.axisTag == "opsz")
            self.assertGreater(opsz_axis.axisNameID, 260)
            self.assertEqual(
                font["STAT"].table.DesignAxisRecord.Axis[0].AxisNameID,
                opsz_axis.axisNameID,
            )
            self.assertIsNone(font["name"].getDebugName(763))


if __name__ == "__main__":
    unittest.main()
