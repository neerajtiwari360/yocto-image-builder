# Optional KV260 offline HDMI preview image

`kv260-vision-hdmi` uses the same source locks, machine, kernel, camera, B3136 DPU
and model as `kv260-vision-minimal`. It adds systemd and the optional `kv260-yunet-hdmi`
package. The original headless target retains SysV init. No FPGA or device-tree
change is needed for the inspected board: its PS display controller already
exposes a DRM DP connector feeding the carrier's HDMI J5 splitter.

The maintained source, ownership protocol, deployment instructions and measured
results are in the [YuNet HDMI guide](../../FaceGuard/kv260-yunet/HDMI.md).
The [module and component-update guide](../../FaceGuard/kv260-yunet/MODULES.md)
maps the separate HDMI, preprocessing, DPU inference and postprocessing source
folders and their independent HDMI-only / ML-only build and deployment commands.
Image recipes consume a generated source snapshot; application code is maintained
in FaceGuard rather than edited inside the image archive or Docker workspace.
`yunet-hdmi` is a separate process pinned to CPU3 with nice 10. It captures
camera-only video while inference is off and yields the camera at ML startup.
During inference it reads paired frames/detections from a bounded nonblocking
shared-memory mailbox; preview never holds inference's DMA camera buffers.

## Build and export the image

To rebuild with the current checked-in runtime snapshot (including the boot
mount fix), run this in laptop PowerShell:

```powershell
cd D:\Github\yocto-image-builder
docker compose run --rm builder bash /project/scripts/image.sh kv260-vision-hdmi build
```

This builds and exports the image to the timestamped artifacts directory below.
If the maintained FaceGuard application source has changed, synchronize it first
and optionally use the detached build workflow:

```powershell
cd D:\Github\FaceGuard\kv260-yunet
..\.venv\Scripts\python.exe .\tools\sync_image.py
cd D:\Github\yocto-image-builder
docker compose build
docker compose run -d --name yocto-vision-hdmi builder bash /project/scripts/build-vision-hdmi.sh
Get-Content .\artifacts\kv260-vision-hdmi-build.log -Tail 30 -Wait
```

Use a new container name if that name already exists. Ctrl+C stops following the
log, leaving the build running. Exit status is written to
`artifacts/kv260-vision-hdmi-build.exit`; 0 is success. Completed `.img` files and
checksums are exported under `artifacts/scarthgap-kv260/kv260-vision-hdmi/` in
timestamped directories. Flashing replaces the SD contents; this target uses
the board's existing compatible QSPI firmware.

The optional image starts **camera-only HDMI video at boot**, without logging in
on HDMI or UART. ML remains off until explicitly started.

## Turn AI on and off through PuTTY

Open the board's serial console in PuTTY (COM7 on the validated laptop,
115200 baud, 8 data bits, no parity, 1 stop bit, no flow control). Log in as
`root`. Type these commands at the board shell, not in laptop PowerShell:

```sh
systemctl start yunet-inference   # AI ON: face boxes and five landmarks
systemctl stop yunet-inference    # AI OFF: camera-only preview resumes
systemctl is-active yunet-inference
```

Run the start or stop command as needed. The status command prints `active`
when AI is on, `inactive` when it is off, or `failed` if the service failed.
Starting AI this way applies to the current boot; after reboot, camera-only
preview starts and AI remains off until started again.

Other board diagnostics and preview controls:

```sh
systemctl status kv260-vision
systemctl stop yunet-hdmi
systemctl start yunet-hdmi
systemctl start yunet-inference   # add bounding boxes and five landmarks
systemctl stop yunet-inference    # camera-only video resumes
journalctl -u yunet-hdmi --no-pager
```

The default output is 640x480/60 Hz with two equal columns: CAMERA on the left,
and YUNET with boxes/five landmarks on the right. Each column contains the same
320x180 letterboxed picture, updated at up to 15 preview fps. When ML is off the
right column is labelled ML OFF. `--layout single` restores one annotated view.
`/etc/default/yunet-hdmi` controls the layout, mode and preview cap.
The viewer's `--probe` lists the connected sink's modes. The Xilinx driver needs
graphics global alpha 0 to reveal its NV12 video plane; this is handled and
restored by the viewer, along with tty1 text/graphics mode.

Hardware validation on the existing SysV board confirmed Windows Camera live
video, boxes/landmarks, camera-only/ML handoff and preview crash/restart isolation.
The user also confirmed automatic live video after reboot. A 600-frame OFF/ON/OFF
comparison measured approximately 30.071/30.058/30.066 steady inference fps at the
15 fps preview cap. These performance measurements used the deployed native
package on that SysV board, rather than the newly flashed systemd image.

On 2026-11-02, the flashed systemd image entered emergency mode because WIC
generated `/dev/mmcblkp1` for the `/boot` fstab entry, while Linux exposed the SD
as `/dev/mmcblk1`. The shared WKS now requests `--use-uuid` for the boot
partition, as it already does for root. Images exported before this fix retain
the defective fstab; rebuild to include the correction.

The installed SD was repaired in place using its FAT filesystem UUID in fstab
(with the original saved as `/etc/fstab.before-boot-fix`). After a reboot,
systemd reported `running`, no failed units, a mounted `/boot`, successful
three-frame camera startup and active split HDMI preview. A bounded 60-frame
native inference run completed and preview returned to camera-only mode.
That SD does not need reflashing for this fix. Kernel stream-transition and
older-QSPI pinctrl warnings remain; this is not a warning-free boot.

The user subsequently rebuilt, flashed and booted a new image and confirmed
the two-panel HDMI preview appeared automatically. A UART check reported
systemd `running`, with `kv260-vision` and `yunet-hdmi` active. Starting
`yunet-inference` succeeded: all three services were active, the runtime logged
1280x720 NV12 camera initialization, and the HDMI journal confirmed camera
handoff to inference. This verifies startup and service handoff on the new
image; no new sustained performance or positive face-detection accuracy test
was recorded for that flash.

The rootfs check validates HDMI enablement links without following their absolute
Linux paths on the build host. It also checks that their unit targets exist
inside the image and that ML inference remains manually controlled. Regression
tests for this policy can run in the Linux builder:

```powershell
docker compose run --rm -v D:/Github/FaceGuard/kv260-yunet:/yunet:ro builder python3 /project/scripts/test-vision-boot-policy.py --model /yunet/runtime/model/yunet_smartcam.xmodel
```
