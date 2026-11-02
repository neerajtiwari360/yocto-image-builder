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

From laptop PowerShell, synchronize the maintained runtime and build:

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
on HDMI or UART. ML remains off until explicitly started. Board commands:

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
15 fps preview cap. These tests used the deployed native package on that board;
a newly generated systemd image still requires its own physical boot test.
