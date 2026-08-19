#!/bin/sh
# Run bootstrap.sh's Linux path end-to-end inside a disposable Debian
# container, using the local working trees of devbox + devbox-private
# (including uncommitted changes) instead of cloning from GitHub, and
# skipping the 1Password ssh-key step. See DEVBOX_LOCAL_TEST in
# bootstrap.sh for exactly what's skipped.
#
# Not covered: the macOS path (Homebrew, xcode-select), and the real
# ssh_key()/1Password flow.
#
#   ./test-bootstrap.sh
set -eu

cd "$(dirname "$0")"

IMAGE=devbox-bootstrap-test
PRIVATE_REPO="../devbox-private"

docker build -t "$IMAGE" -f docker/Dockerfile.bootstrap . >&2

set -- -v "$(pwd):/src/devbox:ro"
if [ -d "$PRIVATE_REPO" ]; then
    set -- "$@" -v "$(cd "$PRIVATE_REPO" && pwd):/src/devbox-private:ro"
fi

exec docker run --rm -it "$@" "$IMAGE"
