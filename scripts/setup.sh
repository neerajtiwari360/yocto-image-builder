#!/bin/bash
# Device-independent foundation; does not fetch sources or build a target.
set -euo pipefail
mkdir -p /work/layers /work/builds /work/downloads /work/sstate-cache /work/project-layers /work/exports /work/logs
validate-foundation
echo 'Foundation ready. Next select a target under /project/yocto/targets/.'
