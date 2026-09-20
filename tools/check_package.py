"""Validate the source manifest and, optionally, a distributable ZIP."""
import argparse
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = "PyresinQoL"
VERSION = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def source_files(root, tag=None):
    toc = root / f"{ADDON}.toc"
    text = toc.read_text()
    versions = re.findall(r"^## Version: (.+)$", text, re.MULTILINE)
    if len(versions) != 1 or not re.fullmatch(VERSION, versions[0]):
        raise ValueError("TOC must contain exactly one Version: X.Y.Z")
    version = versions[0]
    if tag is not None and tag != f"v{version}":
        raise ValueError(f"Release tag must be v{version}, got {tag!r}")
    files = {toc.name, "LICENSE", "Media/AddonIcon.tga"}
    for directory in ("Core", "Settings", "Modules", "Media"):
        for path in (root / directory).rglob("*"):
            if path.is_symlink():
                raise ValueError(f"Symlinks are not allowed in packages: {path}")
            if path.is_file():
                files.add(path.relative_to(root).as_posix())
    for line in text.splitlines():
        line = line.strip().replace("\\", "/")
        if line and not line.startswith("#"):
            path = PurePosixPath(line)
            if path.is_absolute() or ".." in path.parts or line not in files:
                raise ValueError(f"Invalid or unpackaged TOC path: {line}")
    for name in files:
        if (root / name).is_symlink() or not (root / name).is_file():
            raise ValueError(f"Missing or unsafe package file: {name}")
    return version, files


def check_archive(root, archive, tag=None):
    version, files = source_files(root, tag)
    expected = {f"{ADDON}/{name}" for name in files}
    # BigWigs adds release notes to the package.
    allowed = expected | {f"{ADDON}/CHANGELOG.md"}
    with zipfile.ZipFile(archive) as package:
        names = package.namelist()
        directories = {str(parent) + "/" for name in allowed
                       for parent in PurePosixPath(name).parents if str(parent) != "."}
        for entry in package.infolist():
            name = entry.filename
            path = PurePosixPath(name)
            if (not path.parts or path.is_absolute() or ".." in path.parts
                    or path.parts[0] != ADDON or stat.S_ISLNK(entry.external_attr >> 16)
                    or (entry.is_dir() and name not in directories)):
                raise ValueError(f"Unsafe ZIP path: {name}")
        entries = [entry.filename for entry in package.infolist() if not entry.is_dir()]
        if len(names) != len(set(names)) or not expected <= set(entries) <= allowed:
            raise ValueError("ZIP contains missing, duplicate or unexpected files")
        for name in files:
            if package.read(f"{ADDON}/{name}") != (root / name).read_bytes():
                raise ValueError(f"ZIP differs from tested source: {name}")
        if package.testzip() is not None:
            raise ValueError("ZIP integrity check failed")
    return version


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag")
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    try:
        if args.archive:
            print(check_archive(ROOT, args.archive, args.tag))
        else:
            print(source_files(ROOT, args.tag)[0])
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Package check failed: {error}\n")
