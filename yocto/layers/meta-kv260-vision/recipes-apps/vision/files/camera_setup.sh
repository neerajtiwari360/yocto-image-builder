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
rm -f /run/kv260-camera.conf
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
# SmartCam fixes CSI to YUV420 (DT data type 0x18), exposed by this Xilinx
# kernel as VYYUYY8_1X24 (0x2100). UYVY is YUV422 and fails link validation.
# Upstream media-ctl lacks this vendor format name, so use the numeric ioctl.
ap_node=$(media-ctl -d "$media" -e "$ap")
csi_node=$(media-ctl -d "$media" -e "$csi")
for node_pad in "$ap_node:2" "$csi_node:0" "$csi_node:1"; do
    node=${node_pad%:*}
    pad=${node_pad##*:}
    v4l2-ctl -d "$node" --set-subdev-fmt="pad=$pad,width=$width,height=$height,code=0x2100,field=none"
    actual=$(v4l2-ctl -d "$node" --get-subdev-fmt="pad=$pad")
    printf '%s\n' "$actual"
    printf '%s\n' "$actual" | grep -q 'Mediabus Code *: 0x2100' || { echo "Unexpected camera bus format on $node pad $pad" >&2; exit 1; }
    printf '%s\n' "$actual" | grep -q "Width/Height *: $width/$height" || { echo "Unexpected camera dimensions on $node pad $pad" >&2; exit 1; }
done
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
actual=$(v4l2-ctl -d "$video" --get-fmt-video)
printf '%s\n' "$actual"
printf '%s\n' "$actual" | grep -q 'Number of planes *: 1' || { echo 'NV12 capture must expose one contiguous memory plane' >&2; exit 1; }
if [ "$frames" -gt 0 ]; then
    timeout -s KILL 20 v4l2-ctl -d "$video" --stream-mmap=3 --stream-count="$frames" --stream-to=/dev/null
fi
printf 'media=%s\nvideo=%s\nwidth=%s\nheight=%s\npixel_format=NV12\n' "$media" "$video" "$width" "$height" > /run/kv260-camera.conf
cat /run/kv260-camera.conf
