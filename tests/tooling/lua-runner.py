#!/usr/bin/env python3
"""Check discovery and process-failure behavior in isolated miniature suites."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    source = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="pyresinqol-lua-runner-") as temporary:
        root = Path(temporary)
        (root / "tests/unit/core").mkdir(parents=True)
        (root / "tests/integration/core").mkdir(parents=True)
        (root / "bin").mkdir()
        shutil.copyfile(source / "tests/run.sh", root / "tests/run.sh")
        runner = root / "bin/luajit"
        runner.write_text('#!/bin/sh\necho "$*" >> "$RUNNER_CALLS"\ncase "$1" in */fail.lua) exit 7 ;; esac\n')
        runner.chmod(0o755)
        calls = root / "calls"
        env = {**os.environ, "PATH": str(runner.parent) + os.pathsep + os.environ["PATH"], "RUNNER_CALLS": str(calls)}

        def check(label, args, code, expected):
            calls.write_text("")
            result = subprocess.run(["sh", "tests/run.sh", *args], cwd=root, env=env,
                                    capture_output=True, text=True, timeout=10)
            assert result.returncode == code, (label, result.returncode, result.stdout, result.stderr)
            assert calls.read_text().splitlines() == expected, (label, calls.read_text())
            print("PASS:", label)
            return result

        unit = root / "tests/unit/core/pass.lua"
        unit.touch()
        integration = root / "tests/integration/core/pass.lua"
        integration.touch()
        both = ["tests/integration/core/pass.lua", "tests/unit/core/pass.lua"]
        check("discovers both layers", [], 0, both)
        check("unit selector", ["unit"], 0, [both[1]])
        check("domain selector includes both layers", ["core"], 0, both)
        for name in ("settings.lua", "settings-search.lua"):
            scenario = root / "tests/integration/core" / name
            scenario.touch()
            path = str(scenario.relative_to(root))
            variants = [path, *(f"{path} {mode}" for mode in ("de", "disabled", "modules-disabled"))]
            check(f"{name} runs every settings variant", ["core"], 0, [both[0], *variants, both[1]])
            scenario.unlink()
        check("invalid selector", ["unknown"], 2, [])
        check("extra selector", ["unit", "core"], 2, [])
        check("empty selected domain", ["castbar"], 1, [])
        failure = root / "tests/integration/core/fail.lua"
        failure.touch()
        result = check("continues after scenario failure", [], 1, ["tests/integration/core/fail.lua", *both])
        assert "2 passed, 1 failed" in result.stdout and "Failed scenarios:" in result.stderr
        failure.unlink()
        shutil.rmtree(root / "tests/integration")
        check("missing layer cannot silently pass", [], 1, [])
        (root / "tests/integration").mkdir()
        fake_find = root / "bin/find"
        fake_find.write_text('#!/bin/sh\nprintf "tests/unit/core/pass.lua\\n"\nexit 1\n')
        fake_find.chmod(0o755)
        check("partial discovery failure cannot silently pass", [], 1, [])


if __name__ == "__main__":
    main()
