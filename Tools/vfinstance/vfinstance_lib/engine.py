"""Static instancing engine for VarFontStudio."""

from __future__ import annotations

import json
import os
import re
import sys
import time
from concurrent.futures import FIRST_COMPLETED, ProcessPoolExecutor, wait
from copy import deepcopy
from pathlib import Path
from typing import Any

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.varLib.instancer import names as instancer_names


SCHEMA_VERSION = 1
NAME_ID_FAMILY = 1
NAME_ID_SUBFAMILY = 2
NAME_ID_FULL = 4
NAME_ID_POSTSCRIPT = 6
NAME_ID_TYPO_FAMILY = 16
NAME_ID_TYPO_SUBFAMILY = 17
NAME_ID_VARIATIONS_PS_PREFIX = 25

RIBBI_STYLES = frozenset({"Regular", "Italic", "Bold", "Bold Italic"})

# Default parallel workers; capped by CPU and instance count at runtime.
DEFAULT_MAX_WORKERS = 8
# Delay between launching each in-flight slot so completions don't clump.
DEFAULT_STAGGER_SECONDS = 1.0

# Mirrors PostScriptNaming.stripVariableTokens / vfcommit name_policies.
_RE_VARIABLE_TOKENS = re.compile(r"\b(Variable|VF|GX|Flex)\b", re.I)
_RE_VARIABLE_BOUNDARY = re.compile(r"(?i)(?:^|[-_\s])Variable(?:Italic)?(?=$|[-_\s])")
_RE_VF_GX_FLEX_BOUNDARY = re.compile(r"(?i)(?:^|[-_\s])(VF|GX|Flex)(?=$|[-_\s])")

# Process-pool worker locals (lazy TTFont load per worker process).
_WORKER_BASE_FONT: TTFont | None = None
_WORKER_SOURCE_PATH: str | None = None
_WORKER_CONTEXT: dict[str, Any] | None = None


def resolve_worker_count(requested: Any, total: int) -> int:
    """Always parallel-capable: min(requested|default, cpu, instance_count)."""
    if total <= 0:
        return 1
    if requested is None:
        requested_n = DEFAULT_MAX_WORKERS
    else:
        try:
            requested_n = int(requested)
        except (TypeError, ValueError):
            requested_n = DEFAULT_MAX_WORKERS
    if requested_n < 1:
        requested_n = 1
    cpu = os.cpu_count() or 1
    return max(1, min(requested_n, cpu, total))


def resolve_stagger_seconds(requested: Any) -> float:
    if requested is None:
        return DEFAULT_STAGGER_SECONDS
    try:
        value = float(requested)
    except (TypeError, ValueError):
        return DEFAULT_STAGGER_SECONDS
    return max(0.0, min(value, 10.0))


def run_instance(request: dict[str, Any]) -> dict[str, Any]:
    request_id = str(request.get("request_id") or "")
    dry_run = bool(request.get("dry_run", False))
    source_path = Path(str(request.get("source_path") or "")).expanduser()
    output_dir = Path(str(request.get("output_dir") or "")).expanduser()
    ps_prefix = (request.get("ps_prefix") or "").strip() or None
    family_name = (request.get("family_name") or "").strip() or None
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
    workers = 1 if dry_run else resolve_worker_count(request.get("workers"), total)

    shared = {
        "output_dir": str(output_dir),
        "dry_run": dry_run,
        "overwrite": overwrite,
        "ps_prefix": ps_prefix,
        "family_name": family_name,
        "keep_stat": keep_stat,
        "ext": ext,
        "axis_tags": sorted(axis_tags),
        "source_path": str(source_path),
    }

    if workers == 1:
        try:
            for index, item in enumerate(instances):
                outcome = _process_instance(
                    base_font=base_font,
                    item=item,
                    index=index,
                    total=total,
                    shared=shared,
                )
                _absorb_outcome(outcome, written, errors)
        finally:
            base_font.close()
    else:
        # Drop the parent copy before workers load their own — frees ~1× VF RSS.
        base_font.close()
        del base_font

        jobs = [
            {"item": item, "index": index, "total": total}
            for index, item in enumerate(instances)
        ]
        ctx = {k: v for k, v in shared.items() if k != "axis_tags"}
        ctx["axis_tags"] = list(axis_tags)
        stagger = resolve_stagger_seconds(request.get("stagger_seconds"))
        _run_parallel_pipeline(
            source_path=str(source_path),
            context=ctx,
            jobs=jobs,
            workers=workers,
            stagger_seconds=stagger,
            total=total,
            written=written,
            errors=errors,
        )

    # Keep written list stable by original request order when possible.
    written.sort(key=lambda row: _written_sort_key(row, instances))

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


