"""Post-write validation for vfcommit output fonts."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

from fontTools.ttLib import TTFont

from vfcommit_lib.ot_label_scanner import scan_ot_label_nameids


@dataclass
class ValidationIssue:
    code: str
    severity: str  # "error" | "warning"
    message: str

    def to_dict(self) -> Dict[str, str]:
        return {
            "code": self.code,
            "severity": self.severity,
            "message": self.message,
        }


@dataclass
class ValidationExpectations:
    instances_written: Optional[int] = None
    elided_fallback_name: Optional[str] = None


@dataclass
class ValidationResult:
    ok: bool
    issues: List[ValidationIssue] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ok": self.ok,
            "issue_count": len(self.issues),
            "issues": [issue.to_dict() for issue in self.issues],
        }


def _resolve_name(font: TTFont, name_id: Optional[int]) -> Optional[str]:
    if name_id is None or name_id in (0, 0xFFFF):
        return None
    try:
        name = font["name"].getDebugName(name_id)
        if name:
            return name
        rec = font["name"].getName(name_id, 3, 1, 0x409)
        if rec is not None:
            return rec.toUnicode()
    except Exception:
        return None
    return None


def _add(issues: List[ValidationIssue], code: str, severity: str, message: str) -> None:
    issues.append(ValidationIssue(code=code, severity=severity, message=message))


def validate_written_font(
    font_path: str,
    *,
    expectations: Optional[ValidationExpectations] = None,
) -> ValidationResult:
    """Reload a written font and verify vfcommit-critical table integrity."""
    issues: List[ValidationIssue] = []
    path = Path(font_path)
    if not path.is_file():
        _add(issues, "missing_output", "error", f"Output font not found: {font_path}")
        return ValidationResult(ok=False, issues=issues)

    try:
        font = TTFont(str(path), lazy=False)
    except Exception as exc:
        _add(issues, "unreadable_output", "error", f"Cannot reload output font: {exc}")
        return ValidationResult(ok=False, issues=issues)

    if "fvar" not in font:
        _add(issues, "missing_fvar", "error", "Output font missing fvar table")
    if "STAT" not in font:
        _add(issues, "missing_stat", "error", "Output font missing STAT table")

    if "fvar" in font:
        axes = font["fvar"].axes
        axis_ranges = {
            axis.axisTag: (float(axis.minValue), float(axis.maxValue))
            for axis in axes
        }
        instances = font["fvar"].instances
        if expectations and expectations.instances_written is not None:
            if len(instances) != expectations.instances_written:
                _add(
                    issues,
                    "instance_count_mismatch",
                    "error",
                    f"fvar has {len(instances)} instances; expected {expectations.instances_written}",
                )

        for index, inst in enumerate(instances):
            subfamily_id = inst.subfamilyNameID
            subfamily = _resolve_name(font, subfamily_id)
            if not subfamily:
                _add(
                    issues,
                    "dangling_nameid",
                    "error",
                    f"fvar instance {index}: subfamilyNameID {subfamily_id} does not resolve",
                )

            ps_id = getattr(inst, "postscriptNameID", 0xFFFF)
            if ps_id not in (0, None, 0xFFFF):
                ps_name = _resolve_name(font, ps_id)
                if not ps_name:
                    _add(
                        issues,
                        "dangling_nameid",
                        "error",
                        f"fvar instance {index}: postscriptNameID {ps_id} does not resolve",
                    )

            for tag, value in inst.coordinates.items():
                if tag not in axis_ranges:
                    _add(
                        issues,
                        "unknown_axis_coord",
                        "warning",
                        f"fvar instance {index}: coordinate tag {tag!r} not in fvar.axes",
                    )
                    continue
                min_val, max_val = axis_ranges[tag]
                fval = float(value)
                if fval < min_val - 1e-4 or fval > max_val + 1e-4:
                    _add(
                        issues,
                        "coord_out_of_range",
                        "error",
                        f"fvar instance {index}: {tag}={fval} outside [{min_val}, {max_val}]",
                    )

        for axis in axes:
            axis_name_id = axis.axisNameID
            if axis_name_id >= 256 and not _resolve_name(font, axis_name_id):
                _add(
                    issues,
                    "dangling_nameid",
                    "error",
                    f"fvar axis {axis.axisTag}: axisNameID {axis_name_id} does not resolve",
                )

    if "STAT" in font:
        stat = font["STAT"].table
        design = getattr(stat, "DesignAxisRecord", None)
        design_axes = list(getattr(design, "Axis", []) or []) if design else []
        if not design_axes:
            _add(issues, "stat_no_design_axes", "error", "STAT DesignAxisRecord.Axis is empty")

        axis_values = getattr(stat, "AxisValueArray", None)
        value_records = list(getattr(axis_values, "AxisValue", []) or []) if axis_values else []
        if not value_records:
            _add(issues, "stat_no_axis_values", "error", "STAT AxisValueArray.AxisValue is empty")

        for record in value_records:
            value_name_id = getattr(record, "ValueNameID", None)
            if value_name_id is None:
                continue
            if not _resolve_name(font, value_name_id):
                axis_index = getattr(record, "AxisIndex", "?")
                _add(
                    issues,
                    "dangling_nameid",
                    "error",
                    f"STAT AxisValue axisIndex={axis_index}: ValueNameID {value_name_id} does not resolve",
                )
            axis_index = getattr(record, "AxisIndex", None)
            if axis_index is not None and design_axes:
                if axis_index < 0 or axis_index >= len(design_axes):
                    _add(
                        issues,
                        "stat_bad_axis_index",
                        "error",
                        f"STAT AxisValue references invalid AxisIndex {axis_index}",
                    )

        for axis in design_axes:
            axis_name_id = getattr(axis, "AxisNameID", None)
            if axis_name_id and axis_name_id >= 256 and not _resolve_name(font, axis_name_id):
                tag = getattr(axis, "AxisTag", "?")
                _add(
                    issues,
                    "dangling_nameid",
                    "error",
                    f"STAT design axis {tag}: AxisNameID {axis_name_id} does not resolve",
                )

        efb_id = getattr(stat, "ElidedFallbackNameID", None)
        if not efb_id:
            _add(issues, "missing_elided_fallback", "error", "STAT missing ElidedFallbackNameID")
        else:
            efb_name = _resolve_name(font, efb_id)
            if not efb_name:
                _add(
                    issues,
                    "dangling_nameid",
                    "error",
                    f"STAT ElidedFallbackNameID {efb_id} does not resolve",
                )
            elif (
                expectations
                and expectations.elided_fallback_name
                and efb_name != expectations.elided_fallback_name
            ):
                _add(
                    issues,
                    "elided_fallback_mismatch",
                    "error",
                    f"STAT elided fallback is {efb_name!r}; expected {expectations.elided_fallback_name!r}",
                )

    ot_labels = scan_ot_label_nameids(font)
    for label in ot_labels:
        if label.name_id >= 256 and not _resolve_name(font, label.name_id):
            _add(
                issues,
                "dangling_ot_label",
                "error",
                f"{label.table} {label.feature_tag} {label.field}: nameID {label.name_id} does not resolve",
            )

    has_error = any(issue.severity == "error" for issue in issues)
    return ValidationResult(ok=not has_error, issues=issues)


__all__ = [
    "ValidationExpectations",
    "ValidationIssue",
    "ValidationResult",
    "validate_written_font",
]
