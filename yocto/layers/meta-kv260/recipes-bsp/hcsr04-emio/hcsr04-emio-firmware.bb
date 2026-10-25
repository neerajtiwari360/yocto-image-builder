SUMMARY = "Pinned KV260 Pmod EMIO bitstream and HC-SR04 preparation tool"
LICENSE = "BSD-2-Clause"
# Checksum of upstream Git bytes (LF), not a Windows CRLF working copy.
LIC_FILES_CHKSUM = "file://LICENSE;md5=6d4d7a52a6c1d153537c960df78d5cd8"
SRC_URI = " \
    git://github.com/ikwzm/Kv260-Pmod-gpio-emio.git;protocol=https;nobranch=1 \
    file://hcsr04-emio.dts \
    file://hcsr04-prepare \
"
SRCREV = "33fbc93e46f942093b355023ee8e614aecebf989"
S = "${WORKDIR}/git"
DEPENDS = "dtc-native"
PACKAGE_ARCH = "${MACHINE_ARCH}"
COMPATIBLE_MACHINE = "^kv260-hcsr04$"

python do_unpack:append() {
    import gzip
    import hashlib
    import pathlib
    import struct
    source = pathlib.Path(d.getVar('S')) / 'kv260-pmod-gpio-emio.bin.gz'
    if hashlib.sha256(source.read_bytes()).hexdigest() != 'd7c5344c4d8f0b0f64fbdf4e4574e2749cce0618ad7c8a23147b61e97e79be4b':
        bb.fatal('Pinned FPGA bitstream checksum mismatch')
    binary = gzip.decompress(source.read_bytes())
    ids = [struct.unpack_from('<I', binary, i + 4)[0]
           for i in range(0, len(binary) - 7, 4)
           if binary[i:i + 4] == struct.pack('<I', 0x30018001)]
    if ids != [0x04A49093]:
        bb.fatal('Expected exactly one K26 FPGA IDCODE 0x04A49093')
    (pathlib.Path(d.getVar('WORKDIR')) / 'ubiety-gy521-emio.bit.bin').write_bytes(binary)
}
do_compile() {
    dtc -@ -I dts -O dtb -o ${B}/hcsr04-emio.dtbo ${WORKDIR}/hcsr04-emio.dts
}
do_install() {
    install -Dm0644 ${WORKDIR}/ubiety-gy521-emio.bit.bin ${D}${nonarch_base_libdir}/firmware/ubiety-gy521-emio.bit.bin
    install -Dm0644 ${B}/hcsr04-emio.dtbo ${D}${datadir}/hcsr04/hcsr04-emio.dtbo
    install -Dm0755 ${WORKDIR}/hcsr04-prepare ${D}${sbindir}/hcsr04-prepare
    install -Dm0644 ${S}/LICENSE ${D}${datadir}/licenses/hcsr04-emio-firmware/LICENSE
}
FILES:${PN} += "${nonarch_base_libdir}/firmware ${datadir}/hcsr04 ${datadir}/licenses/hcsr04-emio-firmware"
