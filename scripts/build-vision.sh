#!/bin/bash
set -uo pipefail
log=/artifacts/kv260-vision-build.log
rm -f /artifacts/kv260-vision-build.exit
printf 'Building kv260-vision-minimal; log: %s\n' "$log"
bash /project/scripts/image.sh kv260-vision-minimal build > "$log" 2>&1
status=$?
printf '%s\n' "$status" > /artifacts/kv260-vision-build.exit
tail -30 "$log"
exit "$status"
