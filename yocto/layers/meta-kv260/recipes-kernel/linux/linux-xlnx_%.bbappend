FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:kv260-hcsr04 = " file://hcsr04.cfg"

do_configure:append:kv260-hcsr04() {
    for setting in CONFIG_GPIO_CDEV CONFIG_GPIO_CDEV_V1 CONFIG_GPIO_ZYNQ CONFIG_OF_CONFIGFS CONFIG_FPGA_MGR_ZYNQMP_FPGA CONFIG_OF_FPGA_REGION CONFIG_EXT4_FS CONFIG_MMC_SDHCI_OF_ARASAN; do
        grep -qx "$setting=y" ${B}/.config || bbfatal "Required HC-SR04/SD boot kernel setting missing: $setting=y"
    done
}
