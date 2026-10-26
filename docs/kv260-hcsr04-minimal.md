# KV260 C development image

The historical `kv260-hcsr04-minimal` target and image recipe names are retained
so existing build commands and export paths continue to work. This target now
includes the lightweight `opkg` package manager and a persistent project workspace.
GCC, Make, development headers and the C++ toolchain are not preinstalled.
The broad `tools-sdk` and `dev-pkgs` features are disabled. HC-SR04 application, userspace driver,
sensor test code, FPGA preparation helper and sensor bitstream are removed.
Standard Linux board, GPIO and FPGA drivers remain available.

## Build and flash

From PowerShell at the repository root, with Docker Desktop running Linux containers:

```powershell
docker compose run --rm builder bash /project/scripts/image.sh kv260-hcsr04-minimal parse
docker compose run --rm builder bash /project/scripts/image.sh kv260-hcsr04-minimal build
```

The build exports a new image and checksum-verified artifacts to:

```text
artifacts/scarthgap-kv260/kv260-hcsr04-minimal/<version>/kv260-hcsr04-minimal.img
```

Previously exported images are unchanged. Flash the newly built `.img` onto a
spare SD card. Flashing replaces the card contents; back up your projects first.
The exported `.img` is a complete raw SD-card image suitable for Raspberry Pi
Imager's **Use custom** option. No conversion or additional build is needed:

1. Open Raspberry Pi Imager. If a device selection is required, select **No filtering**.
2. Select **Use custom** in the OS selection and choose
   `kv260-hcsr04-minimal.img` from the image export folder above.
3. Select the SD card, skip OS customisation if offered, and write the image.
4. Let verification finish, eject the card, and insert it into the KV260.

The image boots a KV260, not a Raspberry Pi. Imager is used only to write the SD
card. Wi-Fi, user and SSH customisation through Imager are not supported by this
image. The optional `c-toolchain.tar.gz` bundle is not an SD image and must not
be selected in Imager.

The layout has a 64 MiB FAT boot partition and a writable ext4 root partition.
The current kernel and boot assets occupy about 24 MB. If future boot assets
outgrow this partition, increase its size in `kv260-hcsr04.wks` before rebuilding.
Rootfs size follows installed contents, with no fixed minimum or extra development
space reserved. Yocto's normal filesystem overhead allowance is retained for
filesystem creation and metadata; WIC adds no further percentage or spare space.
Use a card larger than the exported image. Unused card space is not automatically
expanded. Expand the root partition later before large source transfers/builds.

To expand after deployment, power off the board and attach the SD card to a Linux
PC with `growpart` (usually the `cloud-guest-utils` package) and `e2fsprogs` installed.
Use `lsblk -f` to identify the SD card and unmount its partitions. For a card
identified as `/dev/sdX` (replace this placeholder with the actual SD-card device):

```sh
sudo growpart /dev/sdX 2
sudo e2fsck -f /dev/sdX2
sudo resize2fs /dev/sdX2
```

Proceed to `resize2fs` only after the filesystem check succeeds or reports errors
corrected. For an MMC device, the names are `/dev/mmcblkN` and `/dev/mmcblkNp2`.
These commands expand the existing root partition/filesystem to use the remaining
card space without reflashing; back up your projects first. Boot again and check
`df -h /opt/projects`.

## Boot

This is a 64-bit Cortex-A53 Linux image for the Kria K26 starter SOM on the KV260
carrier, revisions A/Z and B/1/2. It relies on existing QSPI firmware to initialize
the SOM and launch SD `boot.scr`; it does not build or flash BOOT.BIN or QSPI.
The existing firmware must expose `card1_name=SCK-KV-G`, carrier revision, and
support `part uuid` and `booti`. Manual boot of the previous sensor image has
succeeded; automatic boot on observed legacy QSPI firmware had a carrier-check
issue. This development image still requires hardware boot verification.

Use UART at 115200 8N1. Log in as `root` with no password for local bench use.
No SSH service or configured public online package feed is provided. Optional
C build tools can be installed from matching packages built on your PC, as below.
The boot script selects the matching carrier DTB and boots using the ext4
partition PARTUUID. Keep the working SD card and capture UART output on failure.

## Install the C compiler later

The base image contains `opkg`, not a compiler. Build and flash the new image
first; older images without `opkg` do not support these instructions. Expand the
root filesystem as described above before installing tools or compiling projects.

When you need C compilation, build an optional offline package bundle on the PC:

