#!/usr/bin/env bash

set -e

log() {
    case "$1" in
        info) echo "${@:2}" > /dev/stdout ; exit 1 ;;
        fatal) echo "[ ERR ] ${@:2}" > /dev/stderr ; exit 1 ;;
    esac
}

get_staged_packages() {
    git diff --cached --name-only --diff-filter=ACM -- */PKGBUILD | xargs -r dirname
}

pkgver_changed() {
    ! git diff --cached --name-only --exit-code -G '^pkgver' -- "$1" 1>/dev/null
}

pkgrel_changed() {
    ! git diff --cached --name-only --exit-code -G '^pkgrel' -- "$1" 1>/dev/null
}

get_pkgver() {
    v=$(grep -o '^pkgver=.*$' "$1" 2>/dev/null)
    echo "${v##*=}"
}

get_relnotes_uri() {
    pkgpath="$1"
    pkgname="${1##*/}"
    pkgver="$2"

    case "$pkgname" in
        firebase-tools)
            echo "https://github.com/firebase/firebase-tools/releases/tag/v${pkgver}"
            ;;
        google-cloud-sdk)
            tarball="${pkgpath}/${pkgname}_${pkgver}.orig.tar.gz"
            [ ! -f "$tarball" ] && log fatal "archive does not exist: ${tarball}" > /dev/stderr

            ts=$(date +%F -r "${pkgpath}/${pkgname}_${pkgver}.orig.tar.gz")
            [ -z "${ts+x}" ] && log fatal "unable to generate timestamp"

            v=$(tr -d '.' <<< "$pkgver")
            [ -z "${v+x}" ] && log fatal "unable to generate version string"

            echo "https://cloud.google.com/sdk/docs/release-notes#${v}_${ts}"
            ;;
    esac
}

if dest=$(mktemp); then
    # always remove the temporary file
    trap 'rm -f "${dest}"' EXIT

    trailer="Release-Notes"

    for p in $(get_staged_packages); do
        if pkgver_changed "$p" && ! pkgrel_changed "$p"; then
            pkgver=$(get_pkgver "${p}/PKGBUILD")
            relnote=$(get_relnotes_uri "$p" "$pkgver")

            if [ -n "$relnote" ]; then
                # avoid using --in-place, which was added in git v2.8
                # avoid using --if-exists, which was added in git v2.15
                if ! git -c trailer.ifexists=doNothing interpret-trailers \
                        --trailer "${trailer}: ${relnote}"\
                        < "$1" > "$dest"; then
                    echo "unable to insert trailer: ${trailer}"
                    exit 1
                fi

                if ! mv "$dest" "$1"; then
                    echo "unable to move '${dest}' to '${1}'"
                    exit 1
                fi
            fi
        fi
    done
else
    echo "unable to create temporary file"
    exit 1
fi
