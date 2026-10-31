SUMMARY = "Official KV260 SmartCam combined J7 camera and B3136 DPU design"
LICENSE = "Xilinx-Binary & GPL-2.0-only"
NO_GENERIC_LICENSE[Xilinx-Binary] = "LICENSE-BINARIES"
LIC_FILES_CHKSUM = "file://LICENSE-BINARIES;md5=fa9b03ada9ffccf51dd60899bf28c702 file://LICENSE-GPLv2;md5=9afdcd1be3f71bd3791fa5961075d776"
SRC_URI = "git://github.com/Xilinx/kria-apps-firmware.git;protocol=https;nobranch=1"
SRCREV = "c111436a82d60b13f4092768d213e7a09c6b0972"
S = "${WORKDIR}/git"
DEPENDS = "dtc-native bootgen-native"
do_compile[depends] += "virtual/kernel:do_deploy"
do_configure[noexec] = "1"
do_compile() {
    cd ${S}/boards/kv260/smartcam
    dtc -@ -I dts -O dtb -o ${B}/kv260-smartcam.dtbo kv260-smartcam.dtsi
    for revision in A B; do
        fdtoverlay -i ${DEPLOY_DIR_IMAGE}/zynqmp-smk-k26-revA-sck-kv-g-rev$revision.dtb -o ${B}/merged-rev$revision.dtb ${B}/kv260-smartcam.dtbo
    done
    printf 'all:\n{\n [destination_device=pl] %s\n}\n' "${S}/boards/kv260/smartcam/kv260-smartcam.bit" > ${B}/smartcam.bif
    bootgen -image ${B}/smartcam.bif -arch zynqmp -o ${B}/kv260-smartcam.bit.bin -w
}
do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/xilinx/kv260-smartcam
    install -m0644 ${B}/kv260-smartcam.bit.bin ${D}${nonarch_base_libdir}/firmware/
    install -m0644 ${B}/kv260-smartcam.dtbo ${S}/boards/kv260/smartcam/kv260-smartcam.xclbin ${S}/boards/kv260/smartcam/shell.json ${D}${nonarch_base_libdir}/firmware/xilinx/kv260-smartcam/
}
FILES:${PN} = "${nonarch_base_libdir}/firmware"
COMPATIBLE_MACHINE = "kv260-vision"
PACKAGE_ARCH = "${MACHINE_ARCH}"
