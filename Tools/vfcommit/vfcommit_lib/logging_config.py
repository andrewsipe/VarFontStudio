"""Minimal logging for vfcommit (no FontCore console styles)."""

from __future__ import annotations

import logging


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
