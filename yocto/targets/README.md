# Named targets

Create `yocto/targets/<board>-<profile>/` after completing `templates/target/requirements.md`.
Target files are trusted repository code: sources.conf and target.conf are sourced by Bash.
Do not run configurations from untrusted sources.

Each target requires:

- `sources.conf`: POKY_URL, POKY_TAG and exact 40-character POKY_COMMIT; BSP URLs/commits as needed.
- `target.conf`: runner settings described below.
- `local.conf`: BitBake MACHINE, DISTRO, image formats and target-specific settings;
  include `require /project/yocto/config/common.conf` for shared caches and defaults.

Example runner settings (replace placeholders; this is not a configured target):

```bash
RELEASE=scarthgap
IMAGE_RECIPE=product-example
TARGET_MACHINE=vendor-machine
EXTERNAL_LAYERS=("meta-vendor|https://example.com/vendor.git|EXACT_COMMIT")
LOCAL_LAYERS=(meta-product)
EXPORT_FILES=(product-example-vendor-machine.rootfs.wic.bz2 product-example-vendor-machine.rootfs.manifest)
SD_IMAGE_BZ2=product-example-vendor-machine.rootfs.wic.bz2
```

An external-layer entry is `repository-name|URL|commit|optional-layer-subdirectory`.
Use multiple entries with the same repository name for repositories containing multiple layers.
Use `EXTERNAL_LAYERS=()` when the MACHINE is already supported by Poky.
Use `LOCAL_LAYERS=()` when no local layer is required.
EXPORT_FILES lists exact deploy filenames; include manifests, maps and licenses as required.
SD_IMAGE_BZ2 is optional: it expands a bzipped SD image to `<target>.img`.
IMAGE_VERIFIER is optional: a Python script relative to scripts/ receiving the expanded image.
The supplied verify-kv260-image.py checks the KV260 boot files and SD layout.
Without a verifier, export copies and hashes files but does not validate boot structure.

Keep TARGET_MACHINE consistent with MACHINE in local.conf. Set IMAGE_FSTYPES there;
EXPORT_FILES does not control what BitBake builds. Match local layer compatibility to the release.
The supplied meta-product layer currently supports Scarthgap only.

Run `bash /project/scripts/image.sh <target> prepare`, then `parse`, `build`, and `export`.
Existing source directories must match their locks and be clean; the runner refuses to overwrite them.
Targets sharing a release must use the same Poky and external repository revisions.
For differing revisions, choose a distinct release namespace and separate sources.
Do not change the source locks of a target while it or another target using those sources is building.

The build command also exports to the local artifacts folder. Use export alone to copy
a completed image again without rebuilding. Both require the Compose /artifacts mount.
