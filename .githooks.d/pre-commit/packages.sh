#!/usr/bin/env sh

set -e

get_staged_packages() {
  git diff --cached --name-only --diff-filter=ACM -- */PKGBUILD | xargs -r dirname
}

get_unstaged_packages() {
  git diff --name-only --diff-filter=ACM -- */PKGBUILD | xargs -r dirname
}

pkgver_changed() {
  ! git diff --cached --name-only -Gpkgver --quiet -- "$1"
}

pkgrel_changed() {
  ! git diff --cached --name-only -Gpkgrel --quiet -- "$1"
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
      sed -i -e 's/^\(pkgrel\)=.*/\1=1/' "${p}/PKGBUILD"
    else
      if ! pkgrel_changed "$p"; then
        cur_pkgrel=$(. "${p}/PKGBUILD" && echo $pkgrel)

        if ! arg_set "$cur_pkgrel"; then
          echo "Unable to detect pkgrel for package: ${p}"
          exit 1
        fi

        new_pkgrel=$(($cur_pkgrel+1))

        if ! arg_set "$new_pkgrel"; then
          echo "Unable to determine new pkgrel for package: ${p}"
          exit 1
        fi

        set_pkgrel "${p}/PKGBUILD" "$new_pkgrel"
      fi
    fi
  done
}

update_srcinfos() {
  for p in $(get_staged_packages); do
    pushd $p
    updpkgsums && makepkg --printsrcinfo > .SRCINFO
    popd
  done
}

update_pkgrels
update_srcinfos

for p in $(get_unstaged_packages); do
  git add -- "$p" 2>/dev/null || continue
done
