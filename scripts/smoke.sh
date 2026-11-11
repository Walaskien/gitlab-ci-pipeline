#!/bin/sh
# Check a deployed instance over HTTP.
# usage: smoke.sh BASE_URL [EXPECTED_VERSION]
set -eu

base=$1
expected=${2:-}

fetch() {
    # the docker:cli image has wget from busybox but no curl
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --max-time 3 "$base$1"
    else
        wget -qO- -T 3 "$base$1"
    fi
}

tries=0
until fetch /health 2>/dev/null | grep -q '"status":"ok"'; do
    tries=$((tries + 1))
    if [ "$tries" -ge 30 ]; then
        echo "no healthy answer from $base/health" >&2
        exit 1
    fi
    sleep 1
done
echo "health ok"

if [ -n "$expected" ]; then
    fetch / | grep -q "\"version\":\"$expected\"" || {
        echo "wrong version served, wanted $expected" >&2
        fetch / >&2 || true
        exit 1
    }
    echo "version $expected ok"
fi

fetch /metrics | grep -q '^http_requests_total' || {
    echo "/metrics has no http_requests_total" >&2
    exit 1
}
echo "metrics ok"
