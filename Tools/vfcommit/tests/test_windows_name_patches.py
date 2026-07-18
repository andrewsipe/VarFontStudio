"""Windows English low-ID name patches via vfcommit."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from fontTools.ttLib import TTFont

from vfcommit_lib.engine import run_commit
from live_font_fixture import resolve_playfair_roman

_FIXTURE = (
    Path(__file__).resolve().parents[3]
    / "fixtures"
    / "examples"
    / "playfair-roman-commit-request.json"
)


class WindowsNamePatchTests(unittest.TestCase):
    def _base_request(self) -> dict:
        if not _FIXTURE.is_file():
            self.skipTest("fixture missing")
        source = resolve_playfair_roman()
        if source is None:
            self.skipTest("Playfair Roman VF not on disk — see fixtures/fonts/README.md")
        request = json.loads(_FIXTURE.read_text(encoding="utf-8"))
        request["source_path"] = str(source)
        return request

    def test_windows_patches_set_without_clobbering_mac(self) -> None:
        request = self._base_request()
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "PlayfairRomanVF-names.woff2"
            request["output_path"] = str(output)
            request["dry_run"] = False
            request["windows_name_patches"] = [
                {"name_id": 1, "string": "Playfair Display Test"},
                {"name_id": 6, "string": "PlayfairDisplay-Variable"},
                {"name_id": 16, "string": "Playfair Display Variable"},
            ]
            # Seed a Mac Roman record that must survive.
            source = TTFont(request["source_path"])
            source["name"].setName("MacFamilyKeep", 1, 1, 0, 0)
            seeded = Path(tmp) / "seeded.ttf"
            source.save(str(seeded))
            request["source_path"] = str(seeded)

            result = run_commit(request)
            self.assertTrue(result.get("ok"), result.get("errors"))

            font = TTFont(str(output))
            name = font["name"]
            self.assertEqual(name.getName(1, 3, 1, 0x409).toUnicode(), "Playfair Display Test")
            self.assertEqual(name.getName(6, 3, 1, 0x409).toUnicode(), "PlayfairDisplay-Variable")
            self.assertEqual(name.getName(16, 3, 1, 0x409).toUnicode(), "Playfair Display Variable")
            mac = name.getName(1, 1, 0, 0)
            self.assertIsNotNone(mac)
            self.assertEqual(mac.toUnicode(), "MacFamilyKeep")

    def test_dry_run_surfaces_windows_patches(self) -> None:
        request = self._base_request()
        request["dry_run"] = True
        request["windows_name_patches"] = [
            {"name_id": 6, "string": "PlayfairDisplay-Variable"},
        ]
        result = run_commit(request)
        self.assertTrue(result.get("ok"), result.get("errors"))
        patches = result.get("diff", {}).get("windows_name_patches") or []
        self.assertTrue(any(p.get("name_id") == 6 for p in patches))
