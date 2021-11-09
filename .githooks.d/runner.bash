#!/usr/bin/env bash

set -e

log() {
    local prefix="git-hooks"

    case "$1" in
        fatal)
            shift
            printf "${prefix}: ${hook_name:-core}: fatal: $*\n"
            exit 1
            ;;
    esac
}

readonly hook_name="$1"
readonly args="${@:2}"

# Error out if no hook name was provided
if [ -z "$hook_name" ]; then
    log fatal "usage: $0 <hook-name>"
fi

readonly git_root=$(git rev-parse --show-toplevel)
readonly hook_root=$(git config --local --get core.hooksPath 2>/dev/null | xargs -r dirname)

# Search the given paths for directories matching the hook_root variable
function find_hook_dirs() {
    local parents

    for p in $@; do
        if [ -d "${p}/${hook_root}/${hook_name}" ]; then
            find "${p}/${hook_root}/${hook_name}" \
              -mindepth 1 \
              -maxdepth 1 \
              -not -type d \
              -perm -u=x,g=x,o=x \
              -print0 |\
            xargs -0 -I script sh script "$args"
        fi

        # If the current path is the git root, stop
        if [ "$p" = "$git_root" ]; then
            break
        fi

        if [ "${p%/*}" != "$p" ] && [ "$p" != "$git_root" ]; then
            local parent="${p%/*}"
        else
            local parent="$git_root"
        fi

        if [ "${parents%*$parent}" = "$parents" ]; then
            if [ -z "$parents" ]; then
                parents="$parent"
            else
                parents="${parents} ${parent}"
            fi
        fi
    done

    if [ -n "$parents" ]; then
        find_hook_dirs "$parents"
    fi
}

find_hook_dirs $(git diff --cached --name-only | xargs -r dirname | sort -u)
