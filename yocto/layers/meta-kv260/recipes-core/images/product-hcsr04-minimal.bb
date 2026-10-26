require recipes-core/images/core-image-minimal.bb
SUMMARY = "Offline KV260 UART console image"
# Keep the historical recipe/target names so existing build commands still work.
# Compile applications on the PC; no compiler or package manager on the board.
IMAGE_FEATURES:remove = "tools-sdk dev-pkgs package-management read-only-rootfs"
IMAGE_INSTALL:append = " board-projects"
# Boot assets are built explicitly; the card reuses the SOM's QSPI boot firmware.
do_image_wic[depends] += "kv260-boot-script:do_deploy virtual/kernel:do_deploy"

ROOTFS_POSTPROCESS_COMMAND += "verify_offline_rootfs; "
python verify_offline_rootfs() {
    import pathlib
    root = pathlib.Path(d.getVar('IMAGE_ROOTFS'))
    interfaces = root / 'etc/network/interfaces'
    if not interfaces.is_file():
        bb.fatal('Offline image requires the loopback-only interfaces file')
    active = [line.strip() for line in interfaces.read_text().splitlines()
              if line.strip() and not line.lstrip().startswith('#')]
    if active != ['auto lo', 'iface lo inet loopback']:
        bb.fatal('Unexpected network configuration in offline KV260 image')
    for directory in ('usr/bin', 'usr/sbin', 'bin', 'sbin'):
        for name in ('opkg', 'apt', 'apt-get', 'dnf', 'rpm', 'gcc', 'g++', 'make'):
            if (root / directory / name).exists():
                bb.fatal('Offline image unexpectedly contains ' + directory + '/' + name)
    bb.note('Verified offline rootfs: loopback-only networking, no package manager or compiler')
}
