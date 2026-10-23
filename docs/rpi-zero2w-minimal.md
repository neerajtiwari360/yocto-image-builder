# Small first image for Raspberry Pi Zero 2 W

Target: rpi-zero2w-minimal. Machine: raspberrypi0-2w (32-bit).
Image recipe: product-minimal. Yocto 5.0.14 / Scarthgap.
Exact Poky and Raspberry Pi BSP commits are locked in sources.conf.

This basic console OS contains BusyBox, init, boot components. Standard USB keyboard support is built into the Pi kernel.
No desktop, Python, Docker runtime, SSH server or Wi-Fi connection manager is installed.
Wi-Fi credentials and automatic wireless setup are not included.
Use a mini-HDMI display and USB OTG keyboard, or a correctly connected 3.3 V UART adapter.
UART is enabled. Login as root with no password for this local learning image.
Set production authentication before deploying beyond local testing.

## Locations

docker/: local PC build tools.
yocto/layers/meta-product/: device software recipe.
yocto/targets/rpi-zero2w-minimal/: board selection, source lock and build settings.
scripts/rpi-zero2w.sh: prepare, build and export commands.
/project: read-only mount of the Windows project.
/work/project-layers/meta-product: synchronized Linux copy for BitBake; edit the Windows original.
/work/layers/scarthgap/: pinned upstream sources.
/work/builds/scarthgap/rpi-zero2w-minimal/: generated Linux build files.
/work/downloads and /work/sstate-cache: shared caches.
/work/exports/scarthgap/rpi-zero2w-minimal/<version>/: versioned exports.
artifacts/scarthgap/rpi-zero2w-minimal/<version>/: Windows copy of a completed release.

There is no virtual-PC target. A Pi SD image cannot be boot-tested as a normal x86 Windows VM.

## Commands from PowerShell

    cd D:\Github\yocto-image-builder
    docker compose run --rm builder bash /project/scripts/rpi-zero2w.sh parse
    docker compose run --rm builder bash /project/scripts/rpi-zero2w.sh build
    docker compose run --rm builder bash /project/scripts/rpi-zero2w.sh export

Four parallel tasks, two compiler jobs per task and rm_work limit memory and disk pressure.
The first build downloads and compiles tools much larger than the final image.
A failed or stopped build can usually be resumed with the build command.

## Initial background build

    docker logs -f yocto-rpi-zero2w-build
    docker inspect --format '{{.State.Status}} {{.State.ExitCode}}' yocto-rpi-zero2w-build

Stop if needed:

    docker stop -t 60 yocto-rpi-zero2w-build

Do not start another build of this target while it is running.

## Outputs and testing

Deploy directory:
/work/builds/scarthgap/rpi-zero2w-minimal/tmp/deploy/images/raspberrypi0-2w/

Expected SD image: product-minimal-raspberrypi0-2w.rootfs.wic.bz2
Exports include the compressed SD image, bmap, package manifest, source locks,
target configuration, authored layer snapshot, byte sizes and SHA256 checksums.

The export includes pi-zero2w-minimal.img ready for Raspberry Pi Imager's Use Custom option; the .wic.bz2 is its compressed copy.
Flashing erases the selected SD card; verify the destination yourself.
No SD card is flashed by the scripts.

The BSP reserves a 100 MiB boot partition. Actual rootfs and compressed/uncompressed SD image sizes are measured after building.
Physical boot on a Pi Zero 2 W is required to validate the hardware.

References:
https://github.com/agherzan/meta-raspberrypi/tree/scarthgap
https://docs.yoctoproject.org/5.0.14/ref-manual/system-requirements.html

Console display uses the built-in legacy framebuffer; VC4 graphics is disabled and GPU memory is set to 16 MB for this console-only test.
