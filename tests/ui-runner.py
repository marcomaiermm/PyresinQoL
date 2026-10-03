#!/usr/bin/env python3
"""Exercise the UI commands while another checkout replaces their image tags."""

import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile


def docker_mock():
    state_path = Path(os.environ["UI_RUNNER_STATE"])
    state = json.loads(state_path.read_text())
    args = sys.argv[1:]

    def finish(code=0):
        state_path.write_text(json.dumps(state))
        raise SystemExit(code)

    if args[0] == "build":
        state["builds"] += 1
        iidfile = Path(args[args.index("--iidfile") + 1])
        state["iidfiles"].append(str(iidfile))
        assert not iidfile.exists(), "Build ID file must be private and new"
        if state["failure"] == "build":
            finish(1)
        state["image"] = "sha256:" + f'{state["builds"]:064x}'
        iidfile.write_text(state["image"] + "\n")
        # Another checkout replaces the shared tag before the first container starts.
        state["tag"] = "sha256:" + "f" * 64
    elif args[0] == "run":
        reference = args[args.index("--no-saved-vars") - 1]
        resolved = state["tag"] if reference.startswith("pyresinqol-ui:") else reference
        size = next(arg.split("=", 1)[1] for arg in args if arg.startswith("WOW_SIM_SCREEN_SIZE="))
        state["runs"].append({"reference": reference, "resolved": resolved, "size": size})
        # The tag keeps changing between resolutions as well.
        state["tag"] = "sha256:" + f'{256 + len(state["runs"]):064x}'
        if resolved != state["image"]:
            print("Container started from another checkout's image", file=sys.stderr)
            finish(1)
        if "--name" in args:
            name = args[args.index("--name") + 1]
            state["containers"][name] = {"size": size, "screenshot": "screenshot" in args}
        if size == "1280x720" and (
            (state["failure"] == "startup" and args[-1] == "lua-errors")
            or (state["failure"] == "screenshot" and "screenshot" in args)
        ):
            finish(1)
    elif args[:2] == ["container", "inspect"]:
        finish(0 if args[-1] in state["containers"] else 1)
    elif args[:2] == ["image", "inspect"]:
        finish(0 if args[-1] in (state["image"], "pyresinqol-ui:forever", "pyresinqol-ui:dev") else 1)
    elif args[0] == "exec":
        if "printenv" in args:
            print(state["containers"][args[1]]["size"])
    elif args[0] == "cp":
        name = args[1].split(":", 1)[0]
        assert state["containers"][name]["screenshot"]
        Path(args[2]).write_text("Mock screenshot\n")
    elif args[0] == "rm":
        state["containers"].pop(args[-1], None)
    else:
        raise AssertionError(f"Unexpected Docker command: {args}")
    finish()


def main():
    source = Path(__file__).resolve().parent.parent
    sizes = (source / "tests/ui/resolutions.txt").read_text().splitlines()
    with tempfile.TemporaryDirectory(prefix="pyresinqol-ui-runner-") as temporary:
        root = Path(temporary)
        checkout = root / "checkout"
        for name in ("tests/run-ui.sh", "tools/ui.sh", "tests/ui/resolutions.txt"):
            target = checkout / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / name, target)
        mock = root / "bin/docker"
        mock.parent.mkdir()
        shutil.copyfile(__file__, mock)
        mock.chmod(0o755)
        state_path = root / "state.json"
        scratch = root / "tmp"
        scratch.mkdir()
        display = root / "display"
        desktop = socket.socket(socket.AF_UNIX)
        desktop.bind(str(display))
        env = {
            **os.environ,
            "PATH": str(mock.parent) + os.pathsep + os.environ["PATH"],
            "UI_RUNNER_STATE": str(state_path),
            "TMPDIR": str(scratch),
            "XDG_RUNTIME_DIR": str(root),
            "WAYLAND_DISPLAY": display.name,
            "WOW_UI_RESOLUTION": "1280x720",
            "WOW_UI_WOW_PATH": "",
        }
        cached_image = "sha256:" + f'{1:064x}'
        scenarios = (
            ("test matrix", ["tests/run-ui.sh"], "", 2 * len(sizes), 0, True, ""),
            ("single render", ["tools/ui.sh", "render"], "", 2, 1, True, ""),
            ("render matrix", ["tools/ui.sh", "render-matrix"], "", 2 * len(sizes), len(sizes), True, ""),
            ("desktop preview", ["tools/ui.sh", "preview"], "", 1, 0, True, ""),
            ("failed screenshot", ["tools/ui.sh", "render-matrix"], "screenshot", 2 * len(sizes), len(sizes) - 1, False, ""),
            ("failed startup", ["tools/ui.sh", "render-matrix"], "startup", 2 * len(sizes) - 1, len(sizes) - 1, False, ""),
            ("failed build", ["tests/run-ui.sh"], "build", 0, 0, False, ""),
            ("cached tests", ["tests/run-ui.sh"], "", 2 * len(sizes), 0, True, cached_image),
            ("cached rendering", ["tools/ui.sh", "render-matrix"], "", 2 * len(sizes), len(sizes), True, cached_image),
            ("cached preview", ["tools/ui.sh", "preview"], "", 1, 0, True, cached_image),
            ("reject mutable cached tag", ["tests/run-ui.sh"], "", 0, 0, False, "pyresinqol-ui:forever"),
            ("reject mutable renderer tag", ["tools/ui.sh", "render"], "", 0, 0, False, "pyresinqol-ui:dev"),
            ("reject missing cached image", ["tools/ui.sh", "render"], "", 0, 0, False, "sha256:" + "f" * 64),
            ("reject missing test image", ["tests/run-ui.sh"], "", 0, 0, False, "sha256:" + "f" * 64),
        )
        try:
            for label, command, failure, runs, artifacts, succeeds, prebuilt in scenarios:
                shutil.rmtree(checkout / "dist", ignore_errors=True)
                state_path.write_text(json.dumps({
                    "builds": 0, "iidfiles": [], "runs": [], "containers": {}, "failure": failure,
                    "image": cached_image, "tag": "sha256:" + "f" * 64,
                }))
                result = subprocess.run(
                    ["bash", *command], cwd=checkout, env={**env, "WOW_UI_IMAGE": prebuilt},
                    stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=20,
                )
                state = json.loads(state_path.read_text())
                assert (result.returncode == 0) == succeeds, (label, result.stderr)
                assert state["builds"] == (0 if prebuilt else 1), (label, state["builds"])
                assert len(state["runs"]) == runs, (label, state["runs"])
                assert all(run["resolved"] == state["image"] for run in state["runs"]), label
                if label in ("test matrix", "render matrix", "cached tests", "cached rendering"):
                    assert [run["size"] for run in state["runs"]] == [size for size in sizes for _ in range(2)]
                assert len(list((checkout / "dist/ui").glob("render-*.webp"))) == artifacts, label
                assert all(not Path(path).parent.exists() for path in state["iidfiles"]), label
                assert not any(scratch.iterdir()), label
                if command[-1] != "preview":
                    assert not state["containers"], (label, state["containers"])
                print(f"PASS: {label}, immutable image despite concurrent tag changes")
        finally:
            desktop.close()


if __name__ == "__main__":
    if Path(sys.argv[0]).name == "docker":
        docker_mock()
    else:
        main()
