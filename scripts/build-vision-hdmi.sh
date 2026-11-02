#!/bin/bash
set -uo pipefail
log=/artifacts/kv260-vision-hdmi-build.log
rm -f /artifacts/kv260-vision-hdmi-build.exit
printf 'Building optional kv260-vision-hdmi; log: %s\n' "$log"
bash /project/scripts/image.sh kv260-vision-hdmi build > "$log" 2>&1
status=$?
printf '%s\n' "$status" > /artifacts/kv260-vision-hdmi-build.exit
tail -30 "$log"
exit "$status"
