#!/bin/sh
# Start an image on whatever docker daemon is configured and ask it for
# /health and / from the inside. Used by the build job before the push.
# usage: container-smoke.sh IMAGE [EXPECTED_VERSION]
set -eu

image=$1
expected=${2:-}
name="smoke-$$"

cleanup() {
    docker rm -f "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

get() {
    docker exec "$name" python -c \
        "import sys, urllib.request as u; sys.stdout.write(u.urlopen('http://127.0.0.1:8000$1', timeout=2).read().decode())"
}

docker run -d --name "$name" "$image" >/dev/null

tries=0
until get /health >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 20 ]; then
        docker logs "$name" >&2
        echo "image did not answer on /health" >&2
        exit 1
    fi
    sleep 1
done
echo "/health ok after $tries retries"

if [ -n "$expected" ]; then
    get / | grep -q "\"version\":\"$expected\"" || {
        echo "version in / is not $expected" >&2
        get / >&2
        exit 1
    }
    echo "version $expected ok"
fi
