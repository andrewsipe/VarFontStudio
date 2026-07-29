"""Static instancing engine for VarFontStudio."""

from __future__ import annotations

import json
import re
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer


SCHEMA_VERSION = 1
NAME_ID_FAMILY = 1
NAME_ID_SUBFAMILY = 2
NAME_ID_FULL = 4
NAME_ID_POSTSCRIPT = 6
NAME_ID_TYPO_FAMILY = 16
NAME_ID_TYPO_SUBFAMILY = 17
NAME_ID_VARIATIONS_PS_PREFIX = 25


def run_instance(request: dict[str, Any]) -> dict[str, Any]:
    request_id = str(request.get("request_id") or "")
    dry_run = bool(request.get("dry_run", False))
    source_path = Path(str(request.get("source_path") or "")).expanduser()
    output_dir = Path(str(request.get("output_dir") or "")).expanduser()
    ps_prefix = (request.get("ps_prefix") or "").strip() or None
    keep_stat = bool(request.get("keep_stat", False))
    overwrite = bool(request.get("overwrite", False))
    instances = request.get("instances") or []

    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, str]] = []
    written: list[dict[str, Any]] = []

    if not source_path.is_file():
        return _result(
            request_id,
            False,
            dry_run,
            str(output_dir) if output_dir else None,
            written,
            warnings,
            [{"code": "source_missing", "message": f"Source font not found: {source_path}"}],
        )

    if not instances:
        return _result(
            request_id,
            False,
            dry_run,
            str(output_dir),
            written,
            warnings,
            [{"code": "no_instances", "message": "No instances requested"}],
        )

    if not dry_run:
        try:
            output_dir.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            return _result(
                request_id,
                False,
                dry_run,
                str(output_dir),
                written,
                warnings,
                [{"code": "output_dir", "message": f"Cannot create output directory: {exc}"}],
            )

    try:
        base_font = TTFont(str(source_path), recalcBBoxes=False, recalcTimestamp=False)
    except Exception as exc:  # noqa: BLE001
        return _result(
            request_id,
            False,
            dry_run,
            str(output_dir),
            written,
            warnings,
            [{"code": "font_load", "message": f"{type(exc).__name__}: {exc}"}],
        )

    if "fvar" not in base_font:
        return _result(
            request_id,
            False,
            dry_run,
            str(output_dir),
            written,
            warnings,
            [{"code": "no_fvar", "message": "Source is not a variable font (missing fvar)"}],
        )

    axis_tags = {a.axisTag for a in base_font["fvar"].axes}
    ext = ".otf" if ("CFF " in base_font or "CFF2" in base_font) else ".ttf"
    total = len(instances)

    for index, item in enumerate(instances):
        instance_id = str(item.get("id") or "") if isinstance(item, dict) else ""
        if not isinstance(item, dict):
            message = f"Instance {index} is not an object"
            errors.append({"code": "bad_instance", "message": message, "id": instance_id or None})
            _emit_progress(
                {
                    "event": "error",
                    "id": instance_id or None,
                    "index": index,
                    "total": total,
                    "message": message,
                }
            )
            continue

        coordinates = item.get("coordinates") or {}
        display_name = (item.get("name") or "").strip() or None
        _emit_progress(
            {
                "event": "start",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "name": display_name,
            }
        )

        if not isinstance(coordinates, dict) or not coordinates:
            message = f"Instance {index} missing coordinates"
            errors.append({"code": "bad_coordinates", "message": message, "id": instance_id or None})
            _emit_progress(
                {
                    "event": "error",
                    "id": instance_id or None,
                    "index": index,
                    "total": total,
                    "name": display_name,
                    "message": message,
                }
            )
            continue

        try:
            coords = {str(k): float(v) for k, v in coordinates.items()}
        except (TypeError, ValueError) as exc:
            message = f"Instance {index} has non-numeric coordinates: {exc}"
            errors.append({"code": "bad_coordinates", "message": message, "id": instance_id or None})
            _emit_progress(
                {
                    "event": "error",
                    "id": instance_id or None,
                    "index": index,
                    "total": total,
                    "name": display_name,
                    "message": message,
                }
            )
            continue

        unknown = sorted(set(coords) - axis_tags)
        if unknown:
            message = f"Instance {index}: axis not in font: {', '.join(unknown)}"
            errors.append({"code": "unknown_axis", "message": message, "id": instance_id or None})
            _emit_progress(
                {
                    "event": "error",
                    "id": instance_id or None,
                    "index": index,
                    "total": total,
                    "name": display_name,
                    "message": message,
                }
            )
            continue

        # Pin every fvar axis (static=True path expects full location).
        full_coords = {}
        for axis in base_font["fvar"].axes:
            tag = axis.axisTag
            full_coords[tag] = coords[tag] if tag in coords else float(axis.defaultValue)

        postscript_name = (item.get("postscript_name") or "").strip() or None

        style_token = _style_token(display_name) if display_name else None
        if postscript_name:
            file_stem = _sanitize_ps(postscript_name)
        elif ps_prefix and style_token:
            file_stem = _sanitize_ps(f"{ps_prefix}-{style_token}")
        elif style_token:
            file_stem = _sanitize_ps(style_token)
        else:
            file_stem = "Instance-" + "-".join(
                f"{tag}{full_coords[tag]:g}" for tag in sorted(full_coords)
            )
            file_stem = _sanitize_ps(file_stem)

        out_path = output_dir / f"{file_stem}{ext}"
        if out_path.exists() and not overwrite and not dry_run:
            message = f"Refusing to overwrite existing file: {out_path.name}"
            errors.append({"code": "exists", "message": message, "id": instance_id or None})
            _emit_progress(
                {
                    "event": "error",
                    "id": instance_id or None,
                    "index": index,
                    "total": total,
                    "name": display_name,
                    "message": message,
                }
            )
            continue

        if dry_run:
            written.append(
                {
                    "id": instance_id or None,
                    "path": str(out_path),
                    "postscript_name": postscript_name or file_stem,
                    "coordinates": full_coords,
                    "name": display_name,
                }
            )
            _emit_progress(
                {
                    "event": "written",
                    "id": instance_id or None,
                    "index": index,
                    "total": total,
                    "name": display_name,
                    "path": str(out_path),
                }
            )
            continue

        try:
            instance_font = deepcopy(base_font)
            if ps_prefix:
                _set_name_id(instance_font, NAME_ID_VARIATIONS_PS_PREFIX, ps_prefix)

            try:
                instancer.instantiateVariableFont(
                    instance_font,
                    full_coords,
                    inplace=True,
                    updateFontNames=True,
                    static=True,
                )
            except ValueError:
                if not display_name:
                    raise
                instance_font = deepcopy(base_font)
                if ps_prefix:
                    _set_name_id(instance_font, NAME_ID_VARIATIONS_PS_PREFIX, ps_prefix)
                instancer.instantiateVariableFont(
                    instance_font,
                    full_coords,
                    inplace=True,
                    updateFontNames=False,
                    static=True,
                )

            if not keep_stat and "STAT" in instance_font:
                del instance_font["STAT"]

            if display_name or postscript_name:
                _apply_name_overrides(
                    instance_font,
                    display_name=display_name,
                    postscript_name=postscript_name,
                    ps_prefix=ps_prefix,
                )

            if not postscript_name and not display_name:
                final_ps = _get_name_id(instance_font, NAME_ID_POSTSCRIPT)
                if final_ps:
                    file_stem = _sanitize_ps(final_ps)
                    out_path = output_dir / f"{file_stem}{ext}"
                    if out_path.exists() and not overwrite:
                        message = f"Refusing to overwrite existing file: {out_path.name}"
                        errors.append({"code": "exists", "message": message, "id": instance_id or None})
                        _emit_progress(
                            {
                                "event": "error",
                                "id": instance_id or None,
                                "index": index,
                                "total": total,
                                "name": display_name,
                                "message": message,
                            }
                        )
                        continue

            instance_font.save(str(out_path))
            written_name = (
                display_name
                or _get_name_id(instance_font, NAME_ID_TYPO_SUBFAMILY)
                or _get_name_id(instance_font, NAME_ID_SUBFAMILY)
            )
            written.append(
                {
                    "id": instance_id or None,
                    "path": str(out_path),
                    "postscript_name": _get_name_id(instance_font, NAME_ID_POSTSCRIPT) or file_stem,
                    "coordinates": full_coords,
                    "name": written_name,
                }
            )
            _emit_progress(
                {
                    "event": "written",
                    "id": instance_id or None,
                    "index": index,
                    "total": total,
                    "name": written_name or display_name,
                    "path": str(out_path),
                }
            )
        except Exception as exc:  # noqa: BLE001 — continue batch; surface per-instance failure
            message = f"{file_stem}: {type(exc).__name__}: {exc}"
            errors.append(
                {
                    "code": "instance_failed",
                    "message": message,
                    "id": instance_id or None,
                }
            )
            _emit_progress(
                {
                    "event": "error",
                    "id": instance_id or None,
                    "index": index,
                    "total": total,
                    "name": display_name,
                    "message": message,
                }
            )

    ok = len(errors) == 0 and (dry_run or len(written) > 0)
    if not dry_run and written and errors:
        warnings.append(
            {
                "code": "partial_write",
                "message": f"Wrote {len(written)} of {len(instances)} instances; {len(errors)} failed",
            }
        )
        ok = len(written) > 0

    return _result(request_id, ok, dry_run, str(output_dir), written, warnings, errors)


