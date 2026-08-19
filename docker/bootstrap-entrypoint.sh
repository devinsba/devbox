#!/bin/sh
set -eux

mkdir -p "${HOME}/.local/opt"
cp -r /src/devbox "${HOME}/.local/opt/devbox"

if [ -d /src/devbox-private ]; then
  cp -r /src/devbox-private "${HOME}/.local/opt/devbox-private"
fi

export DEVBOX_LOCAL_TEST=1
sh "${HOME}/.local/opt/devbox/bootstrap.sh"
