# Foundation and device targets

The foundation is device independent: docker/ installs host tools, compose.yaml mounts
persistent Linux storage, and scripts/setup.sh validates the environment without fetching a BSP.
Changing a board does not require a board-specific Docker image.
The current Ubuntu 22.04 foundation is intended for Scarthgap; check host compatibility
before choosing another Yocto release. This is a Yocto workflow, not a Buildroot or Android builder.

Author metadata in the Windows checkout, mounted read-only at /project.
The runner copies selected local layers into Linux storage before invoking BitBake.
Do not edit the generated copies. Local layers are isolated per release and target.

```text
/work/
  layers/<release>/poky/
  layers/<release>/<external-repository>/
  project-layers/<release>/<target>/<local-layer>/
  builds/<release>/<target>/
  downloads/
  sstate-cache/
  logs/
  exports/<release>/<target>/<version>/
```

The runner preserves the existing volume, upstream sources, builds and caches. Local layers are synchronized into the isolated path for the selected target.

The KV260 target uses the meta-kv260 layer for its hardware configuration, sensor software and image recipe.

Do not run manual BitBake commands against a target while the runner is building it.
The runner locks each target and serializes shared source preparation. Source revisions
are immutable during a build; a changed lock fails rather than silently updating a checkout.

Exports contain selected deploy files, target settings, actual generated configuration,
local layer snapshots and SHA256SUMS. The version comes from the pinned Poky tag.
Physical boot and device-specific acceptance testing remain separate requirements.
Build and export automatically copy verified releases to artifacts/<release>/<target>/<version>/ on Windows through the /artifacts bind mount.
