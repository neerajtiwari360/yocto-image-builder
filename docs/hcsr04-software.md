# HC-SR04 software and image boundary

The user has confirmed that the flashed minimal image and sensor have been tested
on the KV260. This confirms that the image can support this sensor setup; it is
not a calibration or a guarantee for different wiring, FPGA designs or sensors.
The reported image boots manually with the existing 2020.2-era QSPI firmware.
The automatic boot script's carrier check remains an open issue.

## Separate code responsibilities

The source snapshot is at
`yocto/layers/meta-kv260/recipes-apps/hcsr04-reader/files/source/`:

| Source | Responsibility | Recipe |
| --- | --- | --- |
| `driver/hcsr04_driver.c` | GPIO ownership, trigger, edge timestamps, timeouts and release | `hcsr04-driver` |
| `include/hcsr04_driver.h` | Public interface between driver and application | `hcsr04-driver` |
| `app/main.c` | CLI, acquisition scheduling and CSV output | `hcsr04-reader` |
| `app/distance.c`, `app/distance.h` | Convert echo timestamps to distance | `hcsr04-reader` |

The sensor driver is a userspace C library using the Linux GPIO driver already
built into the kernel. It is not a loadable kernel module. Its recipe produces
`libhcsr04.a` and stages its header/library for application builds. The application
recipe depends on that library. Driver changes rebuild the library and relink the
application; application changes do not rebuild the driver library. Static linking
keeps deployment to one `hcsr04-reader` executable, without an extra runtime library.

The root filesystem, GPIO/FPGA kernel support and pinned EMIO firmware form the
image baseline. The GPIO offsets, firmware identity checks and protected-wiring
confirmation are part of the driver contract, not application measurement logic.

## What needs rebuilding?

| Change | Required work |
| --- | --- |
| CSV format, sampling policy or distance calculation | Rebuild and deploy `hcsr04-reader` |
| Driver's GPIO/timing implementation, with same hardware interface | Rebuild driver and reader; deploy the relinked reader |
| Public driver header/API | Update callers; rebuild driver and reader |
| Kernel driver configuration, device tree or FPGA pin routing | Rebuild the affected platform components and validate on hardware; normally export a new image |

No compiler, Git or Python needs to be installed on the Kria. Compile for ARM64
using the same pinned Yocto environment. A Windows/x86 executable cannot run there.
Keep the existing tested SD image as a baseline while testing software updates.

## Build only the software

Open a builder from PowerShell in this repository:

```powershell
docker compose run --rm builder
```

Inside the container, with no other build of this target running:

```sh
bash /project/scripts/image.sh kv260-hcsr04-minimal prepare
source /work/layers/scarthgap-kv260/poky/oe-init-build-env /work/builds/scarthgap-kv260/kv260-hcsr04-minimal
flock -n /work/builds/scarthgap-kv260/kv260-hcsr04-minimal.lock bitbake hcsr04-reader
```

This builds the reader package and required library, not a complete SD image.
Packages appear under the build's `tmp/deploy/rpm/` tree. A software build does not
automatically change the running board. Choose an explicit package/binary transfer
workflow; this image currently provides UART and does not include an SSH server or
package manager. Include the new package in a subsequent image with the normal build
command when a new flashable release is desired.

The original project at `D:/Github/kria-project/software/hcsr04` is separate from
this snapshot. Editing it alone does not change an image. Port deliberate changes
into the corresponding driver/app files here and update `ORIGIN.md` before release.
Hardware-independent conversion and CLI tests are available with:

```powershell
docker compose run --rm builder bash /project/scripts/test-hcsr04.sh
```