def _result(
    request_id: str,
    ok: bool,
    dry_run: bool,
    output_dir: str | None,
    written: list[dict[str, Any]],
    warnings: list[dict[str, str]],
    errors: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "request_id": request_id,
        "ok": ok,
        "dry_run": dry_run,
        "output_dir": output_dir,
        "written": written,
        "warnings": warnings,
        "errors": errors,
    }


def _emit_progress(payload: dict[str, Any]) -> None:
    """Line-delimited JSON on stderr so Swift can update the table mid-batch."""
    sys.stderr.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stderr.flush()


def _style_token(name: str) -> str:
    return re.sub(r"\s+", "", name.strip())


def _sanitize_ps(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9-]", "", value)
    return cleaned or "Instance"


def _set_name_id(font: TTFont, name_id: int, string: str) -> None:
    name = font["name"]
    name.setName(string, name_id, 3, 1, 0x409)
    try:
        name.setName(string, name_id, 1, 0, 0)
    except Exception:  # noqa: BLE001 — Mac platform optional
        pass


def _get_name_id(font: TTFont, name_id: int) -> str | None:
    name = font["name"]
    record = name.getName(name_id, 3, 1, 0x409) or name.getName(name_id, 1, 0, 0)
    if record is None:
        return None
    try:
        return str(record.toUnicode()).strip() or None
    except Exception:  # noqa: BLE001
        return None


def _apply_name_overrides(
    font: TTFont,
    *,
    display_name: str | None,
    postscript_name: str | None,
    ps_prefix: str | None,
) -> None:
    if display_name:
        ribbi = {"Regular", "Italic", "Bold", "Bold Italic"}
        _set_name_id(font, NAME_ID_TYPO_SUBFAMILY, display_name)
        if display_name in ribbi:
            _set_name_id(font, NAME_ID_SUBFAMILY, display_name)
        family = _get_name_id(font, NAME_ID_TYPO_FAMILY) or _get_name_id(font, NAME_ID_FAMILY)
        if family:
            _set_name_id(font, NAME_ID_FULL, f"{family} {display_name}")

    if postscript_name:
        _set_name_id(font, NAME_ID_POSTSCRIPT, _sanitize_ps(postscript_name))
    elif display_name and ps_prefix:
        _set_name_id(
            font,
            NAME_ID_POSTSCRIPT,
            _sanitize_ps(f"{ps_prefix}-{_style_token(display_name)}"),
        )
