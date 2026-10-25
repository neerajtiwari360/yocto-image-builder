SUMMARY = "HC-SR04 C userspace GPIO reader from kria-project"
LICENSE = "CLOSED"
SRC_URI = "file://source"
S = "${WORKDIR}/source"
do_compile() {
    oe_runmake CC="${CC}" AR="${AR}" CPPFLAGS="${CPPFLAGS} -Iinclude -Iapp" CFLAGS="${CFLAGS} -std=c11 -Wall -Wextra -Wpedantic -Werror" LDFLAGS="${LDFLAGS}"
}
do_install() {
    install -Dm0755 ${S}/hcsr04-reader ${D}${bindir}/hcsr04-reader
}
