#!/bin/bash
set -eo pipefail
source /project/yocto/targets/rpi-zero2w-minimal/sources.conf
poky=/work/layers/scarthgap/poky
rpi=/work/layers/scarthgap/meta-raspberrypi
build=/work/builds/scarthgap/rpi-zero2w-minimal
mode=build
if [ "$#" -gt 0 ]; then mode=$1; fi
mkdir -p /work/builds/scarthgap /work/logs
exec 9>/work/builds/scarthgap/rpi-zero2w-minimal.lock
flock -n 9 || { echo "This target is already in use"; exit 1; }
if [ ! -d "$poky/.git" ]; then
    test ! -e "$poky" || { echo "Refusing to replace existing source directory"; exit 1; }
    mkdir -p /work/layers/scarthgap
    git clone --depth 1 --branch "$POKY_TAG" "$POKY_URL" "$poky"
fi
if [ ! -d "$rpi/.git" ]; then
    test ! -e "$rpi" || { echo "Refusing to replace existing BSP directory"; exit 1; }
    git init "$rpi"
    git -C "$rpi" remote add origin "$RPI_URL"
    git -C "$rpi" fetch --depth 1 origin "$RPI_COMMIT"
    git -C "$rpi" checkout --detach FETCH_HEAD
fi
test "$(git -C "$poky" rev-parse HEAD)" = "$POKY_COMMIT" || { echo "Poky revision differs from lock"; exit 1; }
test "$(git -C "$rpi" rev-parse HEAD)" = "$RPI_COMMIT" || { echo "BSP revision differs from lock"; exit 1; }
test -z "$(git -C "$poky" status --porcelain)" || { echo "Poky has local changes"; exit 1; }
test -z "$(git -C "$rpi" status --porcelain)" || { echo "BSP has local changes"; exit 1; }
# Copy authored metadata to Linux storage; edit only /project's source copy.
product=/work/project-layers/meta-product
mkdir -p /work/project-layers
rsync -a /project/yocto/layers/meta-product/ "$product/"
source "$poky/oe-init-build-env" "$build" >/dev/null
include='require /project/yocto/targets/rpi-zero2w-minimal/local.conf'
if ! grep -Fxq "$include" conf/local.conf; then
    printf '\n%s\n' "$include" >> conf/local.conf
fi
for layer in "$rpi" "$product"; do
    if ! grep -Fq "$layer" conf/bblayers.conf; then
        printf '\nBBLAYERS += "%s"\n' "$layer" >> conf/bblayers.conf
    fi
done
case "$mode" in
    build) bitbake product-minimal ;;
    parse) bitbake -p ;;
    export)
        deploy="$build/tmp/deploy/images/raspberrypi0-2w"
        image="$deploy/product-minimal-raspberrypi0-2w.rootfs.wic.bz2"
        test -f "$image" || { echo "No completed image found"; exit 1; }
        version="yocto-5.0.14-$(date -u +%Y%m%dT%H%M%SZ)"
        output="/work/exports/scarthgap/rpi-zero2w-minimal/$version"
        mkdir -p "$(dirname "$output")"
        mkdir "$output"
        cp -L "$image" "$output/pi-zero2w-minimal.wic.bz2"
        bzip2 -dc "$image" > "$output/pi-zero2w-minimal.img"
        python3 /project/scripts/verify-sd-image.py "$output/pi-zero2w-minimal.img" | tee "$output/validation.txt"
        cp -L "$deploy/product-minimal-raspberrypi0-2w.rootfs.wic.bmap" "$output/pi-zero2w-minimal.wic.bmap"
        cp -L "$deploy/product-minimal-raspberrypi0-2w.rootfs.manifest" "$output/packages.manifest"
        cp /project/yocto/targets/rpi-zero2w-minimal/sources.conf "$output/"
        cp /project/yocto/targets/rpi-zero2w-minimal/local.conf "$output/"
        cp -a /project/yocto/layers/meta-product "$output/"
        printf 'Image: product-minimal\nMachine: raspberrypi0-2w (32-bit)\nPoky: %s\nBSP: %s\n' "$POKY_COMMIT" "$RPI_COMMIT" > "$output/build-info.txt"
        stat -c '%n: %s bytes' "$output/pi-zero2w-minimal.wic.bz2" >> "$output/build-info.txt"
        bzip2 -dc "$output/pi-zero2w-minimal.wic.bz2" | wc -c | sed 's/$/ bytes uncompressed SD image/' >> "$output/build-info.txt"
        (cd "$output"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
        printf '%s\n' "$output" | tee /work/exports/rpi-zero2w-minimal-latest.txt
        ;;
    *) echo "Usage: bash /project/scripts/rpi-zero2w.sh [build|parse|export]"; exit 2 ;;
esac
