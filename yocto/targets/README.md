# Named build targets
rpi-zero2w-minimal/ is the first configured target: Pi Zero 2 W, 32-bit, Yocto Scarthgap.
sources.conf locks upstream commits; local.conf selects the machine and resource limits.
Run it using scripts/rpi-zero2w.sh. See docs/rpi-zero2w-minimal.md.
Each additional supported combination should have its own target directory and build directory.
