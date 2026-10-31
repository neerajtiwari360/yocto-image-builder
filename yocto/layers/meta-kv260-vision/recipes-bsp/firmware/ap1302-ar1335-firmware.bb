SUMMARY = "AP1302 firmware for the single AR1335 IAS camera"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=9c13aad1aab42f76326f1beceafc40c4"
SRC_URI = "git://github.com/Xilinx/ap1302-firmware.git;protocol=https;nobranch=1"
SRCREV = "63e20752dc8b1e91fc6d6d518ebeb76f65e9f738"
S = "${WORKDIR}/git"
do_configure[noexec] = "1"
do_compile[noexec] = "1"
do_install() {
    install -Dm0644 ${S}/ap1302_ar1335_single_fw.bin ${D}${nonarch_base_libdir}/firmware/ap1302_ar1335_single_fw.bin
}
FILES:${PN} = "${nonarch_base_libdir}/firmware/ap1302_ar1335_single_fw.bin"
