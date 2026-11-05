#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
fixture="$temporary/PyresinQoL"
mkdir -p "$fixture/tools"
cp -R PyresinQoL.toc LICENSE Bindings.xml Core Settings Modules Media PyresinQoL_ResourceBar "$fixture/"
cp tools/check-package.sh "$fixture/tools/"
archive="$temporary/test.zip"

check() { bash "$fixture/tools/check-package.sh" "$@"; }
rejects() {
    if check "$@" > "$temporary/result" 2>&1; then
        echo "FAIL: accepted invalid package: $*" >&2
        exit 1
    fi
}
# Like the packager's move-folders: the resource bars become a second top-level addon with the license.
build() {
    rm -f "$archive"
    (cd "$temporary"; zip -qr "$archive" PyresinQoL -x 'PyresinQoL/tools/*' 'PyresinQoL/PyresinQoL_ResourceBar/*')
    rm -rf "$temporary/moved"
    mkdir "$temporary/moved"
    cp -R "$fixture/PyresinQoL_ResourceBar" "$temporary/moved/"
    cp "$fixture/LICENSE" "$temporary/moved/PyresinQoL_ResourceBar/"
    (cd "$temporary/moved"; zip -qr "$archive" PyresinQoL_ResourceBar)
}

version=$(check)
build
check --tag "v$version" --archive "$archive" >/dev/null
for tag in v999.0.0 "$version" "v$version-beta" 'v1.0.0; exit 0'; do rejects --tag "$tag"; done
for missing in LICENSE Bindings.xml Media/AddonIcon.tga Core/Bootstrap.lua PyresinQoL_ResourceBar/Bars.lua; do
    cp "$fixture/$missing" "$temporary/saved"
    entry="PyresinQoL/$missing"
    [[ "$missing" == PyresinQoL_ResourceBar/* ]] && entry=$missing
    zip -qd "$archive" "$entry"
    rejects --archive "$archive"
    rm "$fixture/$missing"
    rejects
    cp "$temporary/saved" "$fixture/$missing"
    build
done
for unwanted in tests/integration/core/settings.lua docs/logo.png .github/ci.yml; do
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
rm "$fixture/Core/unsafe-link"
lodToc="$fixture/PyresinQoL_ResourceBar/PyresinQoL_ResourceBar.toc"
sed -i 's/^## Version:.*/## Version: 9.9.9/' "$lodToc"
rejects
cp PyresinQoL_ResourceBar/PyresinQoL_ResourceBar.toc "$lodToc"
printf '\nMissing.lua\n' >> "$lodToc"
rejects
cp PyresinQoL_ResourceBar/PyresinQoL_ResourceBar.toc "$lodToc"
build
(cd "$temporary"; zip -qr "$archive" PyresinQoL/PyresinQoL_ResourceBar)
rejects --archive "$archive"

echo 'PASS: package contents, source integrity, TOC paths, icon, license, release versions and the resource bar addon'
