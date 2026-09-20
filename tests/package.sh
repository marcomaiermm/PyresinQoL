#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
fixture="$temporary/PyresinQoL"
mkdir -p "$fixture/tools"
cp -R PyresinQoL.toc LICENSE Core Settings Modules Media "$fixture/"
cp tools/check-package.sh "$fixture/tools/"
archive="$temporary/test.zip"

check() { bash "$fixture/tools/check-package.sh" "$@"; }
rejects() {
    if check "$@" > "$temporary/result" 2>&1; then
        echo "FAIL: accepted invalid package: $*" >&2
        exit 1
    fi
}
build() {
    rm -f "$archive"
    (cd "$temporary"; zip -qr "$archive" PyresinQoL -x 'PyresinQoL/tools/*')
}

version=$(check)
build
check --tag "v$version" --archive "$archive" >/dev/null
for tag in v999.0.0 "$version" "v$version-beta" 'v1.0.0; exit 0'; do rejects --tag "$tag"; done
for missing in LICENSE Media/AddonIcon.tga Core/Bootstrap.lua; do
    cp "$fixture/$missing" "$temporary/saved"
    zip -qd "$archive" "PyresinQoL/$missing"
    rejects --archive "$archive"
    rm "$fixture/$missing"
    rejects
    cp "$temporary/saved" "$fixture/$missing"
    build
done
for unwanted in tests/menu.lua docs/logo.png .github/ci.yml; do
    mkdir -p "$fixture/$(dirname "$unwanted")"
    echo unwanted > "$fixture/$unwanted"
    build
    rejects --archive "$archive"
    rm -r "${fixture:?}/${unwanted%%/*}"
done
build
printf '\n-- changed after packaging\n' >> "$fixture/Core/Bootstrap.lua"
rejects --archive "$archive"
cp Core/Bootstrap.lua "$fixture/Core/Bootstrap.lua"
printf '\nModules/Missing.lua\n' >> "$fixture/PyresinQoL.toc"
rejects
cp PyresinQoL.toc "$fixture/PyresinQoL.toc"
sed -i 's/^## Version:.*/## Version: invalid/' "$fixture/PyresinQoL.toc"
rejects
cp PyresinQoL.toc "$fixture/PyresinQoL.toc"
ln -s ../LICENSE "$fixture/Core/unsafe-link"
rejects

echo 'PASS: package contents, source integrity, TOC paths, icon, license and release versions'
