"""Tests for OT feature inventory, patches, additions, and clear-only suggestions."""

from __future__ import annotations

import unittest
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables
from fontTools.ttLib.tables._n_a_m_e import table__n_a_m_e

from vfcommit_lib.ot_label_scanner import (
    analyze_ot_features,
    scan_ot_label_nameids,
    scan_unlabeled_stylesets,
)
from vfcommit_lib.ot_label_suggest import suggest_styleset_label
from vfcommit_lib.ot_label_writer import apply_ot_label_additions, apply_ot_label_patches
from vfcommit_lib.engine import run_commit

from live_font_fixture import resolve_playfair_roman


def _minimal_font_with_ss(labeled: bool, *, coverage_glyphs=None) -> TTFont:
    font = TTFont()
    name = table__n_a_m_e()
    name.names = []
    font["name"] = name

    glyph_order = ["glyph00000", "a", "a.alt", "b", "b.alt"]
    if coverage_glyphs:
        glyph_order = ["glyph00000"] + list(coverage_glyphs)
    font.setGlyphOrder(glyph_order)

    from fontTools.fontBuilder import FontBuilder

    # Prefer a tiny hand-built GSUB without FontBuilder complexity.
    gsub = otTables.GSUB()
    gsub.Version = 0x00010000
    gsub.ScriptList = otTables.ScriptList()
    gsub.ScriptList.ScriptRecord = []
    gsub.FeatureList = otTables.FeatureList()
    gsub.LookupList = otTables.LookupList()

    mapping = {"a": "a.alt"}
    if coverage_glyphs:
        mapping = {}
        for g in coverage_glyphs:
            if g.endswith(".alt"):
                continue
            alt = f"{g}.alt"
            if alt in glyph_order:
                mapping[g] = alt

    subst = otTables.SingleSubst()
    subst.mapping = mapping

    lookup = otTables.Lookup()
    lookup.LookupType = 1
    lookup.LookupFlag = 0
    lookup.SubTable = [subst]

    gsub.LookupList.Lookup = [lookup]

    feature = otTables.Feature()
    feature.FeatureParams = None
    feature.LookupListIndex = [0]
    if labeled:
        name.setName("Stylistic Set 1", 300, 3, 1, 0x0409)
        params = otTables.FeatureParamsStylisticSet()
        params.Version = 0
        params.UINameID = 300
        feature.FeatureParams = params

    rec = otTables.FeatureRecord()
    rec.FeatureTag = "ss01"
    rec.Feature = feature
    gsub.FeatureList.FeatureRecord = [rec]

    # Attach via fontTools GSUB table wrapper
    from fontTools.ttLib import newTable

    table = newTable("GSUB")
    table.table = gsub
    font["GSUB"] = table

    # cmap for suggest path
    from fontTools.ttLib.tables._c_m_a_p import CmapSubtable

    cmap = newTable("cmap")
    cmap.tableVersion = 0
    sub = CmapSubtable.newSubtable(4)
    sub.platformID = 3
    sub.platEncID = 1
    sub.language = 0
    sub.cmap = {ord("a"): "a", ord("b"): "b"}
    cmap.tables = [sub]
    font["cmap"] = cmap
    return font


