FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-edge-guard-aie-context.patch"

SRC_URI += "file://0002-export-legacy-cu-index.patch"

SRC_URI += "file://0003-vart-legacy-api-exports.patch"

SRC_URI += "file://0004-edge-explicit-legacy-exports.patch"

do_compile:append() {
    ${NM} -D --defined-only ${B}/runtime_src/core/edge/user/libxrt_core.so > ${T}/vart-legacy-exports.txt
    for api in xclOpen xclClose xclProbe xclGetDeviceInfo2 xclOpenContext xclCloseContext xclIPName2Index xclIPSetReadRange xclAllocBO xclFreeBO xclMapBO xclUnmapBO xclSyncBO xclExecBuf xclExecWait; do
        awk '{print $3}' ${T}/vart-legacy-exports.txt | grep -Fx "$api" >/dev/null || bbfatal "Missing VART legacy XRT export: $api"
    done
}
