"""Reorder STAT DesignAxisRecord order to match the commit request.

fvar axis record order and avar segment maps are intentionally left alone:
variation data (gvar / HVAR / etc.) is stored parallel to fvar axis indices.
Rewriting fvar order without remapping that data swaps slider identity.
"""

from __future__ import annotations

from typing import List, Sequence

from fontTools.ttLib import TTFont


def reorder_axis_tables(
    font: TTFont,
    *,
    design_axis_tags: Sequence[str],
    fvar_axis_tags: Sequence[str] | None = None,
) -> None:
    """Rewrite STAT DesignAxisRecord order (+ AxisOrdering). Does not touch fvar/avar.

    ``fvar_axis_tags`` is accepted for call-site compatibility and ignored.
    """
    del fvar_axis_tags  # locked: do not permute fvar / avar
    if design_axis_tags:
        _reorder_stat_design_axes(font, list(design_axis_tags))


def _reorder_stat_design_axes(font: TTFont, tag_order: List[str]) -> None:
    if "STAT" not in font:
        return
    stat = font["STAT"].table
    design = getattr(stat, "DesignAxisRecord", None)
    if not design or not design.Axis:
        return
    by_tag = {ax.AxisTag: ax for ax in design.Axis}
    reordered = [by_tag[tag] for tag in tag_order if tag in by_tag]
    for ax in design.Axis:
        if ax.AxisTag not in tag_order:
            reordered.append(ax)
    design.Axis = reordered
    for index, axis in enumerate(design.Axis):
        axis.AxisOrdering = index


__all__ = ["reorder_axis_tables"]
