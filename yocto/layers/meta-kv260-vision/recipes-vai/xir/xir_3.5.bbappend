FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-attrs-include-cstdint.patch"

PACKAGECONFIG:remove = "python"

EXTRA_OECMAKE:append = " -DBUILD_PYTHON=OFF"

SRC_URI += "file://0002-protobuf-config-dependencies.patch"
EXTRA_OECMAKE:append = " -DXIR_HOST_PROTOC=${STAGING_BINDIR_NATIVE}/protoc -DProtobuf_PROTOC_EXECUTABLE=${STAGING_BINDIR_NATIVE}/protoc"
