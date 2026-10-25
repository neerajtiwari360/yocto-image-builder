# KV260 minimal HC-SR04 image

The user has confirmed physical image/sensor testing on the KV260. See
[the software separation guide](hcsr04-software.md) for driver/application updates
without rebuilding the full OS. Automatic boot on the observed legacy QSPI
firmware still needs the carrier-check issue resolved; manual boot has succeeded.

This target builds a 64-bit Cortex-A53 UART console image for a Kria K26 starter
SOM on the KV260 Vision AI carrier, revisions A/Z and B/1/2. It includes BusyBox,
the Linux GPIO/FPGA drivers, the HC-SR04 C reader and a pinned EMIO bitstream.
It does not include AI applications, a desktop, Python, Git, a compiler or an SSH
server on the device. Python and compilers in build logs are host build dependencies.
Build helpers use standard Yocto user-mode QEMU, rather than the Xilinx full-system
emulator fork. QEMU is not installed on the device.

Source is a snapshot of `D:/Github/kria-project/software/hcsr04`; see its ORIGIN.md
in the recipe. The I2C/GY-521 helper and other sensor applications are excluded.
The application's firmware identity and GPIO checks remain enabled. Only the
firmware node path is ported to the vendor 6.6 kernel's `/fpga-region` node.

## Build and local output

From PowerShell in `D:/Github/yocto-image-builder`:

```powershell
docker compose run --rm builder bash /project/scripts/image.sh kv260-hcsr04-minimal build
```

The build downloads pinned sources, cross-compiles the C application and exports
the image automatically to:

```text
artifacts/scarthgap-kv260/kv260-hcsr04-minimal/<version>/kv260-hcsr04-minimal.img
```

The release also contains a compressed WIC, bmap, package manifest, source/config
snapshots, structural validation and SHA256SUMS. Export verifies checksums on the
Windows copy. The separate source/build namespace preserves the Pi configuration.

The SD layout uses 64 MiB FAT boot plus ext4 root. Actual sizes are reported by
validation after building; they are not predetermined. Structural validation
does not prove successful hardware boot or sensor accuracy.

## Boot firmware and first boot

This is a Linux SD image. It relies on the KV260's existing QSPI firmware to
initialize the K26 and launch SD `boot.scr`. It builds neither BOOT.BIN nor a QSPI
update and performs no firmware flashing. The existing firmware must expose
`card1_name=SCK-KV-G`, carrier revision and support `part uuid` and `booti`.
An existing PetaLinux 2022.1 installation is recorded in kria-project, but the
actual QSPI version and this new kernel/firmware combination must be checked on UART.
If boot fails, capture UART output before changing QSPI. Retain the working SD card.

Flash the `.img` onto a spare SD card and boot with sensor power off. Use UART
115200 8N1. Login is `root`, with no password for this local bench image. There is
no remote login service. This configuration is for local development.

The boot script selects AMD's matching KV260 carrier DTB, obtains the ext4
partition's PARTUUID and boots Linux directly without an initramfs. It refuses a
non-KV260 carrier. Kernel DTBs come from the same pinned kernel sources as Image.

## Prepare the FPGA and run only HC-SR04

Keep HC-SR04 sensor power off during boot and FPGA changes. Disconnect GY-521 and
other devices using these GPIO lines. Retain the project's verified J2 wiring:
TRIG J2.1/offset 78, protected ECHO J2.3/offset 79 and common ground J2.10.
ECHO needs the voltage divider described in `kria-project/docs/13-hcsr04.md`;
do not connect a 5 V ECHO signal directly to the Kria pin.

On the KV260 UART console:

```sh
hcsr04-prepare --confirm-sensor-power-off
hcsr04-reader --confirm-protected-wiring --wait
```

Stop on errors. After the reader reports READY, verify physical fan operation,
power the sensor using the existing protected wiring, and press ENTER for ten
readings. The preparation command mounts configfs, checks board identity and
conflicting overlays, loads the pinned FPGA design and checks operating state.
No Python, xmutil or on-board compilation is required. FPGA loading and acquisition
are manual; neither is automatically started at boot.

For another measurement while the FPGA is still configured:

```sh
hcsr04-reader --confirm-protected-wiring --samples=100 --period-ms=100 > readings.csv
```

The reader releases GPIO ownership after exiting; the pin state is then no longer
guaranteed. Switch off sensor power before reboot, shutdown or FPGA changes.

## Source references

- Vendor BSP: https://github.com/Xilinx/meta-xilinx/tree/8759e6effd1996c15d16d092860ea7fa4ac1653a
- Kernel: https://github.com/Xilinx/linux-xlnx/tree/2b7f6f70a62a52a467bed030a27c2ada879106e9
- EMIO bitstream: https://github.com/ikwzm/Kv260-Pmod-gpio-emio/tree/33fbc93e46f942093b355023ee8e614aecebf989
- Vendor overlay reset references: https://github.com/Xilinx/kria-base-firmware/blob/d512881ad56fcb8ad3bffea543280c5b357bb9ea/k26_starter_kits/k26_starter_kits.dtsi

The firmware recipe verifies the compressed bitstream SHA256 and K26 IDCODE before
installation and installs its BSD license. The custom overlay uses the matching
vendor FPGA region and reset identifiers. Source/compiler tests can run without
hardware using `docker compose run --rm builder bash /project/scripts/test-hcsr04.sh`.
