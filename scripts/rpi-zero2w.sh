#!/bin/bash
# Compatibility entry point for the original Pi workflow.
set -eo pipefail
exec bash /project/scripts/image.sh rpi-zero2w-minimal "${1:-build}"
