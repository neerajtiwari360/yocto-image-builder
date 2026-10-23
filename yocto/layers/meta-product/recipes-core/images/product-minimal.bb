require recipes-core/images/core-image-minimal.bb
SUMMARY = "Small console-only learning image for supported product boards"
# Pi's selected kernel includes standard USB keyboard and framebuffer support.
# Keep applications out of this baseline; add separate image variants later.
