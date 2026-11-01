SUMMARY = "Optimized native YuNet camera inference for KV260 SmartCam"
LICENSE = "CLOSED"
SRC_URI = "file://runtime.tar.gz"
S = "${WORKDIR}/runtime"
DEPENDS = "vart xir"
RDEPENDS:${PN} = "kv260-vision-runtime"
inherit cmake
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
}
FILES:${PN} = "/opt/yunet"
CONFFILES:${PN} = "/opt/yunet/config/yunet.conf"
COMPATIBLE_MACHINE = "kv260-vision"
PACKAGE_ARCH = "${MACHINE_ARCH}"
