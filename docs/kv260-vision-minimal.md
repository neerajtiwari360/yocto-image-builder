# KV260 minimal native camera/DPU image

This headless Scarthgap target uses the existing QSPI firmware and the official
SmartCam camera + DPU B3136 design (fingerprint 0x101000016010406).
Use the separately compiled yunet_smartcam.xmodel; the generic B4096 model is incompatible.
Physical boot, camera capture and DPU execution remain to be verified on the board.

The image includes the AP1302/AR1335 ISP firmware, camera kernel support,
SmartCam bitstream/device-tree overlay/xclbin, ZOCL/XRT, native XIR/VART,
media-ctl, v4l2-ctl, and shell initialization. The J7 camera is configured for
1280x720 NV12 and three frames are captured during startup.

Python bindings in XIR/VART are disabled. Python, NumPy, OpenCV and GStreamer
are not requested by the image. A rootfs check rejects Python/OpenCV runtime
artifacts. Python inside the Yocto/Docker build environment remains necessary
for BitBake and is not the board inference implementation.

Build on the laptop:

```powershell
docker compose run --rm builder bash /project/scripts/image.sh kv260-vision-minimal build
```

The SDK and native application build scripts are in
D:/Github/FaceGuard/yunet-kv260-native/yocto. Build the SDK from the same image
metadata and use that SDK/sysroot for the ARM64 C/C++ application.
See the native application's README for cross-build and packaging commands.

Extract the native deployment package under /opt/yunet on the board, then run:

```sh
kv260-infer --frames 300
```

The package contains bin/yunet-kv260, run.sh, config/yunet.conf, the matching
model, and required runtime libraries. The C code converts NV12 to BGR,
letterboxes and quantizes the input, then decodes detections and runs NMS.
A minimal C++ wrapper invokes the DPU through VART. No Python inference is used.

Inspect /var/log/kv260-camera.log and /run/kv260-camera.conf for camera startup.
Set AUTORUN=yes in /etc/default/kv260-vision after deploying the native package
to launch it at boot. AUTORUN defaults to no. Detections are written to stdout;
manage log capture/rotation externally when enabling continuous operation.

Build exports are under artifacts/scarthgap-kv260/kv260-vision-minimal/.
The detached wrapper logs to artifacts/kv260-vision-build.log and records its
exit status in artifacts/kv260-vision-build.exit. Image generation alone does
not establish camera operation or a guaranteed real-time frame rate.
