#!/usr/bin/env python3
"""
Apply OpenType feature label string patches and ss## FeatureParams additions.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional, Set, Tuple

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables

from vfcommit_lib.logging_config import get_logger
from vfcommit_lib.ot_label_scanner import (
    find_feature_record,
    scan_ot_label_nameids,
)

logger = get_logger(__name__)

_RE_STYLESET = re.compile(r"^ss\d{2}$")
_WINDOWS = (3, 1, 0x0409)


def apply_ot_label_additions(
    font: TTFont,
    additions: List[Dict[str, Any]],
    *,
    used_name_ids: Optional[Set[int]] = None,
    free_start: int = 256,
) -> List[Dict[str, Any]]:
    """
    Create FeatureParamsStylisticSet + Windows English name for unlabeled ss##.

    Returns applied records: {table, feature_tag, field, name_id, string}.
    """
    used = set(used_name_ids or set())
    try:
        for rec in font["name"].names:
            used.add(int(rec.nameID))
    except Exception:
        pass
    for label in scan_ot_label_nameids(font):
        used.add(label.name_id)

    applied: List[Dict[str, Any]] = []
    # Process additions in stable feature order so provisional UI IDs match write order.
    ordered = sorted(
        additions or [],
        key=lambda item: (str(item.get("table") or ""), str(item.get("feature_tag") or "")),
    )
    next_id = max(int(free_start), 256)
    for addition in ordered:
        table = str(addition.get("table") or "GSUB")
        tag = str(addition.get("feature_tag") or "")
        text = str(addition.get("string") or "").strip()
        if not _RE_STYLESET.match(tag) or not text:
            continue
        feature_rec = find_feature_record(font, table, tag)
        if feature_rec is None:
            logger.warning("OT add: feature %s/%s not found", table, tag)
            continue
        # Skip if a primary label already exists.
        params = getattr(feature_rec.Feature, "FeatureParams", None)
        existing = _primary_styleset_name_id(params)
        if existing is not None and existing > 0:
            name_id = existing
            font["name"].setName(text, name_id, *_WINDOWS)
            applied.append(
                {
                    "table": table,
                    "feature_tag": tag,
                    "field": "UINameID",
                    "name_id": name_id,
                    "string": text,
                    "created_params": False,
                }
            )
            continue

        while next_id in used:
            next_id += 1
        name_id = next_id
        used.add(name_id)
        next_id += 1

        font["name"].setName(text, name_id, *_WINDOWS)
        new_params = otTables.FeatureParamsStylisticSet()
        new_params.Version = 0
        new_params.UINameID = name_id
        feature_rec.Feature.FeatureParams = new_params
        applied.append(
            {
                "table": table,
                "feature_tag": tag,
                "field": "UINameID",
                "name_id": name_id,
                "string": text,
                "created_params": True,
            }
        )
    return applied


def apply_ot_label_patches(
    font: TTFont,
    patches: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """
    Rewrite Windows English strings for existing FeatureParams-linked sites.

    Each patch: {table, feature_tag, field, string}. Resolves nameID from live
    FeatureParams after any reflow.

    Empty string removes the name-table label and clears the FeatureParams
    nameID pointer for that field (ss## drops FeatureParams when primary IDs
    are gone). The GSUB/GPOS feature and its lookups are left intact.
    """
    applied: List[Dict[str, Any]] = []
    for patch in patches or []:
        table = str(patch.get("table") or "")
        tag = str(patch.get("feature_tag") or "")
        field = str(patch.get("field") or "")
        if "string" not in patch:
            continue
        text = str(patch.get("string") or "")
        name_id = resolve_ot_label_name_id(font, table=table, feature_tag=tag, field=field)
        if name_id is None or name_id <= 0:
            logger.warning("OT patch: could not resolve %s/%s/%s", table, tag, field)
            continue
        if text == "":
            font["name"].removeNames(nameID=name_id, platformID=3, platEncID=1, langID=0x0409)
            _clear_feature_params_field(font, table=table, feature_tag=tag, field=field)
        else:
            font["name"].setName(text, name_id, *_WINDOWS)
        applied.append(
            {
                "table": table,
                "feature_tag": tag,
                "field": field,
                "name_id": name_id,
                "string": text,
            }
        )
    return applied


def _clear_feature_params_field(
    font: TTFont,
    *,
    table: str,
    feature_tag: str,
    field: str,
) -> None:
    """Zero a FeatureParams nameID field; drop ss FeatureParams when primary IDs are gone."""
    feature_rec = find_feature_record(font, table, feature_tag)
    if feature_rec is None:
        return
    params = getattr(feature_rec.Feature, "FeatureParams", None)
    if params is None:
        return

    if field.startswith("FirstParamUILabelNameID+"):
        # Contiguous param UI labels — clearing one string leaves the ID block;
        # do not rewrite FirstParamUILabelNameID here.
        return

    if hasattr(params, field):
        try:
            setattr(params, field, 0)
        except Exception as exc:
            logger.debug("Could not clear %s on %s/%s: %s", field, table, feature_tag, exc)
            return

    if _RE_STYLESET.match(feature_tag):
        ui = int(getattr(params, "UINameID", 0) or 0)
        feat = int(getattr(params, "FeatureNameID", 0) or 0) if hasattr(params, "FeatureNameID") else 0
        if ui <= 0 and feat <= 0:
            feature_rec.Feature.FeatureParams = None


def resolve_ot_label_name_id(
    font: TTFont,
    *,
    table: str,
    feature_tag: str,
    field: str,
) -> Optional[int]:
    """Resolve a FeatureParams field (including FirstParamUILabelNameID+N) to a nameID."""
    feature_rec = find_feature_record(font, table, feature_tag)
    if feature_rec is None:
        return None
    params = getattr(feature_rec.Feature, "FeatureParams", None)
    if params is None:
        return None

    if field.startswith("FirstParamUILabelNameID+"):
        try:
            offset = int(field.split("+", 1)[1])
        except (IndexError, ValueError):
            return None
        first = getattr(params, "FirstParamUILabelNameID", None)
        if first is None:
            return None
        return int(first) + offset

    nid = getattr(params, field, None)
    if nid is None:
        return None
    try:
        value = int(nid)
    except (TypeError, ValueError):
        return None
    return value if value > 0 else None


def _primary_styleset_name_id(params) -> Optional[int]:
    if params is None:
        return None
    for field in ("UINameID", "FeatureNameID"):
        nid = getattr(params, field, None)
        if nid is not None:
            try:
                value = int(nid)
            except (TypeError, ValueError):
                continue
            if value > 0:
                return value
    return None


__all__ = [
    "apply_ot_label_additions",
    "apply_ot_label_patches",
    "resolve_ot_label_name_id",
]
