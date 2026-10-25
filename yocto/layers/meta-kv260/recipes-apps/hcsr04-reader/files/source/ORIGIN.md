# Source provenance

Copied from D:/Github/kria-project/software/hcsr04, repository commit
28c66e9ecd0aaedec1363bed7e410bbc8a395104 on 2026-10-24.
Only C source, headers, Makefile and tests are included; no prebuilt executables,
Python tools, plots or other sensor projects are installed.

Port: driver/hcsr04_driver.c checks /proc/device-tree/fpga-region/firmware-name,
matching the pinned 6.6.40 vendor kernel. The previous 5.15 PetaLinux code used
/fpga-full. Firmware identity, GPIO chip identity/line count, exclusive line
requests, conflicting-overlay checks and explicit wiring confirmation remain.

This is an intentional source snapshot. Later changes in kria-project do not
silently change an image; update this snapshot and provenance explicitly.
