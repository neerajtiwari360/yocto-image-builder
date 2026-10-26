require recipes-core/images/core-image-minimal.bb
SUMMARY = "KV260 UART console with optional post-boot C tool installation"
# Keep the historical recipe/target names so existing build commands still work.
# Keep build tools out of the base image; install matching IPKs later if needed.
IMAGE_FEATURES:remove = "tools-sdk dev-pkgs read-only-rootfs"
IMAGE_FEATURES += "package-management"
IMAGE_INSTALL:append = " board-projects"
# Boot assets are built explicitly; the card reuses the SOM's QSPI boot firmware.
do_image_wic[depends] += "kv260-boot-script:do_deploy virtual/kernel:do_deploy"
