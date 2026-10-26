Use /opt/projects for your C sources, Makefiles and compiled programs.
Files saved here survive a normal reboot. Run sync before shutting down.
Back up this directory before reflashing: flashing replaces the root filesystem.

To include your work in a future Yocto image, copy it back to:
yocto/layers/meta-kv260/recipes-devtools/board-projects/files/projects/
on your PC, then rebuild the target. Board changes are not imported automatically.
See docs/kv260-hcsr04-minimal.md in the image-builder repository.
