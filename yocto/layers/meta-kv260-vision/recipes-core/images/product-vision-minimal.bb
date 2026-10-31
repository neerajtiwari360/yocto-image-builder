require recipes-core/images/core-image-minimal.bb
SUMMARY = "Headless KV260 J7 AP1302/AR1335 camera and Vitis AI runtime"
IMAGE_FEATURES:remove = "tools-sdk dev-pkgs package-management read-only-rootfs"
IMAGE_INSTALL:append = " board-projects kv260-smartcam-hardware ap1302-ar1335-firmware kv260-vision-runtime vart xir media-ctl v4l-utils zocl"
do_image_wic[depends] += "kv260-boot-script:do_deploy virtual/kernel:do_deploy"
ROOTFS_POSTPROCESS_COMMAND += "verify_vision_rootfs; "
python verify_vision_rootfs() {
    import pathlib
    root = pathlib.Path(d.getVar('IMAGE_ROOTFS'))
    for item in ('lib/firmware/ap1302_ar1335_single_fw.bin', 'lib/firmware/kv260-smartcam.bit.bin', 'lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.dtbo', 'lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin', 'usr/bin/media-ctl', 'usr/bin/v4l2-ctl', 'usr/bin/kv260-camera-setup', 'usr/bin/kv260-infer', 'etc/init.d/kv260-vision', 'etc/vart.conf'):
        if not (root / item).is_file():
            bb.fatal('Missing vision runtime asset: ' + item)
    expected_firmware = '/lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin'
    if (root / 'etc/vart.conf').read_text().strip() != 'firmware: ' + expected_firmware:
        bb.fatal('VART must use the installed SmartCam xclbin')
    # Installed alternatives may be absolute symlinks, which cannot be followed
    # with Path.is_file() from the build host. Check the link itself as well.
    if not any((root / directory / 'timeout').exists() or (root / directory / 'timeout').is_symlink()
               for directory in ('usr/bin', 'bin')):
        bb.fatal('Missing timeout command required by camera smoke test')
    for directory in ('usr/bin', 'usr/sbin', 'bin', 'sbin'):
        for name in ('opkg', 'apt', 'apt-get', 'dnf', 'rpm', 'gcc', 'g++', 'make'):
            if (root / directory / name).exists():
                bb.fatal('Unexpected development/package tool: ' + name)
    for pattern in ('usr/bin/python*', 'usr/lib/python*', 'usr/lib/libpython*', 'usr/lib/libopencv*'):
        if list(root.glob(pattern)):
            bb.fatal('Unexpected Python/OpenCV runtime asset: ' + pattern)
    bb.note('Vision assets present; hardware boot/camera/DPU tests still required')
}