def _written_sort_key(row: dict[str, Any], instances: list[Any]) -> int:
    row_id = row.get("id")
    if row_id:
        for index, item in enumerate(instances):
            if isinstance(item, dict) and item.get("id") == row_id:
                return index
    return 10**9


def _run_parallel_pipeline(
    *,
    source_path: str,
    context: dict[str, Any],
    jobs: list[dict[str, Any]],
    workers: int,
    stagger_seconds: float,
    total: int,
    written: list[dict[str, Any]],
    errors: list[dict[str, Any]],
) -> None:
    """Keep up to `workers` in flight, but ramp starts so completions stay sequential-feeling.

    Submits job 1, waits `stagger_seconds`, submits job 2, … until the window is full.
    When any job finishes, immediately starts the next — a sliding pipeline, not 8-at-a-time waves.
    """
    _emit_progress(
        {
            "event": "status",
            "index": 0,
            "total": total,
            "message": f"Starting {workers} workers (staggered)…",
        }
    )

    job_iter = iter(jobs)
    in_flight: dict[Any, dict[str, Any]] = {}

    with ProcessPoolExecutor(
        max_workers=workers,
        initializer=_pool_initializer,
        initargs=(source_path, context),
    ) as pool:

        def _submit_next() -> bool:
            try:
                job = next(job_iter)
            except StopIteration:
                return False
            _emit_job_start(job, total)
            future = pool.submit(_pool_process_job, job)
            in_flight[future] = job
            return True

        # Ramp: open slots one-by-one so workers don't sync-lockstep.
        for slot in range(workers):
            if not _submit_next():
                break
            if slot + 1 < workers and stagger_seconds > 0:
                time.sleep(stagger_seconds)

        while in_flight:
            done, _ = wait(in_flight.keys(), return_when=FIRST_COMPLETED)
            for future in done:
                in_flight.pop(future, None)
                try:
                    outcome = future.result()
                except Exception as exc:  # noqa: BLE001
                    message = f"worker_crash: {type(exc).__name__}: {exc}"
                    errors.append({"code": "instance_failed", "message": message})
                    _emit_progress(
                        {
                            "event": "error",
                            "id": None,
                            "index": 0,
                            "total": total,
                            "message": message,
                        }
                    )
                else:
                    _absorb_outcome(outcome, written, errors)
                # Refill immediately — keeps N busy without re-bunching the whole cohort.
                _submit_next()


def _emit_job_start(job: dict[str, Any], total: int) -> None:
    """Parent-side start so the UI advances as jobs are queued, not only when a wave finishes."""
    item = job.get("item") if isinstance(job.get("item"), dict) else {}
    instance_id = str(item.get("id") or "") or None
    display_name = (item.get("name") or "").strip() or None
    _emit_progress(
        {
            "event": "start",
            "id": instance_id,
            "index": int(job.get("index") or 0),
            "total": total,
            "name": display_name,
        }
    )


def _absorb_outcome(
    outcome: dict[str, Any],
    written: list[dict[str, Any]],
    errors: list[dict[str, Any]],
) -> None:
    for event in outcome.get("events") or []:
        # Parent already emitted start when the job was queued.
        if event.get("event") == "start":
            continue
        _emit_progress(event)
    if outcome.get("written"):
        written.append(outcome["written"])
    if outcome.get("error"):
        errors.append(outcome["error"])


def _pool_initializer(source_path: str, context: dict[str, Any]) -> None:
    """Light init — load the VF lazily on the first job so ramp-up isn't a silent hang."""
    global _WORKER_BASE_FONT, _WORKER_SOURCE_PATH, _WORKER_CONTEXT
    _WORKER_SOURCE_PATH = source_path
    _WORKER_CONTEXT = context
    _WORKER_BASE_FONT = None


def _ensure_worker_font() -> TTFont:
    global _WORKER_BASE_FONT
    if _WORKER_BASE_FONT is None:
        assert _WORKER_SOURCE_PATH is not None
        _WORKER_BASE_FONT = TTFont(
            _WORKER_SOURCE_PATH,
            recalcBBoxes=False,
            recalcTimestamp=False,
        )
    return _WORKER_BASE_FONT


def _pool_process_job(job: dict[str, Any]) -> dict[str, Any]:
    assert _WORKER_CONTEXT is not None
    return _process_instance(
        base_font=_ensure_worker_font(),
        item=job.get("item"),
        index=int(job.get("index") or 0),
        total=int(job.get("total") or 1),
        shared=_WORKER_CONTEXT,
    )


