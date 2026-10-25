require recipes-core/images/core-image-minimal.bb
SUMMARY = "KV260 UART console and HC-SR04 userspace reader"
IMAGE_INSTALL:append = " hcsr04-reader hcsr04-emio-firmware"
# Boot assets are built explicitly; the card reuses the SOM's QSPI boot firmware.
do_image_wic[depends] += "kv260-boot-script:do_deploy virtual/kernel:do_deploy"
