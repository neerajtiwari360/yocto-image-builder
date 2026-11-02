# FaceGuard modular migration results

Subsequent KV260-only cleanup archived the desktop/Python pipelines and their
preserved assets outside these repositories. The inspected layout and Python
test results below describe the pre-cleanup state. See
[cleanup and recovery](project-cleanup.md) for the current layout.

Executed 2026-11-02. Baseline FaceGuard commit:
`517f64d3a4f1848960bf5cce62ec9d83b329e548`.

Read the [pre-change architecture review](faceguard-architecture-review.md) for
the dependency map, module interfaces, directory plan and compatibility risks.
Implementation remains in the two existing repositories. Changes are uncommitted.

## Phases completed

| Phase | Change | Executed validation |
| --- | --- | --- |
| 0: baseline | Inspected C/C++, Python, Docker, CMake, Yocto, deployment and services before editing | Existing direct native tests and baseline CTest: 4/4 passed |
| 1: extraction | Standalone static preprocessing/postprocessing/overlay libraries; borrowed overlay frame API independent of IPC; old renderer signatures retained as adapters; optional Linux I/O | Existing tests plus independent overlay: 5/5 passed. An initial new test sampled a title glyph rather than a box; corrected the test coordinate, with no drawing behavior change |
| 2: contracts | Explicit API/platform/model versions and compiled head shapes/scales; fixed model bytes; compile-time guards for unchanged IPC v1 layout | Four Python contract tests including bad version/platform/hash/head and corrupted model; saved XIR compiler-inspection metadata matches. Contract checks also pass in final CTest |
| 3: numerical fixtures | Recorded camera NV12, frozen preprocessing bytes, saved Vitis quantized CPU heads, expected detections and baseline split-overlay bytes; SHA256 and provenance | Expanded Linux CTest 8/8 passed; Linux-I/O-disabled suite 6/6 passed; raw INT8 and NPZ saved-tensor evaluators match the frozen face result |
| 4: source integration | Deterministic source release with archive/file hashes and embedded provenance; generated recipe SHA256 pin; verification before unpack/configure | Repeated release generation byte-identical; archive/recipe tampering rejected; maintained source and template match generated release; real BitBake fetch/unpack/configure/compile/install/package/QA passed |
| 5: delivery gates | CI in both repositories; proposed board hardware acceptance protocol | Existing FaceGuard Python suite: 76/76 passed; ASan/UBSan CTest: 8/8 passed; six image boot-policy cases passed on Linux; standalone HDMI-only, ML-only and combined ARM64 builds passed |

The first container test layout mounted runtime/tools as separate roots, causing
Python fixture paths to fail. Mounting the complete project at its normal layout
resolved those failures; final suites above passed. The Windows boot-policy
symlink test could not create symlinks without privilege; the actual test was
run successfully in Linux. Native Windows C compilation was not tested.

## Reproducible integration

The selected method is a **checksummed source release**, with Git commit and
dirty state recorded. No repository URL or new Git repository was invented.

- Archive SHA256:
  `8155a1814884e025afc936c3b8b6aa2c2e24dff9c84bb8b372257ed5272c502a`.
- `source_dirty` is `true`: the recorded baseline Git commit is provenance,
  not a claim that the migration is already committed there.
- `runtime.tar.gz` includes an embedded source-file manifest;
  `files/source-release.json` records the archive and generated recipe hashes.
- Yocto installed model metadata, compatibility.json and SOURCE_RELEASE.json
  alongside the application. Review/commit FaceGuard changes, then use
  `tools/sync_image.py --require-clean` for a clean Git-backed release and
  review/commit the generated builder files together.
- Host source verification does not require downloading or cloning FaceGuard.
  With both checkouts present, `scripts/verify-yunet-source.py --faceguard
  D:/Github/FaceGuard` also detects source/template drift.

## Preservation evidence

Git comparison confirmed no changes to the Python application/ML source, DVC
definitions, FaceGuard Docker configuration, native preprocessing/postprocessing
function implementations, VART backend, camera/IPC implementations, native main
loop, DRM device adapter, model binary or systemd service files.

The model SHA256 remains
`39bb7312515e3fb350676681571152ed6c0a34afaba850a385d69ee01e3f2752`.
Model metadata was extended; model bytes were not changed. No model/DVC data,
MLflow history, archived conversion workflows or existing build/deployment
scripts were removed. Kernel, FPGA firmware, device trees and BSP configuration
were not changed in this migration. The active board was not modified.

Actual generated IPK inspection confirmed AArch64 executables: ML links VART/XIR
without libdrm; HDMI links libdrm without VART/XIR. Package QA passed. The final
inference backend remains the existing B3136 VART implementation; CPU tensor
replay is a separate evaluation tool.

All three standalone deployment archives passed the existing encoder allowlists;
wrong-component and path-traversal test archives were rejected. A C++17 caller
successfully compiled, linked and called the standalone preprocessing,
postprocessing and overlay C APIs. These were host checks, with no deployment.

## Limits and remaining acceptance

No candidate binaries were deployed, no SD was flashed and no new bootable image
was generated. No camera/DPU/HDMI/systemd hardware test of this migration was
executed. The board protocol in FaceGuard
`kv260-yunet/docs/hardware-regression.md` is **proposed / NOT RUN**.

Fresh XIR graph deserialization in a Vitis Python environment and fresh model
quantization/compiler execution were not run. The checker supports optional
actual-model inspection with `--xmodel`; this session checked preserved compiler
inspection metadata, exact model bytes and real ARM64/VART link compatibility.
Saved head fixtures are quantized CPU simulation, not real DPU dumps or a labelled
accuracy dataset. Golden values were frozen from baseline behavior, not generated
during tests. Historical board measurements are not new performance guarantees.

CI workflows were added and their underlying local commands exercised; hosted
GitHub Actions runs were not triggered. ARM64 builds emitted existing distro/QEMU
configuration warnings, but completed successfully.

Local evidence is under ignored `artifacts/architecture-migration/`, including
CTest logs in the baseline, phase3-verified, pure and sanitizers build directories,
frozen source inputs and `arm64-package-inspection.json`. Standalone archives are
under `artifacts/inference/kv260-yunet/`. Full Yocto task logs remain in the
persistent workspace volume. These files are evidence, not replacements for
the maintained FaceGuard source.
