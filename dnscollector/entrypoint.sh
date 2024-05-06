#!/bin/bash
set -euo pipefail

if [[ ${1:-} = /* ]]; then
    exec "$@"
fi

exec /usr/local/bin/dnscollector "$@"
