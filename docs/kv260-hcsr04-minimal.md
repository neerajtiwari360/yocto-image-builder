# KV260 offline console image

The historical `kv260-hcsr04-minimal` target and image recipe names are retained
so existing build commands and export paths continue to work. This target now
uses loopback-only networking and a persistent project workspace. No Ethernet
or Wi-Fi interface is configured to come up automatically; no DHCP is requested.
No package manager is installed, and no network download is needed on the board.
GCC, Make, development headers and the C++ toolchain are not preinstalled.
The `tools-sdk`, `dev-pkgs` and `package-management` features are disabled. HC-SR04 application, userspace driver,
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
image. Keep Ethernet unplugged for physical network isolation.

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
support `part uuid` and `booti`. The boot script accepts whitespace padding around
the exact `SCK-KV-G` carrier name reported by legacy QSPI firmware, while rejecting
other carriers and extra name tokens. This boot-script fix still needs an automatic
boot test on the board; no QSPI firmware update is needed for the name check.

Older flashed images may stop at `ZynqMP>` with a carrier-check failure. Keep
sensor power off and boot those images temporarily with:

```text
setenv card1_name SCK-KV-G
fatload mmc 1:1 0x10000000 boot.scr
source 0x10000000
```

After Linux starts, enter `root` at `login:`. These U-Boot commands do not save
firmware settings and must be repeated after reset until the SD boot script is
updated. Reflashing replaces project files, so back them up first.

Use UART at 115200 8N1. Log in as `root` with no password for local bench use.
There is no SSH service, package manager or automatic Ethernet/Wi-Fi setup.
USB host support, UART, SD boot, GPIO and FPGA kernel support remain available.
The Linux network stack and administration commands remain, so root can explicitly
configure networking; this is an offline boot policy, not removal of kernel networking.
The boot script selects the matching carrier DTB and boots using the ext4
partition PARTUUID. Keep the working SD card and capture UART output on failure.

## Build applications on the laptop and transfer offline

Cross-compile applications inside the laptop's Docker/Yocto environment against
this image's ARM64 configuration and libraries. Do not copy Windows executables.
The board does not need GCC, package installation or a network connection to run
an already compiled application. The laptop build may fetch upstream sources;
that is independent of networking on the board.

For HC-SR04, the source and Docker cross-build helper are maintained separately
in `D:/Github/kria-project/software/hcsr04`; see that folder's README. This base
image does not preinstall the sensor executable or its FPGA firmware.

The preferred deployment connection is the existing COM-port UART link, with no
Ethernet or USB flash drive. A laptop sender can encode binary files as octal
escapes and send paced shell `printf` commands. The board shell reconstructs the
bytes into a file. For example, this demonstrates the mechanism with a text file:

```sh
mkdir -p /opt/projects
printf '\110\145\154\154\157\012' > /opt/projects/serial-check.txt
cat /opt/projects/serial-check.txt
sha256sum /opt/projects/serial-check.txt
```

For an executable, transfer to a temporary file, compare its SHA256 with the
laptop original, then rename it and make it executable. A sender must pace chunks
and check acknowledgements to avoid overrunning the UART shell. A complete binary
serial-transfer helper is not included yet; this method has not yet been validated
end-to-end for an executable. Previous live deployment used Ethernet, not serial.

The roughly 104 KB HC-SR04 executable is practical to transfer over UART. Its
roughly 7.8 MB FPGA bitstream is much slower; it can instead be included at image
build time. This base image does not include either artifact automatically.
Keep the HC-SR04 sensor powered off while preparing FPGA/GPIO, and follow the
separate sensor project's safe-start instructions. No package installation is
required. USB host support remains available, but a USB drive is not required.

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
   the Yocto build. Compile on the laptop; copied source is not compiled on the board.
   For automated compilation during every image build, create an application
   recipe that uses `${CC}`, declares library dependencies, and installs
   its executable, then add that package to `IMAGE_INSTALL` in the image recipe.

A full powered-off SD-card backup is another way to preserve the exact card,
including local changes. This is separate from a reproducible Yocto rebuild.

## Driver development

Userspace C drivers can be cross-compiled on the laptop with the same tools. Linux kernel modules
need a matching configured kernel build tree, generated headers and symbol
information; the C toolchain alone does not provide that environment. Build kernel
modules through Yocto against this image's kernel. Hardware-specific drivers may
also require a device-tree or FPGA design change. No sensor-specific FPGA design
is included in this image.

## Validation

The build verifies that `/etc/network/interfaces` enables only loopback and
that no compiler or package-manager executables are present. After flashing,
check `ip link` and `ip addr`: Ethernet should be DOWN without an IP address.
Verify `command -v opkg` and `command -v gcc` find nothing. Test serial transfer and
application execution, then confirm project files persist after reboot.
Structural image validation checks boot files and partition layout, not compiler
operation or physical hardware boot.

References: [Yocto image features](https://docs.yoctoproject.org/scarthgap/ref-manual/features.html#image-features)
and [root filesystem sizing](https://docs.yoctoproject.org/scarthgap/ref-manual/variables.html#term-IMAGE_ROOTFS_EXTRA_SPACE).
