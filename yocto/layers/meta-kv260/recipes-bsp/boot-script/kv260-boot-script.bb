SUMMARY = "KV260 SD boot script for an existing QSPI U-Boot"
LICENSE = "CLOSED"
SRC_URI = "file://boot.cmd"
S = "${WORKDIR}"
DEPENDS = "u-boot-tools-native"
inherit deploy
do_compile() {
    mkimage -A arm64 -O linux -T script -C none -n 'KV260 HC-SR04 SD boot' -d ${WORKDIR}/boot.cmd ${B}/kv260-boot.scr
}
do_deploy() {
    install -Dm0644 ${B}/kv260-boot.scr ${DEPLOYDIR}/kv260-boot.scr
}
addtask deploy after do_compile before do_build