```powershell
docker compose run --rm builder bash /project/scripts/image.sh kv260-hcsr04-minimal c-packages
```

This exports `c-toolchain.tar.gz`, source locks and checksums under:

```text
artifacts/scarthgap-kv260/kv260-hcsr04-minimal/c-packages/<version>/
```

The archive contains the full indexed IPK feed from this target build so that
package dependencies are available. It may be large; it is separate from the SD
image. Only the requested C tools and their dependencies are installed, not every
package in the archive. Generate it using the same source locks and configuration
as the flashed image; regenerate the bundle when those change. Do not use Ubuntu,
Debian or arbitrary third-party packages on this Yocto image.

Copy the archive and SHA256SUMS plus sources.conf to a USB drive. On the board,
with the drive mounted at `/mnt/usb` and files at its root:

```sh
cd /mnt/usb
sha256sum -c SHA256SUMS
mkdir -p /mnt/usb/c-toolchain
tar -xzf c-toolchain.tar.gz -C /mnt/usb/c-toolchain
sh /mnt/usb/c-toolchain/install-c-toolchain.sh
```

Stop if checksums fail. The helper uses a temporary local `file://` feed and
installs GCC, the C preprocessor, binutils, Make, glibc development headers and
pkg-config. No network connection is required on the board. G++ and C++
development libraries are not requested. Installed packages survive reboot, but
reflashing replaces them. The helper removes its feed configuration afterward,
so the USB drive can be unmounted. Verify `gcc --version` and `make --version`.

## Compile and keep code on the board

After installing the optional C tools, transfer your source using a mounted USB drive, or create it through the UART
shell. For example, on the board:

```sh
mkdir -p /opt/projects/hello
cd /opt/projects/hello
cat > hello.c <<'EOF'
#include <stdio.h>
int main(void) { puts("Hello from KV260 C"); return 0; }
EOF
gcc -Wall -Wextra hello.c -o hello-c
./hello-c
sync
```

Sources and executables in `/opt/projects` are saved on the SD card and survive
normal reboots. Check with `df -h /opt/projects`. Shut down cleanly with `poweroff`.
Reflashing replaces these files. Saving files does not modify the original `.img`
on your PC, and the build system cannot automatically see changes on the board.
Programs do not automatically start at boot.

## Include your saved work in the next image

1. Stop programs that write to your project directory. Mount a USB drive and
   copy `/opt/projects` to it. For a drive already mounted at `/mnt/usb`:

   ```sh
   tar -czf /mnt/usb/kv260-projects.tar.gz -C /opt projects
   sync
   umount /mnt/usb
   ```

2. On the PC, extract the archive into a temporary folder. Copy the contents of
   its `projects` directory into this repository's directory:

   ```text
   yocto/layers/meta-kv260/recipes-devtools/board-projects/files/projects/
   ```

   Review the files and remove private data, temporary files and unwanted build
   outputs. Keep C sources, headers and Makefiles. You may also include
   executables built on this same AArch64 image; rebuild them if the ABI or
   libraries change. Use LF line endings in source scripts and Makefiles.

3. Run the image build command above. The `board-projects` recipe packages those
   files into `/opt/projects` in the new image. It does not compile them during
   the Yocto build. After flashing, install the optional C tools before compiling on the board.
   For automated compilation during every image build, create an application
   recipe that uses `${CC}`, declares library dependencies, and installs
   its executable, then add that package to `IMAGE_INSTALL` in the image recipe.

A full powered-off SD-card backup is another way to preserve the exact card,
including local changes. This is separate from a reproducible Yocto rebuild.

## Driver development

Userspace C drivers can be built with the same tools. Linux kernel modules
need a matching configured kernel build tree, generated headers and symbol
information; the C toolchain alone does not provide that environment. Build kernel
modules through Yocto against this image's kernel. Hardware-specific drivers may
also require a device-tree or FPGA design change. No sensor-specific FPGA design
is included in this image.

## Validation

After building, inspect the exported `.manifest` for `opkg` and `board-projects`.
Verify GCC, G++, Make, glibc development headers and the old sensor packages are
not installed in the base image. After installing the optional package bundle,
run the C example above, reboot, and confirm the tools and projects persist.
Structural image validation checks boot files and partition layout, not compiler
operation or physical hardware boot.

References: [Yocto image features](https://docs.yoctoproject.org/scarthgap/ref-manual/features.html#image-features)
and [root filesystem sizing](https://docs.yoctoproject.org/scarthgap/ref-manual/variables.html#term-IMAGE_ROOTFS_EXTRA_SPACE).
