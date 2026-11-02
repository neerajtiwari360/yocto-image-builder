SUMMARY = "Optimized native YuNet camera inference for KV260 SmartCam"
LICENSE = "CLOSED"
SRC_URI = "file://runtime.tar.gz"
S = "${WORKDIR}/runtime"
DEPENDS = "vart xir"
RDEPENDS:${PN} = "kv260-vision-runtime"
inherit cmake pkgconfig systemd
PACKAGECONFIG ??= ""
PACKAGECONFIG[hdmi] = "-DENABLE_HDMI=ON,-DENABLE_HDMI=OFF,libdrm"
PACKAGES =+ "${PN}-hdmi"
SYSTEMD_PACKAGES = "${@bb.utils.contains('PACKAGECONFIG', 'hdmi', '${PN}-hdmi', '', d)}"
SYSTEMD_SERVICE:${PN}-hdmi = "yunet-hdmi.service"
SYSTEMD_AUTO_ENABLE:${PN}-hdmi = "${@'enable' if d.getVar('YUNET_HDMI_AUTOSTART') == '1' else 'disable'}"
RDEPENDS:${PN}-hdmi = "${PN}"
EXTRA_OECMAKE = "-DENABLE_VART=ON -DBUILD_TESTING=OFF"
do_configure:prepend() {
    printf '%s  %s\n' '39bb7312515e3fb350676681571152ed6c0a34afaba850a385d69ee01e3f2752' '${S}/model/yunet_smartcam.xmodel' | sha256sum -c -
}
do_install() {
    install -d ${D}/opt/yunet/bin ${D}/opt/yunet/model ${D}/opt/yunet/config
    install -m0755 ${B}/yunet-kv260 ${D}/opt/yunet/bin/
    install -m0644 ${S}/model/yunet_smartcam.xmodel ${D}/opt/yunet/model/
    install -m0644 ${S}/config/yunet.conf ${D}/opt/yunet/config/
    install -m0755 ${S}/scripts/run.sh ${D}/opt/yunet/run.sh
    if ${@bb.utils.contains('PACKAGECONFIG', 'hdmi', 'true', 'false', d)}; then
        install -d ${D}${systemd_system_unitdir} ${D}${sysconfdir}/default
        install -m0755 ${B}/yunet-hdmi ${D}/opt/yunet/bin/
        install -m0755 ${S}/scripts/hdmi.sh ${D}/opt/yunet/hdmi.sh
        install -m0644 ${S}/config/yunet-hdmi ${D}${sysconfdir}/default/yunet-hdmi
        install -m0644 ${S}/scripts/yunet-hdmi.service ${S}/scripts/yunet-inference.service ${D}${systemd_system_unitdir}/
    fi
}
FILES:${PN}-hdmi = "/opt/yunet/bin/yunet-hdmi /opt/yunet/hdmi.sh ${systemd_system_unitdir}/yunet-hdmi.service ${systemd_system_unitdir}/yunet-inference.service ${sysconfdir}/default/yunet-hdmi"
CONFFILES:${PN}-hdmi = "${sysconfdir}/default/yunet-hdmi"
FILES:${PN} = "/opt/yunet"
CONFFILES:${PN} = "/opt/yunet/config/yunet.conf"
COMPATIBLE_MACHINE = "kv260-vision"
PACKAGE_ARCH = "${MACHINE_ARCH}"
