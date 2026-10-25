#!/bin/bash
# Hardware-independent conversion and CLI guard tests in the build container.
set -euo pipefail
scratch=$(mktemp -d /tmp/hcsr04-test.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
cp -R /project/yocto/layers/meta-kv260/recipes-apps/hcsr04-reader/files/source/. "$scratch/"
make -C "$scratch" CC=gcc AR=ar test
