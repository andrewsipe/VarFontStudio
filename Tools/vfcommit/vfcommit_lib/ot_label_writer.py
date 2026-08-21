#!/usr/bin/env python3
"""
Apply OpenType feature label string patches and ss## FeatureParams additions.
"""

from __future__ import annotations

from copy import deepcopy
import re
from typing import Any, Dict, List, Optional, Set

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables

from vfcommit_lib.logging_config import get_logger
from vfcommit_lib.ot_label_scanner import (
    iter_feature_records,
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
        records = list(iter_feature_records(font, table, tag))
        if not records:
            logger.warning("OT add: feature %s/%s not found", table, tag)
            continue
        # Reuse a primary label if any sibling FeatureRecord already has one.
        existing = None
        source_params = None
        for rec in records:
            params = getattr(rec.Feature, "FeatureParams", None)
            nid = _primary_styleset_name_id(params)
            if nid is not None and nid > 0:
                existing = nid
                source_params = params
                break
        if existing is not None:
            name_id = existing
            font["name"].setName(text, name_id, *_WINDOWS)
            _attach_styleset_params(records, name_id, source_params=source_params)
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
        _attach_styleset_params(records, name_id)
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
            if _RE_STYLESET.match(tag):
                records = list(iter_feature_records(font, table, tag))
                source = None
                for rec in records:
                    params = getattr(rec.Feature, "FeatureParams", None)
                    if _primary_styleset_name_id(params) == name_id:
                        source = params
                        break
                _attach_styleset_params(records, name_id, source_params=source)
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
    for feature_rec in iter_feature_records(font, table, feature_tag):
        params = getattr(feature_rec.Feature, "FeatureParams", None)
        if params is None:
            continue

        if field.startswith("FirstParamUILabelNameID+"):
            # Contiguous param UI labels — clearing one string leaves the ID block;
            # do not rewrite FirstParamUILabelNameID here.
            continue

        if hasattr(params, field):
            try:
                setattr(params, field, 0)
            except Exception as exc:
                logger.debug("Could not clear %s on %s/%s: %s", field, table, feature_tag, exc)
                continue

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
    for feature_rec in iter_feature_records(font, table, feature_tag):
        params = getattr(feature_rec.Feature, "FeatureParams", None)
        if params is None:
            continue

        if field.startswith("FirstParamUILabelNameID+"):
            try:
                offset = int(field.split("+", 1)[1])
            except (IndexError, ValueError):
                continue
            first = getattr(params, "FirstParamUILabelNameID", None)
            if first is None:
                continue
            value = int(first) + offset
            if value > 0:
                return value
            continue

        nid = getattr(params, field, None)
        if nid is None:
            continue
        try:
            value = int(nid)
        except (TypeError, ValueError):
            continue
        if value > 0:
            return value
    return None


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


def _new_styleset_params(name_id: int, source_params=None):
    if source_params is not None:
        params = deepcopy(source_params)
    else:
        params = otTables.FeatureParamsStylisticSet()
        params.Version = 0
    params.UINameID = name_id
    return params


def _attach_styleset_params(records, name_id: int, source_params=None) -> None:
    """Give every FeatureRecord for an ss## tag the same FeatureParams nameID."""
    template = source_params
    if template is None:
        for rec in records:
            params = getattr(rec.Feature, "FeatureParams", None)
            if _primary_styleset_name_id(params) is not None:
                template = params
                break
    for rec in records:
        rec.Feature.FeatureParams = _new_styleset_params(name_id, template)


def sync_styleset_feature_params(font: TTFont) -> int:
    """
    Copy ss## FeatureParams onto sibling FeatureRecords that share the tag.

    Fonts often repeat a stylistic set once per script/langsys. Label add used
    to stamp FeatureParams on the first record only, leaving the rest unlabeled.
    """
    synced = 0
    for table in ("GSUB", "GPOS"):
        if table not in font:
            continue
        try:
            feature_list = font[table].table.FeatureList
            if feature_list is None:
                continue
            records = feature_list.FeatureRecord
        except Exception:
            continue
        by_tag: Dict[str, list] = {}
        for rec in records:
            tag = rec.FeatureTag
            if _RE_STYLESET.match(tag):
                by_tag.setdefault(tag, []).append(rec)
        for recs in by_tag.values():
            source = None
            name_id = None
            for rec in recs:
                params = getattr(rec.Feature, "FeatureParams", None)
                nid = _primary_styleset_name_id(params)
                if nid is not None:
                    source = params
                    name_id = nid
                    break
            if source is None or name_id is None:
                continue
            for rec in recs:
                current = getattr(rec.Feature, "FeatureParams", None)
                if _primary_styleset_name_id(current) == name_id:
                    continue
                rec.Feature.FeatureParams = _new_styleset_params(name_id, source)
                synced += 1
    return synced


__all__ = [
    "apply_ot_label_additions",
    "apply_ot_label_patches",
    "resolve_ot_label_name_id",
    "sync_styleset_feature_params",
]
