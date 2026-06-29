"""Tests for vfcommit (no font files required for bridge/unit tests)."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from vfcommit_lib.request_bridge import (
    axis_defs_from_request,
    count_included_instances,
    grid_axis_defs,
    instance_key,
    pinned_coords,
)

_FIXTURE = (
    Path(__file__).resolve().parents[3]
    / "fixtures"
    / "examples"
    / "playfair-roman-commit-request.json"
)


class RequestBridgeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.request = json.loads(_FIXTURE.read_text(encoding="utf-8"))

    def test_instance_key_sorts_tags(self) -> None:
        key = instance_key({"wght": 400, "opsz": 12, "wdth": 100})
        self.assertEqual(key, "opsz:12|wdth:100|wght:400")

    def test_grid_axes_excludes_stat_only(self) -> None:
        axis_defs = axis_defs_from_request(self.request["axes"])
        grid = grid_axis_defs(axis_defs, self.request["axes"])
        tags = {axis.tag for axis in grid}
        self.assertEqual(tags, {"opsz", "wdth", "wght"})
        self.assertNotIn("ital", tags)

    def test_pinned_coords_for_stat_only(self) -> None:
        pinned = pinned_coords(self.request["axes"])
        self.assertEqual(pinned, {"ital": 0.0})

    def test_instance_count_without_filter(self) -> None:
        axis_defs = axis_defs_from_request(self.request["axes"])
        grid = grid_axis_defs(axis_defs, self.request["axes"])
        # 2 opsz × 2 wdth × 2 wght = 8
        self.assertEqual(count_included_instances(grid, []), 8)


if __name__ == "__main__":
    unittest.main()
