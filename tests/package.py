"""Run with python3 tests/package.py; no game client or uploads required."""
import importlib.util
from pathlib import Path
import shutil
import stat
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_package", ROOT / "tools/check_package.py")
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def rejects(callback):
    try:
        callback()
    except ValueError:
        return
    raise AssertionError("Invalid package was accepted")


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    version, files = checks.source_files(ROOT)
    for name in files:
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
    archive = root / "test.zip"

    def build(omit=None, extra=None, changed=None):
        with zipfile.ZipFile(archive, "w") as package:
            for name in sorted(files - {omit}):
                package.writestr(f"PyresinQoL/{name}", b"changed" if name == changed else (root / name).read_bytes())
            if extra:
                package.writestr(extra, "unexpected")

    build()
    assert checks.check_archive(root, archive, f"v{version}") == version
    for tag in ("v999.0.0", version, f"v{version}-beta", "v1.0.0; exit 0"):
        rejects(lambda: checks.source_files(root, tag))
    for missing in ("LICENSE", "Media/AddonIcon.tga", "Core/Bootstrap.lua"):
        build(omit=missing)
        rejects(lambda: checks.check_archive(root, archive))
    for extra in ("PyresinQoL/tests/menu.lua", "PyresinQoL/docs/logo.png", "PyresinQoL/.github/ci.yml", "OtherAddon/file", "PyresinQoL/../escape"):
        build(extra=extra)
        rejects(lambda: checks.check_archive(root, archive))
    build()
    with zipfile.ZipFile(archive, "a") as package:
        link = zipfile.ZipInfo("PyresinQoL/CHANGELOG.md")
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        package.writestr(link, "../../outside")
    rejects(lambda: checks.check_archive(root, archive))
    build(extra="PyresinQoL/.github/")
    rejects(lambda: checks.check_archive(root, archive))
    build(changed="Core/Bootstrap.lua")
    rejects(lambda: checks.check_archive(root, archive))
    toc = root / "PyresinQoL.toc"
    original = toc.read_text()
    toc.write_text(original + "\nModules/Missing.lua\n")
    rejects(lambda: checks.source_files(root))
    toc.write_text(original.replace(f"## Version: {version}", "## Version: invalid"))
    rejects(lambda: checks.source_files(root))
    toc.write_text(original)
    (root / "Media/AddonIcon.tga").unlink()
    rejects(lambda: checks.source_files(root))

print("PASS: package contents, source integrity, TOC paths, icon, license and release versions")
