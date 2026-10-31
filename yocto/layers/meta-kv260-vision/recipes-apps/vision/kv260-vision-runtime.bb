SUMMARY = "Headless KV260 camera initialization and drop-in YuNet DPU inference"
LICENSE = "CLOSED"
SRC_URI = "file://kv260-vision file://camera_setup.sh file://infer.sh file://vision.conf file://README.txt"
S = "${WORKDIR}"
inherit update-rc.d
INITSCRIPT_NAME = "kv260-vision"
INITSCRIPT_PARAMS = "defaults 95 05"
RDEPENDS:${PN} = "vart xir media-ctl v4l-utils kmod busybox"
do_install() {
    install -d ${D}${libexecdir}/kv260-vision ${D}${bindir} ${D}${sysconfdir}/init.d ${D}${sysconfdir}/default ${D}/opt/models ${D}${docdir}/${PN}
    install -m0755 ${WORKDIR}/kv260-vision ${D}${sysconfdir}/init.d/kv260-vision
    install -m0755 ${WORKDIR}/camera_setup.sh ${D}${libexecdir}/kv260-vision/camera_setup.sh
    install -m0755 ${WORKDIR}/infer.sh ${D}${libexecdir}/kv260-vision/infer.sh
    ln -s ../libexec/kv260-vision/camera_setup.sh ${D}${bindir}/kv260-camera-setup
    ln -s ../libexec/kv260-vision/infer.sh ${D}${bindir}/kv260-infer
    install -m0644 ${WORKDIR}/vision.conf ${D}${sysconfdir}/default/kv260-vision
    install -m0644 ${WORKDIR}/README.txt ${D}${docdir}/${PN}/README.txt
}
FILES:${PN} += "${libexecdir}/kv260-vision /opt/models"
CONFFILES:${PN} = "${sysconfdir}/default/kv260-vision"
