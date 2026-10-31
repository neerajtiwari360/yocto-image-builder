FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:kv260-vision = " file://vision.cfg"
do_configure:append:kv260-vision() {
    for setting in CONFIG_VIDEO_AP1302 CONFIG_VIDEO_XILINX CONFIG_VIDEO_XILINX_CSI2RXSS CONFIG_XILINX_FRMBUF CONFIG_I2C_XILINX CONFIG_I2C_MUX_PCA954x CONFIG_CMA CONFIG_DMA_CMA CONFIG_OF_CONFIGFS; do
        grep -qx "$setting=y" ${B}/.config || bbfatal "Required camera/DPU setting missing: $setting=y"
    done
}