class OTFeatureNamesTests(unittest.TestCase):
    def test_scan_unlabeled_styleset(self) -> None:
        font = _minimal_font_with_ss(labeled=False)
        unlabeled = scan_unlabeled_stylesets(font)
        self.assertEqual(len(unlabeled), 1)
        self.assertEqual(unlabeled[0].feature_tag, "ss01")
        self.assertEqual(scan_ot_label_nameids(font), [])

    def test_suggest_clear_single_glyph(self) -> None:
        font = _minimal_font_with_ss(labeled=False)
        suggestion = suggest_styleset_label(font, table="GSUB", feature_tag="ss01")
        self.assertEqual(suggestion, "Alternate a")

    def test_suggest_unclear_wide_set(self) -> None:
        glyphs = []
        for ch in "abcdefghij":
            glyphs.extend([ch, f"{ch}.alt"])
        font = _minimal_font_with_ss(labeled=False, coverage_glyphs=glyphs)
        suggestion = suggest_styleset_label(font, table="GSUB", feature_tag="ss01")
        self.assertIsNone(suggestion)

    def test_add_and_patch_label(self) -> None:
        font = _minimal_font_with_ss(labeled=False)
        applied = apply_ot_label_additions(
            font,
            [{"table": "GSUB", "feature_tag": "ss01", "string": "Swash A"}],
        )
        self.assertEqual(len(applied), 1)
        self.assertTrue(applied[0]["created_params"])
        labels = scan_ot_label_nameids(font)
        self.assertEqual(len(labels), 1)
        self.assertEqual(labels[0].string, "Swash A")

        patched = apply_ot_label_patches(
            font,
            [
                {
                    "table": "GSUB",
                    "feature_tag": "ss01",
                    "field": "UINameID",
                    "string": "Alternate a",
                }
            ],
        )
        self.assertEqual(len(patched), 1)
        labels = scan_ot_label_nameids(font)
        self.assertEqual(labels[0].string, "Alternate a")

    def test_analyze_payload(self) -> None:
        font = _minimal_font_with_ss(labeled=False)
        payload = analyze_ot_features(font)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["ot_feature_labels"], [])
        self.assertEqual(len(payload["ot_features_unlabeled"]), 1)
        self.assertEqual(payload["ot_features_unlabeled"][0]["suggested_string"], "Alternate a")

    def test_playfair_has_labels(self) -> None:
        path = resolve_playfair_roman()
        if path is None:
            self.skipTest("Playfair Roman VF not on disk")
        font = TTFont(str(path), lazy=True)
        labels = scan_ot_label_nameids(font)
        self.assertGreaterEqual(len(labels), 1)

    def test_commit_dry_run_includes_ot_patches(self) -> None:
        path = resolve_playfair_roman()
        if path is None:
            self.skipTest("Playfair Roman VF not on disk")
        font = TTFont(str(path), lazy=False)
        labels = scan_ot_label_nameids(font)
        self.assertTrue(labels)
        target = labels[0]
        request = {
            "schema_version": 1,
            "request_id": "ot-patch-test",
            "source_path": str(path),
            "output_path": "/tmp/unused.ttf",
            "dry_run": True,
            "options": {"nameid_strategy": "preserve", "family_ps_prefix": ""},
            "naming": {"order": [], "elided_fallback": "Regular"},
            "axes": [],
            "included_instance_keys": [],
            "ot_label_patches": [
                {
                    "table": target.table,
                    "feature_tag": target.feature_tag,
                    "field": target.field,
                    "string": "Patched Label",
                }
            ],
        }
        result = run_commit(request)
        self.assertTrue(result.get("ok"), result)
        patches = (result.get("diff") or {}).get("ot_label_patches") or []
        self.assertTrue(any(p.get("string") == "Patched Label" for p in patches))

    def test_reflow_addition_does_not_collide_with_axis_allocation(self) -> None:
        """ss## additions under reflow must not steal 256 from axis names."""
        from vfcommit_lib.nameid_allocator import (
            AxisDef,
            AxisValueDef,
            build_allocation_plan,
            check_for_collisions,
        )

        font = _minimal_font_with_ss(labeled=False)
        applied = apply_ot_label_additions(
            font,
            [{"table": "GSUB", "feature_tag": "ss01", "string": "Sharp Serifs"}],
            free_start=256,
        )
        self.assertEqual(applied[0]["name_id"], 256)
        ot_labels = scan_ot_label_nameids(font)
        axis_defs = [
            AxisDef(
                tag="wght",
                display_name="Weight",
                min_value=100.0,
                default_value=400.0,
                max_value=900.0,
                values=[AxisValueDef(value=400.0, name="Regular", elidable=True)],
            )
        ]
        # Stale reflow end (pre-addition) used to allocate wght at 256 → collision.
        plan = build_allocation_plan(
            font,
            ot_labels,
            axis_defs,
            allocate_postscript_names=False,
            nameid_strategy="reflow",
            ot_reflow_end=max(rec.name_id for rec in ot_labels),
        )
        self.assertEqual([], check_for_collisions(plan, font))
        self.assertGreater(plan.axis_name_ids["wght"], 256)

    def test_reflow_wipe_keeps_added_ot_label_string(self) -> None:
        """Added ss## nameIDs must be in the wipe protect set (reflow write path)."""
        from vfcommit_lib.stat_builder import _wipe_existing_table_data

        font = _minimal_font_with_ss(labeled=False)
        applied = apply_ot_label_additions(
            font,
            [{"table": "GSUB", "feature_tag": "ss01", "string": "Sharp Serifs"}],
            free_start=256,
        )
        name_id = int(applied[0]["name_id"])
        ot_label_ids = {rec.name_id for rec in scan_ot_label_nameids(font)}
        # Engine reflow protect set: remapped IDs ∪ live OT label IDs (incl. additions).
        protected_ids = set() | set(ot_label_ids)
        _wipe_existing_table_data(font, protected_ids)
        self.assertEqual(font["name"].getDebugName(name_id), "Sharp Serifs")
        labels = scan_ot_label_nameids(font)
        self.assertEqual(len(labels), 1)
        self.assertEqual(labels[0].string, "Sharp Serifs")

    def test_add_label_covers_sibling_feature_records(self) -> None:
        font = _font_with_duplicate_ss_records(5)
        applied = apply_ot_label_additions(
            font,
            [{"table": "GSUB", "feature_tag": "ss01", "string": "High Bars"}],
        )
        self.assertEqual(applied[0]["name_id"], 256)
        ss01 = [
            rec
            for rec in font["GSUB"].table.FeatureList.FeatureRecord
            if rec.FeatureTag == "ss01"
        ]
        self.assertEqual(len(ss01), 5)
        ids = [rec.Feature.FeatureParams.UINameID for rec in ss01]
        self.assertEqual(ids, [256, 256, 256, 256, 256])
        windows = [
            rec
            for rec in font["name"].names
            if rec.nameID == 256 and rec.platformID == 3 and rec.platEncID == 1 and rec.langID == 0x409
        ]
        self.assertEqual(len(windows), 1)
        self.assertEqual(windows[0].toUnicode(), "High Bars")

    def test_unlabeled_scan_ignores_sibling_without_params(self) -> None:
        font = _font_with_duplicate_ss_records(3)
        first = font["GSUB"].table.FeatureList.FeatureRecord[0]
        params = otTables.FeatureParamsStylisticSet()
        params.Version = 0
        params.UINameID = 256
        first.Feature.FeatureParams = params
        font["name"].setName("High Bars", 256, 3, 1, 0x409)
        self.assertEqual(scan_unlabeled_stylesets(font), [])


def _font_with_duplicate_ss_records(count: int) -> TTFont:
    font = _minimal_font_with_ss(labeled=False)
    records = font["GSUB"].table.FeatureList.FeatureRecord
    first = records[0]
    for _ in range(count - 1):
        clone = otTables.FeatureRecord()
        clone.FeatureTag = "ss01"
        feature = otTables.Feature()
        feature.FeatureParams = None
        feature.LookupListIndex = list(first.Feature.LookupListIndex)
        clone.Feature = feature
        records.append(clone)
    return font


if __name__ == "__main__":
    unittest.main()
