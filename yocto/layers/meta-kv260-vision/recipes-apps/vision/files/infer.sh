#!/bin/sh
set -eu
launcher=/opt/yunet/run.sh
[ -x "$launcher" ] || { echo 'Deploy the cross-compiled native package under /opt/yunet first.' >&2; exit 1; }
exec "$launcher" "$@"
