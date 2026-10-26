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

The KV260 target uses the meta-kv260 layer for its hardware configuration,
minimal console image, package management and optional project workspace.
The historical `hcsr04` target/machine/recipe names are retained for compatibility;
they do not mean the image still contains sensor software.

## Adding another board

Create `yocto/targets/<new-target>/` with:

- `sources.conf`: exact Poky and BSP repository revisions for a compatible release.
- `target.conf`: release namespace, image recipe, machine, external/local layers,
  export filenames and an optional board-specific structural verifier.
- `local.conf`: the board's `MACHINE`, shared configuration include, package format,
  image formats and any target settings.

Use the board vendor's compatible BSP layer. Add custom board metadata under a
separate local layer such as `yocto/layers/meta-<board>/` when needed. Select only
the layers required by that target; the KV260 boot script, device trees and kernel
fragment are hardware-specific and must not be reused for unrelated boards.
Keep machine-independent application recipes in a shared layer if multiple boards
need them. The runner can already select different local layers per target.

Build with `bash /project/scripts/image.sh <new-target> build` in the same Docker
builder. Outputs go to `artifacts/<release>/<new-target>/<version>/`. Each board
requires its own boot and hardware acceptance tests. Only KV260 is configured now;
adding a target is necessary before other boards can be built.

Targets sharing a `RELEASE` also share upstream checkouts. If they need different
source revisions, use distinct release namespaces; the runner deliberately refuses
to silently replace a locked checkout. A different Yocto release may also need an
updated host container. The optional `c-packages` workflow currently assumes IPK
packaging and glibc; adapt it before using a different package format or C library.

Do not run manual BitBake commands against a target while the runner is building it.
The runner locks each target and serializes shared source preparation. Source revisions
are immutable during a build; a changed lock fails rather than silently updating a checkout.

Exports contain selected deploy files, target settings, actual generated configuration,
local layer snapshots and SHA256SUMS. The version comes from the pinned Poky tag.
Physical boot and device-specific acceptance testing remain separate requirements.
Build and export automatically copy verified releases to artifacts/<release>/<target>/<version>/ on Windows through the /artifacts bind mount.
