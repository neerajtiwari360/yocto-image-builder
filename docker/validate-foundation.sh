#!/bin/bash
set -euo pipefail
test "$(id -u)" -ne 0
test -w /work
test "$(locale charmap)" = UTF-8
for tool in git gcc g++ make python3 tar gawk diffstat chrpath cpio wget zstd lz4 patch; do
    command -v "$tool" >/dev/null
done
python3 -c 'import git, jinja2, pexpect'
scratch=$(mktemp -d /work/.foundation-check.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
cd "$scratch"
printf 'upper' > Case
printf 'lower' > case
test "$(cat Case)" = upper
test "$(cat ./case)" = lower
ln -s Case linked
test "$(cat linked)" = upper
printf '#!/bin/sh
exit 0
' > executable
chmod +x executable
./executable
printf 'int main(void) { return 0; }
' > hello.c
gcc hello.c -o hello
./hello
printf 'PASS: non-root user, writable workspace, UTF-8, dependencies, case sensitivity, symlinks, executable permissions, C compilation.
'
id
cat /etc/os-release | head -2
stat -f -c 'Workspace filesystem: %T' /work
df -h /work
free -h
git --version
python3 --version
