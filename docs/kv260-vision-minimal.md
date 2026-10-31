# KV260 minimal native camera/DPU image

This headless Scarthgap target uses the existing QSPI firmware and the official
SmartCam camera + DPU B3136 design (fingerprint 0x101000016010406).
Use the separately compiled yunet_smartcam.xmodel; the generic B4096 model is incompatible.
The earlier image booted on a KV260 revB on 2026-10-31. After moving the
AR1335 module from J8 to J7 and setting AP1302 to bus code `0x2100`, hardware
capture passed for three frames and then 90 frames at 1280x720 NV12, reporting
30 fps. Sensor chip-ID register `0x3000` returned `0x0153`. This measures capture,
not neural-network inference. `xrt-smi program` also loaded the installed
SmartCam xclbin successfully; its dynamic-region report exposed
`DPUCZDX8G:DPUCZDX8G_1` at `0xa0010000` and the preprocessing CU at `0xa0020000`,
both idle. The regenerated image still needs a fresh boot test after flashing;
DPU model execution remains unverified.

Connect the AR1335 IAS module to **J7**, with board power disconnected while
moving it. J8 is the direct sensor interface and is not routed through the
SmartCam AP1302 pipeline. The AP1302 is on the carrier board, so its presence
and an `ar1335 0` media entity do not prove that a sensor is connected to J7.
An AP1302 status log with sensor I2C NACKs, `WARN_SIPM_0_RTY` and zero frame
counters requires checking the connector before changing the sensor model.

The image includes the AP1302/AR1335 ISP firmware, camera kernel support,
SmartCam bitstream/device-tree overlay/xclbin, ZOCL/XRT, native XIR/VART,
media-ctl, v4l2-ctl, and shell initialization. The J7 camera is configured for
1280x720 NV12 and three frames are captured during startup.

SmartCam's fixed CSI format is YUV420, vendor bus code `0x2100`
(`VYYUYY8_1X24`), on AP1302 source pad 2 and CSI pads 0/1. The setup script
uses numeric V4L2 subdevice ioctls because upstream media-ctl does not name
this vendor code, and verifies the negotiated formats. UYVY/YUV422 does not
match this bitstream. A kernel patch reports the correct one memory plane for
contiguous NV12. BusyBox timeout bounds the startup capture test to 20 seconds.
`/run/kv260-camera.conf` is created only after the requested capture succeeds.

VART reads `/etc/vart.conf`, which must point to
`/lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin`. The generic
`/run/media/mmcblk0p1/dpu.xclbin` default does not apply to this image.
Image generation checks this path and the presence of the timeout command.

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
For a manual repeat of camera initialization and capture:

```sh
kv260-camera-setup --width 1280 --height 720 --smoke-frames 3
cat /run/kv260-camera.conf
cat /etc/vart.conf
cat /sys/class/fpga_manager/fpga0/state
```

To verify XRT registration separately, while inference is stopped:

```sh
xrt-smi program -d 0 -u /lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin --batch
xrt-smi examine -d 0 -r dynamic-regions --batch
```

The unfiltered `xbutil examine` host summary has an XRT 2.18 reporting error
(`host.os.cores`) on this minimal OS. The explicit device/dynamic-region report
works and avoids that unrelated host-summary failure.

Passing camera capture and FPGA `operating` status does not verify DPU inference;
run the matching native YuNet application to establish that separately.
Set AUTORUN=yes in /etc/default/kv260-vision after deploying the native package
to launch it at boot. AUTORUN defaults to no. Detections are written to stdout;
manage log capture/rotation externally when enabling continuous operation.

Build exports are under artifacts/scarthgap-kv260/kv260-vision-minimal/.
The detached wrapper logs to artifacts/kv260-vision-build.log and records its
exit status in artifacts/kv260-vision-build.exit. Image generation alone does
not establish camera operation or a guaranteed real-time frame rate.
