FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-util-4bit-include-cstdint.patch"

SRC_URI += "file://0002-headers-include-cstdint.patch"

SRC_URI += "file://0003-batch-index-copy.patch"

# The generic VART default points at an SD boot partition used by other BSPs.
# This image installs its matching SmartCam xclbin in the root filesystem.
do_install:append:kv260-vision() {
    install -d ${D}${sysconfdir}
    printf 'firmware: /lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin\n' > ${D}${sysconfdir}/vart.conf
}
FILES:${PN}:append:kv260-vision = " ${sysconfdir}/vart.conf"
CONFFILES:${PN}:append:kv260-vision = " ${sysconfdir}/vart.conf"
