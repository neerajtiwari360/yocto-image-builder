FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:kv260-vision = " file://vision-timeout.cfg"

do_configure:append:kv260-vision() {
    grep -qx 'CONFIG_TIMEOUT=y' ${S}/.config || bbfatal "Camera smoke test requires BusyBox timeout"
}
