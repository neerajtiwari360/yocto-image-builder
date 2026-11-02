# FaceGuard / KV260 architecture review and migration

Subsequent KV260-only cleanup archived the desktop/Python pipelines and their
preserved assets outside these repositories. The inspected layout and Python
test results below describe the pre-cleanup state. See
[cleanup and recovery](project-cleanup.md) for the current layout.

Review date: 2026-11-02. FaceGuard baseline: `517f64d3a4f1848960bf5cce62ec9d83b329e548`.
This review was written before implementation. It describes inspected files,
not assumed interfaces. Phase results are recorded separately below as work runs.

## Existing system and dependency map

Two repositories remain the ownership boundary. FaceGuard owns application and
model/evaluation source; yocto-image-builder owns Linux image integration and
platform configuration. No new repository is needed.

| Existing area | Source | Dependencies / outputs |
| --- | --- | --- |
| Python ML / evaluation | `FaceGuard/src/{edge,edge_quantization,yunet,inference,models}.py`, `tests/`, `webcam_demo/`, `pyqt_ui/` | NumPy, OpenCV, ONNX/ORT, PyTorch/DeepFace; CPU reference evaluation, quantization, saved NPZ tensors; not the deployed DPU runtime |
| ML asset lifecycle | `model/`, `dvc.yaml`, `dvc.lock`, `.dvc/`, `mlruns/`, `mlflow.db` | DVC weights and MLflow experiment history; preserve all unchanged |
| Python Docker | FaceGuard `Dockerfile`, `compose.yaml` | Python 3.12, CPU PyTorch, MLflow server and CLI runner; distinct from Yocto builder |
| Native orchestration | `kv260-yunet/runtime/src/app/{main,config}.c` | Camera/intent locks, preprocessing, VART, decoder, IPC; emits JSON detections |
| Preprocessing | `src/ml/preprocess/preprocess.c`, `include/yunet_preprocess.h` | Pure C + libm; NV12/BGR, BT.601/709, limited/full range, bilinear top-left letterbox and INT8 quantization |
| Postprocessing | `src/ml/postprocess/postprocess.c`, `include/yunet_postprocess.h` | Pure C + libm; 12 independently scaled heads, sigmoid confidence, deterministic sorting, NMS and original-pixel coordinates |
| DPU backend | `src/ml/inference/dpu_bridge.cpp`, `include/dpu_bridge.h` | C++17, VART/XIR; graph/runner/buffer ownership, one DPU subgraph, fixed INT8 NHWC, fingerprint/shape checks |
| Camera | `src/camera/{capture,camera_guard}.c` | Linux V4L2 MMAP, poll/ioctl, flock; borrowed frame valid until release; startup intent hands camera from viewer to ML |
| Mailbox | `src/ipc/preview.c`, `include/preview.h` | POSIX mmap/flock and lock-free atomics; triple buffer, bounded publisher, latest paired frame/detections; version 1 already checked |
| Renderer | `src/hdmi/preview_render.c`, `include/preview_render.h` | Pure drawing math but public input is currently IPC `preview_slot`; unnecessary IPC/atomic coupling |
| HDMI device adapter | `src/hdmi/hdmi.c` | libdrm/KMS, camera fallback, IPC, CPU3/nice10; independent executable without VART |
| Native build | `runtime/CMakeLists.txt`, `tools/{Build-Runtime.ps1,build-runtime.sh,yunet-standalone.bb}` | Existing module targets, four CTest tests, all/ML/HDMI standalone packages; compiler/sysroot from Yocto |
| Deployment | `tools/{Deploy-Serial.ps1,encode_serial.py}` | Component allowlists, SHA256, UART; refuses replacing an active selected component; preserve payload paths |
| Services | `runtime/scripts/{yunet-inference,yunet-hdmi}.service` | Camera initialization dependency, manual ML, auto preview; keep names, arguments and activation policy |
| Image integration | `tools/{sync_image.py,kv260-yunet.bb}` and builder `recipes-apps/yunet/` | Deterministic tar source snapshot, CMake cross-build, fixed model SHA; source archive currently lacks an explicit pinned provenance/checksum contract |
| OS / platform | builder `docker/`, `scripts/image.sh`, targets/layers/WKS | ARM64 compiler, kernel, SmartCam B3136 bitstream/xclbin, camera firmware, VART/XIR/XRT, boot partition UUID fix |

The original Vitis quantization/compiler workflow is documented in FaceGuard's
`kv260-yunet/README.md`; its conversion scripts/calibration assets are archived
in builder `artifacts/faceguard-code-only/kv260-yunet-before-code-only.zip`.
The active Python ONNX QDQ/ORT workflow is not equivalent to compiling an XModel
for the DPU. No replacement of final DPU execution is proposed.

## Proposed boundaries and public interfaces

Preserve existing paths and old entry points; expose reusable CMake static
libraries rather than move files for appearance alone. Public APIs are C11,
callable from C++ through `extern "C"`; Linux device adapters stay conditional.

