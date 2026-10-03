#!/usr/bin/env python3
"""Compatibility entrypoint for the UI command contract checks."""
from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).parent / "tooling/ui-runner.py"), run_name="__main__")
