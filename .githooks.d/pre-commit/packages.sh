#!/usr/bin/env sh

set -e

_RUNTIME_DEPS='updpkgsums makepkg git'

check_runtime_deps() {
  missing_deps=""
  for d in ${_RUNTIME_DEPS}; do
    if ! command -v "$d" > /dev/null; then
      missing_deps="$d $missing_deps"
    fi
  done
  if arg_set "$missing_deps"; then
    >&2 printf "FAIL\n"
    for d in ${missing_deps}; do
      >&2 printf "Command '%s' not found.\n" "$d"
    done
    >&2 printf "Hint: use 'pacman -F %s' to determine which packages to install." "$missing_deps"
    exit 1
  fi
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

arg_set() {
  [ -n "$1" ]
}

args_equal() {
  [ "$1" == "$2" ]
}

set_pkgrel() {
  find "$1" \
    -name PKGBUILD \
    -type f \
    -exec sed -i -e 's/^\(pkgrel=\).*$/\1'"$2"'/' {} \;
}

update_pkgrels() {
  for p in $(get_staged_packages); do
    if pkgver_changed "$p"; then
      echo "[ ${p} ] setting pkgrel to '1'"
      set_pkgrel "$p" "1"
    else
      echo "[ ${p} ] did not detect that pkgver had changed"
      if ! pkgrel_changed "$p"; then
        cur_pkgrel=$(grep '^pkgrel=' "${p}/PKGBUILD" | sed -e 's/^pkgrel=//')

        if ! arg_set "$cur_pkgrel"; then
          echo "[ ${p} ] unable to detect current pkgrel"
          exit 1
        fi

        new_pkgrel=$(($cur_pkgrel+1))

        if ! arg_set "$new_pkgrel"; then
          echo "[ ${p} ] unable to determine new pkgrel"
          exit 1
        fi

        echo "[ ${p} ] setting pkgrel to '${new_pkgrel}'"
        set_pkgrel "$p" "$new_pkgrel"
      fi
    fi
  done
}

update_srcinfos() {
  for p in $(get_staged_packages); do
    pushd $p >/dev/null 2>&1
    printf "[ ${p} ] updating package checksums... "
    if updpkgsums >/dev/null 2>&1; then
      printf "OKAY\n"
      printf "[ ${p} ] updating .SRCINFO... "
      if makepkg --printsrcinfo > .SRCINFO; then
        printf "OKAY\n"
      else
        printf "FAIL\n"
        exit 1
      fi
    else
      printf "FAIL\n"
      exit 1
    fi
    popd >/dev/null 2>&1
  done
}

check_runtime_deps
update_pkgrels
update_srcinfos

get_staged_packages | xargs git add 2>/dev/null
