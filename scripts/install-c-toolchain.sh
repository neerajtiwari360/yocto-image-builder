#!/bin/sh
# Run as root on the board, from an unpacked c-toolchain.tar.gz bundle.
set -eu
test "$(id -u)" = 0 || { echo "Run as root on the KV260"; exit 1; }
bundle=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
case "$bundle" in *' '*) echo "Extract the bundle to a path without spaces"; exit 1 ;; esac
test -d "$bundle/ipk" || { echo "Missing ipk feed beside this script"; exit 1; }
command -v opkg >/dev/null || { echo "Boot the new package-management image first"; exit 1; }
feeds=/etc/opkg/c-toolchain-local.conf
mkdir -p /etc/opkg
: > "$feeds"
# Only expose architectures accepted by this board's generated opkg configuration.
for arch in $(opkg print-architecture | awk '$1 == "arch" {print $2}'); do
    if test -f "$bundle/ipk/$arch/Packages.gz"; then
        printf 'src/gz c-local-%s file://%s/ipk/%s\n' "$arch" "$bundle" "$arch" >> "$feeds"
    fi
done
test -s "$feeds" || { echo "No matching package architectures found"; exit 1; }
trap 'rm -f "$feeds"' EXIT HUP INT TERM
opkg update
opkg --no-install-recommends install gcc gcc-symlinks cpp cpp-symlinks \
    binutils binutils-symlinks make glibc-dev pkgconfig
sync
gcc --version
echo "C build tools installed. The temporary feed configuration has been removed."
