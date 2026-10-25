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

## 2. Define the required image

Fill in [the requirements checklist](templates/target/requirements.md). Choose a
Yocto release, compatible BSP, MACHINE, software recipe, boot format and acceptance criteria.
Create a target under `yocto/targets/<name>/` following [the target guide](yocto/targets/README.md).
The existing `rpi-zero2w-minimal` target is a working example.
The `kv260-hcsr04-minimal` target packages only the HC-SR04 application for the
Kria KV260; see [its build and first-boot guide](docs/kv260-hcsr04-minimal.md).

## 3. Prepare, build and export a selected target

```powershell
docker compose run --rm builder bash /project/scripts/image.sh rpi-zero2w-minimal prepare
docker compose run --rm builder bash /project/scripts/image.sh rpi-zero2w-minimal parse
docker compose run --rm builder bash /project/scripts/image.sh rpi-zero2w-minimal build
docker compose run --rm builder bash /project/scripts/image.sh rpi-zero2w-minimal export
```

`prepare` fetches exact locked sources and configures the target; `parse` checks metadata;
`build` produces the device OS, exports it and saves a checksum-verified copy to your local artifacts folder. `export` repeats export without rebuilding.
Exports are in `/work/exports/<release>/<target>/<tag>-<UTC timestamp>/`.
Local files are saved automatically to `artifacts/<release>/<target>/<version>/` in this checkout. No docker cp is needed. The original `scripts/rpi-zero2w.sh` commands still work.

## Repository layout

| Path | Purpose |
| --- | --- |
| `docker/`, `compose.yaml` | Reusable PC build environment and persistent Linux volume |
| `scripts/setup.sh` | Device-independent initialization and validation |
| `scripts/image.sh` | Generic target preparation, parsing, building and exporting |
| `templates/target/` | Requirements checklist before adding hardware |
| `yocto/config/` | Shared build configuration, without a MACHINE selection |
| `yocto/targets/<name>/` | Source locks, board settings and output selection |
| `yocto/layers/` | Authored device software and optional local BSP layers |
| `artifacts/` | Windows copies of completed exports, excluded from Git |
| `docs/` | Setup, structure and device instructions |

All compilation occurs under `/work` on Linux storage. `/project` is a read-only source mount.
Never remove the workspace volume unless you intend to delete builds, caches and exports.
See [the structure guide](docs/project-structure.md) and [Docker setup](docs/docker-setup.md).
