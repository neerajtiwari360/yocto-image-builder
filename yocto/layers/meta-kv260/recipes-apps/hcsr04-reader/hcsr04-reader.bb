SUMMARY = "HC-SR04 C userspace GPIO reader from kria-project"
LICENSE = "CLOSED"
FILESEXTRAPATHS:prepend := "${THISDIR}/files/source:"
SRC_URI = "file://app"
S = "${WORKDIR}/app"
DEPENDS = "hcsr04-driver"
do_compile() {
    ${CC} ${CPPFLAGS} ${CFLAGS} -std=c11 -Wall -Wextra -Wpedantic -Werror \
        -I${S} ${S}/main.c ${S}/distance.c ${LDFLAGS} -lhcsr04 -o ${B}/hcsr04-reader
}
do_install() {
    install -Dm0755 ${B}/hcsr04-reader ${D}${bindir}/hcsr04-reader
}
