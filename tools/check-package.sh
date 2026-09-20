#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "Package check failed: $*" >&2; exit 1; }
tag='' archive=''
while (( $# )); do
    case "$1" in
        --tag) (( $# >= 2 )) || fail 'Missing tag'; tag=$2; shift 2 ;;
        --archive) (( $# >= 2 )) || fail 'Missing archive'; archive=$2; shift 2 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done

toc=PyresinQoL.toc
[[ -f "$toc" ]] || fail "Missing $toc"
version=$(sed -n 's/^## Version: //p' "$toc" | tr -d '\r')
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'TOC must contain one Version: X.Y.Z'
[[ -z "$tag" || "$tag" == "v$version" ]] || fail "Release tag must be v$version"

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
for path in "$toc" LICENSE Media/AddonIcon.tga; do
    [[ -f "$path" && ! -L "$path" ]] || fail "Missing or unsafe file: $path"
done
for directory in Core Settings Modules Media; do
    [[ -d "$directory" && ! -L "$directory" ]] || fail "Missing or unsafe directory: $directory"
done
[[ -z $(find Core Settings Modules Media -type l -print -quit) ]] || fail 'Runtime files must not be symlinks'
{
    printf '%s\n' "$toc" LICENSE
    find Core Settings Modules Media -type f
} | LC_ALL=C sort > "$temporary/files"

while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    [[ -z "$line" || "$line" == \#* ]] && continue
    line=${line//\\//}
    grep -Fxq -- "$line" "$temporary/files" || fail "Missing or unpackaged TOC path: $line"
done < "$toc"

if [[ -n "$archive" ]]; then
    unzip -tq "$archive" >/dev/null || fail 'Corrupt ZIP'
    unzip -Z1 "$archive" > "$temporary/entries"
    [[ -z $(LC_ALL=C sort "$temporary/entries" | uniq -d) ]] || fail 'Duplicate ZIP entries'
    # Check paths and Unix symlink attributes before anything extracts the ZIP.
    if zipinfo -l "$archive" | grep '^l' > /dev/null; then fail 'ZIP must not contain symlinks'; fi
    {
        printf '%s\n' 'PyresinQoL/'
        sed 's|^|PyresinQoL/|' "$temporary/files"
        find Core Settings Modules Media -type d | sed 's|^|PyresinQoL/|; s|$|/|'
        if grep -Fxq 'PyresinQoL/CHANGELOG.md' "$temporary/entries"; then
            printf '%s\n' 'PyresinQoL/CHANGELOG.md'
        fi
    } | LC_ALL=C sort > "$temporary/expected"
    LC_ALL=C sort "$temporary/entries" > "$temporary/actual"
    diff -u "$temporary/expected" "$temporary/actual" || fail 'Missing or unexpected ZIP paths'
    while IFS= read -r path; do
        unzip -p "$archive" "PyresinQoL/$path" | cmp -s - "$path" || fail "ZIP differs from tested source: $path"
    done < "$temporary/files"
fi
printf '%s\n' "$version"
