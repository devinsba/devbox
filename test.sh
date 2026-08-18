#!/bin/sh
# Run the ansible playbook inside a disposable Debian container so roles can
# be tried out without touching the real machine.
#
#   ./test.sh                 # run the fnm + uv roles
#   ./test.sh fnm,uv,antidote # run a custom set of tagged roles
#   ./test.sh shell           # drop into the container instead of running the playbook
set -eu

cd "$(dirname "$0")"

IMAGE=devbox-test

docker build -t "$IMAGE" -f docker/Dockerfile.test . >&2

if [ "${1:-}" = "shell" ]; then
    exec docker run --rm -it \
        -v "$(pwd):/devbox:ro" \
        --entrypoint /bin/bash \
        "$IMAGE"
fi

TAGS="${1:-fnm,uv}"

exec docker run --rm -it \
    -v "$(pwd):/devbox:ro" \
    "$IMAGE" \
    --tags "$TAGS"
