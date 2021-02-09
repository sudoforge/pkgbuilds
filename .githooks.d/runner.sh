#!/usr/bin/env sh

HOOKNAME="$1"
if [ -z "${HOOKNAME+x}" ]; then
  echo "Usage: $0 <hook-name>"
  exit 1
fi

GITROOT=$(git rev-parse --show-toplevel)
HOOKROOT=$(git config --local --get core.hooksPath 2>/dev/null | xargs -r dirname)
HOOKDIR="${GITROOT}/${HOOKROOT}/${HOOKNAME}"

if [ -d "$HOOKDIR" ]; then
  find "$HOOKDIR" -not -type d -executable -print0 | xargs -0 -I script sh script "${@:2}"
fi
