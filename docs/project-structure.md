# Project structure and growth

## Two different kinds of image

1. Local Docker build image: yocto-foundation:ubuntu22.04.
   Its Dockerfile lives in docker/. It provides compilers and build tools for your PC.
2. Device OS image: produced later by Yocto for a selected board and software profile.
   Its definitions belong in Yocto layers; final files may be .wic, .wic.gz or another format selected by that build.

A Docker rebuild does not build or update a device OS.

## Source of truth

Keep authored build definitions in Git: docker/, compose.yaml, yocto/, and docs/.
For actual Yocto work, use a Linux-filesystem checkout of this repository under /work/project.
The D: checkout is convenient for setup and documentation; do not run BitBake against /mnt/d or a Windows bind mount.
Synchronize authored changes through Git when the Linux checkout is created.
Do not keep independent, conflicting copies of custom layer definitions.

The Linux checkout has not been created yet; no Yocto sources have been fetched.

## Planned Yocto layers

Use standard Yocto layer conventions once we select a release and initialize real layers:

    yocto/layers/
      meta-product/
        conf/layer.conf
        conf/distro/product.conf
        recipes-core/images/product-minimal.bb
        recipes-core/images/product-gateway.bb
        recipes-core/packagegroups/packagegroup-product-base.bb
        recipes-apps/...
      meta-product-bsp/
        conf/layer.conf
        conf/machine/<custom-board>.conf
        recipes-bsp/...
        recipes-kernel/...

This tree is a future convention, not files already created.
meta-product contains shared OS policy and software.
Prefer upstream board layers such as meta-raspberrypi for supported boards.
Only create meta-product-bsp when local hardware customizations are necessary.
Do not copy and edit upstream vendor layers for each product.

Yocto references:
https://docs.yoctoproject.org/5.0.14/dev-manual/layers.html
https://docs.yoctoproject.org/5.0.14/dev-manual/custom-distribution.html

## Named targets

A target identifies one supported combination of:
- Pinned Yocto release and exact layer revisions.
- MACHINE: hardware model supported by the selected BSP layer.
- DISTRO: shared OS policy.
- Image recipe: software and features to install.
- Release version and any explicitly supported configuration variant.

Use stable target names such as board-a-minimal and board-a-gateway.
These names are illustrative; they are not Yocto MACHINE values.
Select a real configuration tool and file format when the release is chosen.
Do not invent arbitrary YAML and assume BitBake reads it.

## Persistent Linux storage

The existing Docker volume remains mounted at /work. No existing volume data was moved.

    /work/
      project/                 # future Linux checkout of this project
      layers/<release>/        # future pinned upstream repositories
      downloads/               # shared source downloads
      sstate-cache/            # reusable task cache
      builds/<release>/<target>/  # independent build directory per target
      exports/<release>/<target>/<version>/  # selected release deliverables

layers, downloads, sstate-cache, builds and exports already exist.
The nested release/target paths and project checkout will be created with the first build configuration.
Do not run two builds simultaneously in the same build directory.
Configure DL_DIR and SSTATE_DIR explicitly when real Yocto configuration is added; folder names alone do not configure BitBake.
Cache reuse depends on compatible task signatures. Plan disk and memory capacity as targets increase.

## Exported releases

Copy final deliverables to:

    artifacts/<release>/<target>/<version>/

Keep the flashed image, SHA256 checksums, package manifest, image file size,
root filesystem size where available, exact source/layer revisions and build settings together.
Image file size and installed filesystem usage are different measurements.
Use immutable version directories; do not silently replace an earlier release.
Large binary releases are excluded from Git here; publish them to an artifact store later.
Keep reusable source definitions in Git.

## Scaling to a fleet

Different hardware models usually need separate MACHINE configurations and builds.
Different software roles use separate image recipes while sharing package groups.
Identical physical devices normally reuse a release image.
Provision hostnames, per-device credentials and device IDs separately; do not bake shared secrets into a fleet image.
A separate Docker container image for every physical device is unnecessary.

## Current boundary

Docker foundations are validated. meta-product and rpi-zero2w-minimal are now configured for Scarthgap; see rpi-zero2w-minimal.md for the active target.
The active board is Raspberry Pi Zero 2 W, using pinned source revisions and a minimal console recipe. Release publishing and other board targets remain future work.

For the first target, the Windows project is mounted read-only at /project. Its authored layer is synchronized to /work/project-layers/meta-product. Target settings are included read-only; all compilation and generated output stay on Linux storage. The /work/project checkout described above remains a future option.
