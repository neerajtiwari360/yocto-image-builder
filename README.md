# Yocto image builder

One reusable Linux Docker environment, with explicit configurations for each device image.
Docker contains PC build tools; Yocto recipes select the software installed on a device.
Python and Git in the builder do not automatically go into a device image.

For **live J7 camera video and ML face detection over HDMI**, follow the
`kv260-vision-hdmi` commands below. The target name in the command selects the
image contents; the builder does not automatically choose the camera image.

| Target | What the SD image provides |
| --- | --- |
| `kv260-vision-hdmi` | J7 camera, YuNet ML and HDMI preview; camera starts at boot, ML starts manually |
| `kv260-vision-minimal` | J7 camera and ML runtime, operated through the console without HDMI preview |

## 1. Prepare the foundation (no device required)

From PowerShell at the repository root, with Docker Desktop in Linux container mode:

```powershell
docker compose build
docker compose run --rm builder bash /project/scripts/setup.sh
```

This validates tools, Linux filesystem behavior and non-root compilation and creates
workspace directories. It does not fetch a BSP or generate a device image.
The existing `yocto-foundation-workspace` volume is retained.

## 2. KV260 camera, ML and HDMI image

Use `kv260-vision-hdmi` for the J7 AR1335/AP1302 camera, SmartCam B3136 FPGA
firmware, YuNet face detection and HDMI display. See the
[HDMI build and boot guide](docs/kv260-vision-hdmi.md) for hardware details and diagnostics.

## 3. Prepare, build and export the HDMI image

```powershell
docker compose run --rm builder bash /project/scripts/image.sh kv260-vision-hdmi prepare
docker compose run --rm builder bash /project/scripts/image.sh kv260-vision-hdmi parse
docker compose run --rm builder bash /project/scripts/image.sh kv260-vision-hdmi build
```

`prepare` fetches exact locked sources and configures the target; `parse` checks metadata;
`build` produces the device OS, exports it and saves a checksum-verified copy to your local artifacts folder. `export` repeats export without rebuilding.
Exports are in `/work/exports/<release>/<target>/<tag>-<UTC timestamp>/`.
Local files are saved automatically to `artifacts/<release>/<target>/<version>/` in this checkout. No docker cp is needed.

Flash **`kv260-vision-hdmi.img`** from the newest timestamped folder under
`artifacts/scarthgap-kv260/kv260-vision-hdmi/`. Choose the newest export within
this target, since other target folders contain different images.
Flashing replaces the SD card contents.

After boot, camera-only HDMI preview starts automatically. Log in as `root`
through PuTTY (115200 baud, 8N1, no flow control), then run these commands
**on the board**:

```sh
systemctl start yunet-inference   # enable ML face boxes and five landmarks
systemctl stop yunet-inference    # return to camera-only preview
```

ML starts manually after each reboot. To inspect startup problems, run:

```sh
systemctl status kv260-vision yunet-hdmi yunet-inference --no-pager -l
journalctl -b -u kv260-vision -u yunet-hdmi -u yunet-inference --no-pager -n 100
```


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

The optional [`kv260-vision-hdmi` target](docs/kv260-vision-hdmi.md) adds systemd
and an independent DRM/KMS preview on CPU3. Camera-only video starts at boot;
starting YuNet adds face boxes and five landmarks. It reuses the existing PS
display hardware and SmartCam bitstream. ML inference remains manually controlled.
In the board's PuTTY console, log in as `root` and run
`systemctl start yunet-inference` to turn AI on or
`systemctl stop yunet-inference` to turn it off. Camera preview continues while
AI is off. See the HDMI guide for connection settings, status checks and the
verified boot-mount fix.

The [FaceGuard architecture review](docs/faceguard-architecture-review.md) maps
the two repositories, component interfaces and migration risks. See
[migration results](docs/faceguard-migration-results.md) for the host tests,
ARM64 build validation and remaining hardware acceptance work.

The [KV260-only cleanup record](docs/project-cleanup.md) lists archived legacy
pipelines and experiments, retained dependencies and recovery information.
