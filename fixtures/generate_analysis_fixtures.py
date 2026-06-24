#!/usr/bin/env python3
"""Regenerate FontAnalysis JSON fixtures from local variable fonts."""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

from fontTools.ttLib import TTFont

# Edit paths if your fonts live elsewhere.
FONT_PATHS = [
    Path.home() / "Downloads/PlayfairRomanVF.woff2",
    Path.home() / "Downloads/PlayfairItalicVF.woff2",
    Path.home()
    / "Downloads/RobotoFlex-VariableFont_GRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght.ttf",
]

OUTPUT_DIR = Path(__file__).resolve().parent / "examples"

PARAMETRIC_TAGS = frozenset(
    {"XOPQ", "YOPQ", "XTRA", "YTUC", "YTLC", "YTAS", "YTDE", "YTFI"}
)


def _inst_key(coords: dict[str, float]) -> str:
    return "|".join(f"{t}:{coords[t]}" for t in sorted(coords))


def analyze(path: Path) -> dict:
    font = TTFont(str(path), lazy=True)
    out: dict = {
        "schema_version": 1,
        "source": {
            "path": str(path),
            "format": path.suffix.lstrip(".").lower(),
            "family_name": font["name"].getDebugName(1) or "",
            "full_name": font["name"].getDebugName(4) or "",
            "is_variable": "fvar" in font,
        },
        "readiness": {
            "has_fvar": "fvar" in font,
            "has_stat": "STAT" in font,
            "has_design_axis_record": False,
            "writable": False,
            "blockers": [],
        },
        "axes": [],
        "stat_values": [],
        "instances_existing": [],
        "instances_existing_meta": {"total": 0, "sample_count": 0},
        "name_audit": {
            "free_start": 256,
            "used": [],
            "elided_fallback_id": None,
            "elided_fallback_name": None,
        },
        "inferred": {
            "is_italic_font": False,
            "grid_axis_tags": [],
            "naming_order_suggested": ["wdth", "wght", "opsz", "slnt", "ital"],
        },
    }

    if "post" in font:
        try:
            out["inferred"]["is_italic_font"] = abs(float(font["post"].italicAngle)) > 0.5
        except (AttributeError, TypeError, ValueError):
            pass

    if "fvar" not in font:
        out["readiness"]["blockers"].append("No fvar table")
        font.close()
        return out

    vary: dict[str, set[float]] = defaultdict(set)
    insts = font["fvar"].instances
    for inst in insts:
        for tag, val in inst.coordinates.items():
            vary[tag].add(float(val))
    grid = sorted(t for t, vals in vary.items() if len(vals) > 1)
    out["inferred"]["grid_axis_tags"] = grid

    idx_to_tag: dict[int, str] = {}
    if "STAT" in font:
        stat = font["STAT"].table
        design = getattr(stat, "DesignAxisRecord", None)
        if design and design.Axis:
            out["readiness"]["has_design_axis_record"] = True
            for i, ax in enumerate(design.Axis):
                idx_to_tag[i] = ax.AxisTag

        efb = getattr(stat, "ElidedFallbackNameID", None)
        if efb:
            out["name_audit"]["elided_fallback_id"] = efb
            out["name_audit"]["elided_fallback_name"] = font["name"].getDebugName(efb)

        avarray = getattr(stat, "AxisValueArray", None)
        if avarray and avarray.AxisValue:
            for av in avarray.AxisValue:
                fmt = int(getattr(av, "Format", 0))
                tag = idx_to_tag.get(getattr(av, "AxisIndex", -1), "?")
                nid = getattr(av, "ValueNameID", 0)
                rec: dict = {
                    "format": fmt,
                    "tag": tag,
                    "name": font["name"].getDebugName(nid) or "",
                    "elidable": bool(getattr(av, "Flags", 0) & 2),
                    "name_id": nid,
                }
                if fmt == 1:
                    rec["value"] = float(getattr(av, "Value", 0))
                elif fmt == 2:
                    rec["range_min"] = float(av.RangeMinValue)
                    rec["nominal"] = float(av.NominalValue)
                    rec["range_max"] = float(av.RangeMaxValue)
                elif fmt == 3:
                    rec["value"] = float(av.Value)
                    rec["linked_value"] = float(av.LinkedValue)
                out["stat_values"].append(rec)

    out["readiness"]["writable"] = (
        out["readiness"]["has_stat"] and out["readiness"]["has_design_axis_record"]
    )
    if not out["readiness"]["has_stat"]:
        out["readiness"]["blockers"].append("No STAT table")
    elif not out["readiness"]["has_design_axis_record"]:
        out["readiness"]["blockers"].append("STAT has no DesignAxisRecord")

    order_map: dict[str, int] = {}
    if "STAT" in font:
        design = font["STAT"].table.DesignAxisRecord
        if design and design.Axis:
            order_map = {
                a.AxisTag: int(getattr(a, "AxisOrdering", i))
                for i, a in enumerate(design.Axis)
            }

    for axis in font["fvar"].axes:
        tag = axis.axisTag
        if tag in grid:
            role = "instance"
        elif tag in PARAMETRIC_TAGS:
            role = "parametric"
        else:
            role = "stat_only"

        vals_existing = [
            {
                k: v
                for k, v in s.items()
                if k
                in (
                    "format",
                    "value",
                    "name",
                    "elidable",
                    "linked_value",
                    "range_min",
                    "nominal",
                    "range_max",
                )
            }
            for s in out["stat_values"]
            if s["tag"] == tag
        ]

        out["axes"].append(
            {
                "tag": tag,
                "display_name": font["name"].getDebugName(axis.axisNameID) or tag,
                "min": float(axis.minValue),
                "default": float(axis.defaultValue),
                "max": float(axis.maxValue),
                "ordering": order_map.get(tag),
                "role_inferred": role,
                "varies_in_existing_instances": tag in grid,
                "values_existing": vals_existing,
            }
        )

    for inst in insts[:5]:
        coords = {k: float(v) for k, v in inst.coordinates.items()}
        out["instances_existing"].append(
            {
                "key": _inst_key(coords),
                "composed_name": font["name"].getDebugName(inst.subfamilyNameID) or "",
                "coords": coords,
                "subfamily_name_id": inst.subfamilyNameID,
                "postscript_name_id": getattr(inst, "postscriptNameID", 0xFFFF),
            }
        )
    out["instances_existing_meta"] = {
        "total": len(insts),
        "sample_count": min(5, len(insts)),
    }

    font.close()
    return out


def _output_name(path: Path) -> str:
    stem = path.stem
    if "PlayfairRoman" in stem:
        return "playfair-roman-analysis.json"
    if "PlayfairItalic" in stem:
        return "playfair-italic-analysis.json"
    if "RobotoFlex" in stem:
        return "roboto-flex-analysis.json"
    return f"{stem[:40]}-analysis.json"


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ok = 0
    for fp in FONT_PATHS:
        if not fp.is_file():
            print(f"skip (missing): {fp}", file=sys.stderr)
            continue
        data = analyze(fp)
        out_path = OUTPUT_DIR / _output_name(fp)
        out_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
        total = data["instances_existing_meta"]["total"]
        print(f"wrote {out_path.name} ({total} instances)")
        ok += 1
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