def _process_instance(
    *,
    base_font: TTFont,
    item: Any,
    index: int,
    total: int,
    shared: dict[str, Any],
) -> dict[str, Any]:
    """Instantiate one row. Returns written/error plus progress events (not emitted)."""
    output_dir = Path(str(shared["output_dir"]))
    dry_run = bool(shared["dry_run"])
    overwrite = bool(shared["overwrite"])
    ps_prefix = shared.get("ps_prefix")
    family_name = shared.get("family_name")
    keep_stat = bool(shared["keep_stat"])
    ext = str(shared["ext"])
    axis_tags = set(shared["axis_tags"])

    events: list[dict[str, Any]] = []
    instance_id = str(item.get("id") or "") if isinstance(item, dict) else ""

    if not isinstance(item, dict):
        message = f"Instance {index} is not an object"
        events.append(
            {
                "event": "error",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "message": message,
            }
        )
        return {
            "events": events,
            "error": {"code": "bad_instance", "message": message, "id": instance_id or None},
        }

    coordinates = item.get("coordinates") or {}
    display_name = (item.get("name") or "").strip() or None
    events.append(
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
        events.append(
            {
                "event": "error",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "name": display_name,
                "message": message,
            }
        )
        return {
            "events": events,
            "error": {"code": "bad_coordinates", "message": message, "id": instance_id or None},
        }

    try:
        coords = {str(k): float(v) for k, v in coordinates.items()}
    except (TypeError, ValueError) as exc:
        message = f"Instance {index} has non-numeric coordinates: {exc}"
        events.append(
            {
                "event": "error",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "name": display_name,
                "message": message,
            }
        )
        return {
            "events": events,
            "error": {"code": "bad_coordinates", "message": message, "id": instance_id or None},
        }

    unknown = sorted(set(coords) - axis_tags)
    if unknown:
        message = f"Instance {index}: axis not in font: {', '.join(unknown)}"
        events.append(
            {
                "event": "error",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "name": display_name,
                "message": message,
            }
        )
        return {
            "events": events,
            "error": {"code": "unknown_axis", "message": message, "id": instance_id or None},
        }

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
        events.append(
            {
                "event": "error",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "name": display_name,
                "message": message,
            }
        )
        return {
            "events": events,
            "error": {"code": "exists", "message": message, "id": instance_id or None},
        }

    if dry_run:
        written_row = {
            "id": instance_id or None,
            "path": str(out_path),
            "postscript_name": postscript_name or file_stem,
            "coordinates": full_coords,
            "name": display_name,
        }
        events.append(
            {
                "event": "written",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "name": display_name,
                "path": str(out_path),
            }
        )
        return {"events": events, "written": written_row}

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

        _finalize_static_tables(instance_font, keep_stat=keep_stat)

        _apply_name_overrides(
            instance_font,
            display_name=display_name,
            postscript_name=postscript_name,
            ps_prefix=ps_prefix,
            family_name=family_name,
        )

        if not postscript_name and not display_name:
            final_ps = _get_name_id(instance_font, NAME_ID_POSTSCRIPT)
            if final_ps:
                file_stem = _sanitize_ps(final_ps)
                out_path = output_dir / f"{file_stem}{ext}"
                if out_path.exists() and not overwrite:
                    message = f"Refusing to overwrite existing file: {out_path.name}"
                    events.append(
                        {
                            "event": "error",
                            "id": instance_id or None,
                            "index": index,
                            "total": total,
                            "name": display_name,
                            "message": message,
                        }
                    )
                    return {
                        "events": events,
                        "error": {
                            "code": "exists",
                            "message": message,
                            "id": instance_id or None,
                        },
                    }

        instance_font.save(str(out_path))
        written_name = (
            display_name
            or _get_name_id(instance_font, NAME_ID_TYPO_SUBFAMILY)
            or _get_name_id(instance_font, NAME_ID_SUBFAMILY)
        )
        written_row = {
            "id": instance_id or None,
            "path": str(out_path),
            "postscript_name": _get_name_id(instance_font, NAME_ID_POSTSCRIPT) or file_stem,
            "coordinates": full_coords,
            "name": written_name,
        }
        events.append(
            {
                "event": "written",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "name": written_name or display_name,
                "path": str(out_path),
            }
        )
        return {"events": events, "written": written_row}
    except Exception as exc:  # noqa: BLE001 — continue batch; surface per-instance failure
        message = f"{file_stem}: {type(exc).__name__}: {exc}"
        events.append(
            {
                "event": "error",
                "id": instance_id or None,
                "index": index,
                "total": total,
                "name": display_name,
                "message": message,
            }
        )
        return {
            "events": events,
            "error": {
                "code": "instance_failed",
                "message": message,
                "id": instance_id or None,
            },
        }


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


def _finalize_static_tables(font: TTFont, *, keep_stat: bool) -> None:
    """Drop static-only variation metadata and its now-unused name records."""
    if not keep_stat and "STAT" in font:
        # Instancer prunes names while it trims STAT/fvar. Since we remove STAT
        # afterward, run the same reference-aware pruning around that removal.
        with instancer_names.pruningUnusedNames(font):
            del font["STAT"]

    # Name ID 25 is the Variations PostScript Name Prefix and has no meaning
    # once fvar is gone. It is intentionally outside FontTools' >255 pruning.
    if "fvar" not in font and "name" in font:
        font["name"].removeNames(nameID=NAME_ID_VARIATIONS_PS_PREFIX)
        font["name"].names[:] = [
            record for record in font["name"].names if record.platformID != 1
        ]


def _style_token(name: str) -> str:
    return re.sub(r"\s+", "", name.strip())


def _sanitize_ps(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9-]", "", value)
    return cleaned or "Instance"


def _set_name_id(font: TTFont, name_id: int, string: str) -> None:
    name = font["name"]
    name.setName(string, name_id, 3, 1, 0x409)


def _get_name_id(font: TTFont, name_id: int) -> str | None:
    name = font["name"]
    record = name.getName(name_id, 3, 1, 0x409) or name.getName(name_id, 1, 0, 0)
    if record is None:
        return None
    try:
        return str(record.toUnicode()).strip() or None
    except Exception:  # noqa: BLE001
        return None


def _strip_variable_tokens(text: str | None) -> str | None:
    if not text:
        return None
    s, _ = _RE_VARIABLE_TOKENS.subn("", text)
    s = _RE_VARIABLE_BOUNDARY.sub(" ", s)
    s = _RE_VF_GX_FLEX_BOUNDARY.sub(" ", s)
    collapsed = " ".join(s.split())
    return collapsed or None


def _resolve_family_name(font: TTFont, explicit: str | None) -> str | None:
    """Prefer an explicit override; otherwise strip Variable/VF tokens from ID 16/1."""
    if explicit:
        return explicit
    raw = _get_name_id(font, NAME_ID_TYPO_FAMILY) or _get_name_id(font, NAME_ID_FAMILY)
    if not raw:
        return None
    return _strip_variable_tokens(raw) or raw


def _apply_name_overrides(
    font: TTFont,
    *,
    display_name: str | None,
    postscript_name: str | None,
    ps_prefix: str | None,
    family_name: str | None = None,
) -> None:
    family = _resolve_family_name(font, family_name)

    if family:
        _set_name_id(font, NAME_ID_TYPO_FAMILY, family)

    if display_name:
        _set_name_id(font, NAME_ID_TYPO_SUBFAMILY, display_name)
        if display_name in RIBBI_STYLES:
            _set_name_id(font, NAME_ID_SUBFAMILY, display_name)
            if family:
                _set_name_id(font, NAME_ID_FAMILY, family)
                _set_name_id(font, NAME_ID_FULL, f"{family} {display_name}")
        elif family:
            # Non-RIBBI: Windows family carries the style; ID 2 stays RIBBI from fontTools.
            _set_name_id(font, NAME_ID_FAMILY, f"{family} {display_name}")
            _set_name_id(font, NAME_ID_FULL, f"{family} {display_name}")
        else:
            inherited = _get_name_id(font, NAME_ID_TYPO_FAMILY) or _get_name_id(
                font, NAME_ID_FAMILY
            )
            if inherited:
                _set_name_id(font, NAME_ID_FULL, f"{inherited} {display_name}")
    elif family:
        style = _get_name_id(font, NAME_ID_TYPO_SUBFAMILY) or _get_name_id(
            font, NAME_ID_SUBFAMILY
        )
        subfamily = _get_name_id(font, NAME_ID_SUBFAMILY)
        if style and style not in RIBBI_STYLES:
            _set_name_id(font, NAME_ID_FAMILY, f"{family} {style}")
            _set_name_id(font, NAME_ID_FULL, f"{family} {style}")
        else:
            _set_name_id(font, NAME_ID_FAMILY, family)
            if style:
                _set_name_id(font, NAME_ID_FULL, f"{family} {style}")
            elif subfamily:
                _set_name_id(font, NAME_ID_FULL, f"{family} {subfamily}")
            else:
                _set_name_id(font, NAME_ID_FULL, family)

    if postscript_name:
        _set_name_id(font, NAME_ID_POSTSCRIPT, _sanitize_ps(postscript_name))
    elif display_name and ps_prefix:
        _set_name_id(
            font,
            NAME_ID_POSTSCRIPT,
            _sanitize_ps(f"{ps_prefix}-{_style_token(display_name)}"),
        )
