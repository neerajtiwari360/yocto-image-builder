# KV260-focused repository cleanup

On 2026-11-02 the user selected: **keep only KV260; archive desktop apps and
other pipelines**. Removed items are archived, not deleted permanently.

Archive: `D:\Github\kv260-project-archive-20261102`.
The archive contains `cleanup-plan.json`, `completed.json`, `inventory.json`
and `verification.json`, recording original paths, destinations and checks.

## Active repositories

`FaceGuard/kv260-yunet/` remains the application project: native C/C++ runtime,
compiled B3136 model, recorded numerical fixtures, host tensor evaluation and
compatibility tools, build/deployment scripts, services and documentation.
FaceGuard's `.git`, `.github`, `.venv` and editor configuration remain. The
existing virtual environment is retained because active helper scripts use it.
Root requirements now describe optional NumPy support for laptop NPZ evaluation.

`yocto-image-builder/` retains Docker configuration, image scripts, all required
Yocto layers/targets, source-release pins, flashable images, deployable packages,
model-conversion archives and board/migration validation evidence.

On 2026-11-03, the obsolete console target was removed and shared board metadata was renamed to kv260-base. Vision targets retain the required kernel, firmware, device trees and SD boot settings.

The user ran a full `kv260-vision-hdmi build` after this cleanup. All 4,450
tasks succeeded, with seven warnings, and SD image structural verification
passed. The generated release is `yocto-5.0.19-20261103T153821443693252Z`.
Hardware boot of that release remains unverified.
Old exported layer snapshots were removed locally; retained image binaries and
their original checksum entries were preserved. Each affected export includes
a `SOURCE-SNAPSHOT-REMOVED.txt` note, and its checksum list covers the retained
original files. Generated artifacts are excluded from Git.

## Archived content

- FaceGuard's PyQt/webcam apps and other Python pipelines, their tests/scripts,
  old Docker setup and documentation.
- Their models, datasets, DVC metadata/cache, MLflow experiments/database and
  reports, preserved in the archive under their original relative paths.
- Python package-download cache and generated serial-transfer spool.
- Builder's retired sensor experiments, obsolete patch-generation/debugging
  helpers, superseded build logs and one-time migration editing scripts.
- Backups of FaceGuard's original README, requirements and editor settings.

No active KV260 model, source, fixture, service or deployment package is removed.
Archived MLflow records may contain absolute artifact paths; restore the original
layout before reopening an old experiment or rerunning the legacy DVC pipeline.
No new Git repository is created. Existing Git history remains in each checkout.

## Verification and recovery

Same-volume moves retain file contents and identities. Inventoried file
identities, sizes and timestamps are checked before and after archival; copied
configuration backups are checked by SHA256. One access-restricted UV cache
subdirectory is opaque: its directory identity is preserved by moving its parent
intact, without changing permissions or inspecting its contents.

The current native/model/source-release/fixture checks must pass after cleanup.
The 76 Python tests in the migration results belong to the now-archived legacy
pipeline; those earlier results are historical and not evidence of a post-cleanup
run from the active tree. Physical board regression remains unexecuted.

To recover a moved item, consult `cleanup-plan.json` and move its destination
back to its original source path, only if that path is absent. Do not overwrite
new active files. Original README/requirements/editor settings were copied as
backups; restoring those requires deliberately replacing the new configurations.
No Git changes are committed automatically by this cleanup.

## Completed checks

- 81 archive/backup entries verified: 40,960 inventoried files totaling
  2,603,251,336 bytes, plus the opaque cache subtree preserved intact.
- Active native CMake/CTest suite: 8/8 passed after cleanup.
- Model/platform contract tests: 4/4 passed; frozen fixture hashes passed.
- Builder source-integration tests: 2/2 passed; deterministic source-release
  test passed, and maintained source still matches the pinned archive.
- Existing Python environment and NumPy import successfully. The active model,
  core inference/capture/IPC code and systemd service files remain unchanged.
- No board files, Docker workspace volume or flashable image were modified.

The one-time cleanup orchestration scripts are also archived, with their own
SHA256 move record in `cleanup-script-moves.json`.

## Image-export cleanup

Eight obsolete complete releases (2,090,065,138 bytes) were subsequently moved
to `D:\Github\kv260-project-archive-20261102\image-exports`, including three old
minimal-base releases, four headless vision releases and the pre-boot-fix HDMI
release. Each bundle retains its image, compressed WIC, checksums, manifests
and build configuration together. Source/model ZIP backups were retained.

The only active exported SD image is:

```text
artifacts/scarthgap-kv260/kv260-vision-hdmi/yocto-5.0.19-20261102T132521922766719Z/kv260-vision-hdmi.img
```

Its exported WKS includes the boot UUID fix. All 57 release checksums passed
before and after archival. All eight moved release inventories matched their
original file identities, sizes and timestamps. The image archive's
`cleanup-plan.json`, `completed.json` and `verification.json` record recovery
paths. Only empty old export directories were deleted; target configuration
and shared BSP components remain in the source tree.
