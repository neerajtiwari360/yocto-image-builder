# Yocto image builder

One reusable Linux Docker environment, with explicit configurations for each device image.
Docker contains PC build tools; Yocto recipes select the software installed on a device.
Python and Git in the builder do not automatically go into a device image.

## 1. Prepare the foundation (no device required)

From PowerShell at the repository root, with Docker Desktop in Linux container mode:

```powershell
docker compose build
docker compose run --rm builder bash /project/scripts/setup.sh
```

This validates tools, Linux filesystem behavior and non-root compilation and creates
workspace directories. It does not fetch a BSP or generate a device image.
The existing `yocto-foundation-workspace` volume is retained.

## 2. Xilinx Kria KV260 image

The `kv260-hcsr04-minimal` target builds a minimal console image
for the Kria KV260, with loopback-only networking and a persistent `/opt/projects`
workspace. No package manager or compiler is installed. Cross-compile applications
on the PC and transfer over UART serial, or include them in the image at build time.
HC-SR04 software and firmware are not preinstalled.
The historical target name is retained for existing build commands; see
[the build, first-boot and project-saving guide](docs/kv260-hcsr04-minimal.md).

## 3. Prepare, build and export a selected target

```powershell
docker compose run --rm builder bash /project/scripts/image.sh kv260-hcsr04-minimal prepare
docker compose run --rm builder bash /project/scripts/image.sh kv260-hcsr04-minimal parse
docker compose run --rm builder bash /project/scripts/image.sh kv260-hcsr04-minimal build
docker compose run --rm builder bash /project/scripts/image.sh kv260-hcsr04-minimal export
```

`prepare` fetches exact locked sources and configures the target; `parse` checks metadata;
`build` produces the device OS, exports it and saves a checksum-verified copy to your local artifacts folder. `export` repeats export without rebuilding.
Exports are in `/work/exports/<release>/<target>/<tag>-<UTC timestamp>/`.
Local files are saved automatically to `artifacts/<release>/<target>/<version>/` in this checkout. No docker cp is needed.

## Repository layout

| Path | Purpose |
| --- | --- |
| `docker/`, `compose.yaml` | Reusable PC build environment and persistent Linux volume |
| `scripts/setup.sh` | Device-independent initialization and validation |
| `scripts/image.sh` | Generic target preparation, parsing, building and exporting |
| `yocto/config/` | Shared build configuration, without a MACHINE selection |
| `yocto/targets/<name>/` | Source locks, board settings and output selection |
| `yocto/layers/` | Authored device software and optional local BSP layers |
| `artifacts/` | Windows copies of completed exports, excluded from Git |
| `docs/` | Setup, structure and device instructions |

All compilation occurs under `/work` on Linux storage. `/project` is a read-only source mount.
Never remove the workspace volume unless you intend to delete builds, caches and exports.
See [the structure guide](docs/project-structure.md) and [Docker setup](docs/docker-setup.md).

## KV260 J7 camera and DPU image

The separate `kv260-vision-minimal` target adds the AR1335/AP1302 J7 camera,
SmartCam B3136 FPGA firmware and a headless VART/XIR inference runtime.
The image includes the optimized native YuNet runtime and the verified SmartCam
B3136 model. Run `kv260-infer --frames 300` after boot; autorun is disabled by default.
See [camera/DPU build and deployment](docs/kv260-vision-minimal.md).
