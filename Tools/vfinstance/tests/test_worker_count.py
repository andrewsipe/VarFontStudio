#!/usr/bin/env python3
"""Tests for parallel worker capping in vfinstance."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from vfinstance_lib.engine import DEFAULT_MAX_WORKERS, resolve_worker_count


class ResolveWorkerCountTests(unittest.TestCase):
    def test_default_caps_at_eight(self) -> None:
        with patch("vfinstance_lib.engine.os.cpu_count", return_value=16):
            self.assertEqual(resolve_worker_count(None, 405), DEFAULT_MAX_WORKERS)

    def test_caps_by_cpu(self) -> None:
        with patch("vfinstance_lib.engine.os.cpu_count", return_value=4):
            self.assertEqual(resolve_worker_count(8, 405), 4)

    def test_caps_by_instance_count(self) -> None:
        with patch("vfinstance_lib.engine.os.cpu_count", return_value=16):
            self.assertEqual(resolve_worker_count(8, 3), 3)

    def test_explicit_lower_request(self) -> None:
        with patch("vfinstance_lib.engine.os.cpu_count", return_value=16):
            self.assertEqual(resolve_worker_count(2, 100), 2)

    def test_invalid_request_falls_back(self) -> None:
        with patch("vfinstance_lib.engine.os.cpu_count", return_value=16):
            self.assertEqual(resolve_worker_count("nope", 100), DEFAULT_MAX_WORKERS)

    def test_zero_total(self) -> None:
        self.assertEqual(resolve_worker_count(8, 0), 1)


if __name__ == "__main__":
    unittest.main()