| Component | Public interface / ownership | Allowed dependencies |
| --- | --- | --- |
| Types / contracts | `yunet_types.h`, new `yunet_version.h`; API major/minor/patch and fixed platform constants | stdint/stddef only |
| Preprocessing | Existing `yunet_preprocess`, `yunet_nv12_to_bgr`, `yunet_preprocess_nv12`; caller owns output, input is borrowed; 307200 output bytes | types + libm |
| Postprocessing | Existing `yunet_decode`; borrowed heads in cls/obj/bbox/kps order at strides 8/16/32, caller-owned bounded faces/count | types + libm |
| Overlay | New `yunet_overlay.h`: borrowed contiguous NV12/frame face view independent of mailbox; single/split render into caller-owned output | types + libm; no IPC, DRM, VART or Linux headers |
| Legacy rendering adapter | Existing `preview_render_*` signatures retained, translate slot to overlay view without copying pixels | IPC types + overlay |
| Camera | Existing opaque `camera`, `nv12_frame` and release semantics retained | Linux V4L2/POSIX only |
| KV260 inference | Existing opaque `dpu_context`, `dpu_open/input/output/run/close` retained | VART/XIR, B3136 fingerprint `0x101000016010406`; no CPU fallback |
| IPC | Existing preview API and version-1 layout retained; compile-time ABI size/offset guards and schema documentation | POSIX and atomics, types |
| Model tooling | New host-only manifest/release checker and recorded-tensor evaluator; optional XIR graph inspection without runner execution | Python stdlib for contract checks; optional XIR/Vitis for compiler-graph checks |

## Planned directory additions

```text
FaceGuard/
  .github/workflows/kv260-native.yml
  kv260-yunet/
    docs/{architecture.md,hardware-regression.md}
    runtime/include/{yunet_version.h,yunet_overlay.h}
    runtime/src/overlay/overlay.c
    runtime/tests/{test_overlay.c,test_contracts.c,test_regression.c}
    runtime/tests/fixtures/       # hashes, source provenance, fixed binary inputs/outputs
    tools/{check_contracts.py,evaluate_tensors.py,...}
yocto-image-builder/
  docs/faceguard-architecture-review.md
  scripts/verify-yunet-source.py
  .github/workflows/yunet-integration.yml
  yocto/.../yunet/files/{runtime.tar.gz,source-release.json}
```

## Compatibility risks identified before changes

1. Fused preprocessing depends on exact rounding, saturation, BGR ordering,
   top-left padding and per-head fix points. Freeze recorded-input golden bytes
   before extraction; synthetic parity alone is insufficient.
2. Overlay source consumes the large atomic IPC struct. Separate a borrowed view
   while leaving all pixel loops unchanged; retain compatibility wrappers.
3. The shared-memory format embeds native floats/atomics/padding. Version 1 is
   a same-ABI little-endian Linux contract, not a portable serialized format.
   Keep its bytes unchanged; incompatible changes require a version bump and
   coordinated ML/viewer replacement. Lock-free support must fail closed.
4. Current CMake unconditionally builds Linux camera/IPC even with VART off.
   Pure numerical libraries/tests must configure on laptops independently;
   process-sharing tests remain Linux-only. Avoid claiming Windows IPC support.
5. A generic CPU INT8 ONNX graph does not establish Vitis/XModel compatibility.
   Separate static contract validation, optional XIR graph inspection, numerical
   saved-tensor evaluation, and physical DPU execution in reports.
6. Existing model manifest omits explicit artifact/API/platform versions.
   Add metadata without changing model bytes or tensor order/scale assumptions.
7. Source sync copies a recipe template and archive; manual edits can diverge.
   Generate a checksummed release with source commit/dirty state and file hashes,
   make recipe verify it before configure, and verify template equality in CI.
   An uncommitted migration snapshot must not be described as a pinned clean commit.
8. Standalone component archive allowlists are intentional. Preserve them and
   avoid silently adding deployment files or changing service behavior.
9. No kernel/FPGA/device-tree/BSP change is justified by these module changes.
   Working deployed binaries stay untouched; board tests require explicit,
   evidence-backed execution rather than reusing historical results.
10. Available recorded images/tensors may not have complete provenance. Record
    what is captured, synthetic or generated; never label synthetic outputs as
    DPU recordings. Golden outputs frozen from baseline establish regression,
    not independent model accuracy.

## Incremental migration and tests

0. Inspect both trees and capture clean Git status, model hash and baseline host
   CTest results. Write this review before touching implementation.
1. Extract standalone preprocessing/postprocessing/overlay targets; retain old
   headers/wrappers/target behavior. Run existing tests plus independent overlay
   test and build pure targets without Linux/VART/DRM.
2. Add API/platform/model versions, preserve and guard IPC ABI; test rejects
   wrong hashes/versions/platform/head shape and inspect optional XIR metadata.
3. Freeze a recorded camera image and baseline preprocessed bytes, saved head
   tensors with explicit provenance, expected faces and overlay bytes. Add
   CMake numerical regressions and host saved-tensor evaluator. Run CTest and
   negative/tamper tests; do not auto-regenerate expected results during tests.
4. Pin the generated source release by SHA256 and per-file manifest; verify in
   Yocto before compiling. Test deterministic output, tamper rejection and
   recipe-template synchronization. Preserve model and all existing build scripts.
5. Add host/CI checks and a proposed board acceptance protocol covering camera,
   DPU, HDMI, handoff/restarts and systemd policy. Run available host checks;
   report ARM64/hardware checks separately as run or not run.

Existing DVC/MLflow/model assets and working deployment stay in place. No new
Git repositories, commits, flashing or live replacement are required by these
phases. Each phase result must distinguish actual execution from proposed tests.
