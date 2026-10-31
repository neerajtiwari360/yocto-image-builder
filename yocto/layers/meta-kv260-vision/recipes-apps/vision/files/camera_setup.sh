#!/bin/sh
set -eu
width=1280
height=720
frames=0
while [ "$#" -gt 0 ]; do
    [ "$#" -ge 2 ] || exit 2
    case "$1" in
        --width) width=$2 ;;
        --height) height=$2 ;;
        --smoke-frames) frames=$2 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift 2
done
for value in "$width" "$height" "$frames"; do
    case "$value" in ''|*[!0-9]*) echo 'Expected positive integer dimensions/frame count' >&2; exit 2 ;; esac
done
[ "$width" -ge 320 ] && [ "$height" -ge 240 ] && [ $((width % 2)) -eq 0 ] && [ $((height % 2)) -eq 0 ]
topology=$(mktemp /run/kv260-media.XXXXXX)
trap 'rm -f "$topology"' EXIT HUP INT TERM
media=
attempt=0
while [ "$attempt" -lt 20 ]; do
    for candidate in /dev/media*; do
        [ -e "$candidate" ] || continue
        media-ctl -d "$candidate" -p > "$topology"
        ap=$(sed -n 's/.*entity [0-9][0-9]*: \(ap1302[^()]*\) ([0-9].*/\1/p' "$topology" | sed 's/ *$//' | head -n 1)
        csi=$(sed -n 's/.*entity [0-9][0-9]*: \([^()]*\.csiss\) ([0-9].*/\1/p' "$topology" | head -n 1)
        if [ -n "$ap" ] && [ -n "$csi" ]; then media=$candidate; break; fi
    done
    [ -z "$media" ] || break
    attempt=$((attempt + 1))
    sleep 0.5
done
[ -n "$media" ] || { echo 'J7 AP1302/CSI media graph missing; inspect dmesg and firmware' >&2; exit 1; }
media-ctl -d "$media" -V "\"$ap\":2 [fmt:UYVY8_1X16/${width}x${height} field:none]"
media-ctl -d "$media" -V "\"$csi\":0 [fmt:UYVY8_1X16/${width}x${height} field:none]"
media-ctl -d "$media" -V "\"$csi\":1 [fmt:UYVY8_1X16/${width}x${height} field:none]"
video=
for name in /sys/class/video4linux/video*/name; do
    [ -f "$name" ] || continue
    case "$(cat "$name")" in
        *isp_vcap_csi*)
            [ -z "$video" ] || { echo 'Multiple IAS capture nodes found' >&2; exit 1; }
            node=${name%/name}
            video=/dev/${node##*/}
            ;;
    esac
done
[ -n "$video" ] || { echo 'IAS capture node missing' >&2; exit 1; }
v4l2-ctl -d "$video" --set-fmt-video="width=$width,height=$height,pixelformat=NV12"
if [ "$frames" -gt 0 ]; then
    timeout 20 v4l2-ctl -d "$video" --stream-mmap=3 --stream-count="$frames" --stream-to=/dev/null
fi
printf 'media=%s\nvideo=%s\nwidth=%s\nheight=%s\npixel_format=NV12\n' "$media" "$video" "$width" "$height" > /run/kv260-camera.conf
cat /run/kv260-camera.conf
