SUMMARY = "HC-SR04 userspace GPIO driver library"
DESCRIPTION = "Hardware access and raw edge timestamps; no distance conversion, CLI or CSV output."
LICENSE = "CLOSED"
# Shared source snapshot, with independent file dependencies for each recipe.
FILESEXTRAPATHS:prepend := "${THISDIR}/../../recipes-apps/hcsr04-reader/files/source:"
SRC_URI = "file://driver file://include"
S = "${WORKDIR}"

do_compile() {
    ${CC} ${CPPFLAGS} ${CFLAGS} -std=c11 -Wall -Wextra -Wpedantic -Werror \
        -I${S}/include -c ${S}/driver/hcsr04_driver.c -o ${B}/hcsr04_driver.o
    ${AR} rcs ${B}/libhcsr04.a ${B}/hcsr04_driver.o
}

do_install() {
    install -Dm0644 ${B}/libhcsr04.a ${D}${libdir}/libhcsr04.a
    install -Dm0644 ${S}/include/hcsr04_driver.h ${D}${includedir}/hcsr04_driver.h
}
