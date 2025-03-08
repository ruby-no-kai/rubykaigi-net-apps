#!/bin/dumb-init /bin/bash
set -eu -o pipefail

if [[ ${1:-} = /* ]]; then
    exec "$@"
fi

exec /opt/dnsdist/bin/dnsdist "$@"
