SUMMARY = "Persistent on-board C project workspace"
LICENSE = "CLOSED"
SRC_URI = "file://projects"
S = "${WORKDIR}"

# Sources and optional AArch64 executables copied back from the board are shipped
# unchanged. Build production applications in their own recipes when needed.
do_install() {
    install -d ${D}/opt/projects
    cp -R --no-preserve=ownership ${WORKDIR}/projects/. ${D}/opt/projects/
}

FILES:${PN} = "/opt/projects"
