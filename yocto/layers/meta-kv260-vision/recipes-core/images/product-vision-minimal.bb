require recipes-core/images/core-image-minimal.bb
SUMMARY = "Headless KV260 J7 AP1302/AR1335 camera and Vitis AI runtime"
IMAGE_FEATURES:remove = "tools-sdk dev-pkgs package-management read-only-rootfs"
IMAGE_INSTALL:append = " board-projects kv260-smartcam-hardware ap1302-ar1335-firmware kv260-vision-runtime kv260-yunet vart xir media-ctl v4l-utils zocl"
do_image_wic[depends] += "kv260-boot-script:do_deploy virtual/kernel:do_deploy"
ROOTFS_POSTPROCESS_COMMAND += "verify_vision_rootfs; "
python verify_vision_rootfs() {
    import pathlib
    root = pathlib.Path(d.getVar('IMAGE_ROOTFS'))
    for item in ('lib/firmware/ap1302_ar1335_single_fw.bin', 'lib/firmware/kv260-smartcam.bit.bin', 'lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.dtbo', 'lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin', 'usr/bin/media-ctl', 'usr/bin/v4l2-ctl', 'usr/bin/kv260-camera-setup', 'usr/bin/kv260-infer', 'usr/libexec/kv260-vision/boot.sh', 'etc/vart.conf'):
        if not (root / item).is_file():
            bb.fatal('Missing vision runtime asset: ' + item)
    expected_firmware = '/lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin'
    for item in ('opt/yunet/bin/yunet-kv260', 'opt/yunet/run.sh', 'opt/yunet/config/yunet.conf', 'opt/yunet/model/yunet_smartcam.xmodel'):
        if not (root / item).is_file():
            bb.fatal('Missing native inference asset: ' + item)
    import hashlib
    if hashlib.sha256((root / 'opt/yunet/model/yunet_smartcam.xmodel').read_bytes()).hexdigest() != '39bb7312515e3fb350676681571152ed6c0a34afaba850a385d69ee01e3f2752':
        bb.fatal('YuNet model differs from the verified SmartCam model')
    if (root / 'etc/vart.conf').read_text().strip() != 'firmware: ' + expected_firmware:
        bb.fatal('VART must use the installed SmartCam xclbin')
    if d.getVar('YUNET_HDMI_IMAGE') == '1':
        for item in ('opt/yunet/bin/yunet-hdmi', 'usr/bin/systemctl',
                     'usr/lib/systemd/system/yunet-hdmi.service',
                     'usr/lib/systemd/system/kv260-vision.service',
                     'etc/default/yunet-hdmi'):
            if not (root / item).is_file():
                bb.fatal('Missing optional HDMI/systemd asset: ' + item)
        # Unit links have absolute targets inside the *target* rootfs. A glob
        # ending in a literal filename can follow the link on the build host
        # and omit it as dangling. Enumerate names and inspect lstat instead.
        def enabled_links(unit):
            system = root / 'etc/systemd/system'
            if not system.is_dir():
                return []
            found = []
            for wants in system.iterdir():
                if wants.name.endswith('.wants') and wants.is_dir():
                    link = wants / unit
                    if link.is_symlink():
                        found.append(link)
                    elif link.exists():
                        bb.fatal('Expected a systemd enablement symlink: ' + str(link))
            return found

        enabled = enabled_links('yunet-hdmi.service')
        if bool(enabled) != (d.getVar('YUNET_HDMI_AUTOSTART') == '1'):
            bb.fatal('HDMI preview boot policy differs from YUNET_HDMI_AUTOSTART')
        # Validate the link against the unit installed in the image, never the
        # host's /usr/lib/systemd directory. Also accept native relative links.
        import os
        import posixpath
        for link in enabled:
            target = os.readlink(link)
            if target.startswith('/'):
                relative = posixpath.normpath(target).lstrip('/')
            else:
                relative = posixpath.normpath(
                    link.parent.relative_to(root).as_posix() + '/' + target)
            if relative != 'usr/lib/systemd/system/yunet-hdmi.service':
                bb.fatal('HDMI enablement link has an unexpected target: ' + target)
            if not (root / relative).is_file():
                bb.fatal('HDMI enablement link target is missing from the image')
        if enabled_links('yunet-inference.service'):
            bb.fatal('ML inference must remain manually controlled')
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
