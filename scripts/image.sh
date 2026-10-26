#!/bin/bash
# Repository target files are trusted Bash configuration, not BitBake metadata.
set -eo pipefail
project=${PROJECT_DIR:-/project}
target=${1:-}
mode=${2:-build}
if [[ ! "$target" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Usage: bash /project/scripts/image.sh <target> [prepare|parse|build|export]"
    exit 2
fi
case "$mode" in prepare|parse|build|export) ;; *) echo "Unknown mode: $mode"; exit 2 ;; esac
config="$project/yocto/targets/$target"
test -f "$config/target.conf" || { echo "No configured target: $target"; exit 2; }
source "$config/sources.conf"
source "$config/target.conf"
: "${RELEASE:?}" "${IMAGE_RECIPE:?}" "${TARGET_MACHINE:?}" "${POKY_COMMIT:?}" "${POKY_TAG:?}"
[[ "$RELEASE" =~ ^[a-z0-9][a-z0-9-]*$ ]] || exit 2
[[ "$POKY_COMMIT" =~ ^[0-9a-f]{40}$ ]] || { echo "Poky requires an exact commit"; exit 2; }
test "${#EXPORT_FILES[@]}" -gt 0 || { echo "Configure EXPORT_FILES"; exit 2; }
if [[ "$mode" = build || "$mode" = export ]]; then
    mountpoint -q /artifacts && test -w /artifacts || {
        echo "Mount the writable local artifacts folder at /artifacts (use docker compose)."
        exit 1
    }
fi
poky="/work/layers/$RELEASE/poky"
build="/work/builds/$RELEASE/$target"
mkdir -p "/work/builds/$RELEASE" /work/logs /work/downloads /work/sstate-cache
exec 9>"$build.lock"
flock -n 9 || { echo "This target is already in use"; exit 1; }
# Different targets may share upstream repositories. Serialize their preparation.
mkdir -p "/work/layers/$RELEASE"
exec 8>"/work/layers/$RELEASE/.prepare.lock"
flock 8
checkout() {
    local path=$1 url=$2 revision=$3
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo "Exact commit required: $path"; return 2; }
    if [ ! -d "$path/.git" ]; then
        test ! -e "$path" || { echo "Refusing to replace $path"; return 1; }
        git init "$path"
        git -C "$path" remote add origin "$url"
        git -C "$path" fetch --depth 1 origin "$revision"
        git -C "$path" checkout --detach FETCH_HEAD
    fi
    test "$(git -C "$path" rev-parse HEAD)" = "$revision" || { echo "$path differs from source lock"; return 1; }
    test -z "$(git -C "$path" status --porcelain)" || { echo "$path has local changes"; return 1; }
}
checkout "$poky" "$POKY_URL" "$POKY_COMMIT"
layers=()
for entry in "${EXTERNAL_LAYERS[@]}"; do
    IFS='|' read -r name url revision subdir <<< "$entry"
    [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || exit 2
    path="/work/layers/$RELEASE/$name"
    checkout "$path" "$url" "$revision"
    layers+=("$path${subdir:+/$subdir}")
done
flock -u 8
for name in "${LOCAL_LAYERS[@]}"; do
    [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || exit 2
    # Separate copies prevent one target's synchronization changing another build.
    path="/work/project-layers/$RELEASE/$target/$name"
    mkdir -p "$path"
    rsync -a --delete "$project/yocto/layers/$name/" "$path/"
    layers+=("$path")
done
source "$poky/oe-init-build-env" "$build" >/dev/null
include="require $config/local.conf"
grep -Fxq "$include" conf/local.conf || printf '\n%s\n' "$include" >> conf/local.conf
# Replace runner-owned layer entries.
sed -i '/^# image-builder managed layers$/d; /^BBLAYERS += "\/work\/\(layers\|project-layers\)\//d' conf/bblayers.conf
printf '\n# image-builder managed layers\n' >> conf/bblayers.conf
for layer in "${layers[@]}"; do
    test -f "$layer/conf/layer.conf" || { echo "Missing layer: $layer"; exit 1; }
    printf 'BBLAYERS += "%s"\n' "$layer" >> conf/bblayers.conf
done
case "$mode" in
    prepare) echo "Prepared $target: $build" ;;
    parse) bitbake -p ;;
    build|export)
        if [ "$mode" = build ]; then bitbake "$IMAGE_RECIPE"; fi
        deploy="$build/tmp/deploy/images/$TARGET_MACHINE"
        for file in "${EXPORT_FILES[@]}"; do
            test -f "$deploy/$file" || { echo "Missing completed output: $deploy/$file"; exit 1; }
        done
        version="$POKY_TAG-$(date -u +%Y%m%dT%H%M%S%NZ)"
        output="/work/exports/$RELEASE/$target/$version"
        mkdir -p "$(dirname "$output")"
        mkdir "$output"
        for file in "${EXPORT_FILES[@]}"; do cp -L "$deploy/$file" "$output/"; done
        if [ -n "${SD_IMAGE_BZ2:-}" ]; then
            bzip2 -dc "$deploy/$SD_IMAGE_BZ2" > "$output/$target.img"
            if [ -n "${IMAGE_VERIFIER:-}" ]; then
                python3 "$project/scripts/$IMAGE_VERIFIER" "$output/$target.img" | tee "$output/validation.txt"
            fi
        fi
        cp -a "$config" "$output/target-config"
        cp -a "$project/yocto/config" "$output/shared-config"
        for name in "${LOCAL_LAYERS[@]}"; do cp -a "/work/project-layers/$RELEASE/$target/$name" "$output/"; done
        cp conf/local.conf conf/bblayers.conf "$output/"
        printf 'Target: %s\nImage: %s\nMachine: %s\nPoky: %s\n' "$target" "$IMAGE_RECIPE" "$TARGET_MACHINE" "$POKY_COMMIT" > "$output/build-info.txt"
        (cd "$output"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
        local_parent="/artifacts/$RELEASE/$target"
        mkdir -p "$local_parent"
        local_stage=$(mktemp -d "$local_parent/.partial-$version.XXXXXX")
        # Copy regular files, not Linux ownership or symlinks, onto the host mount.
        cp -R "$output/." "$local_stage/"
        (cd "$local_stage"; sha256sum -c SHA256SUMS >/dev/null)
        test ! -e "$local_parent/$version" || { echo "Local export already exists"; exit 1; }
        mv -T "$local_stage" "$local_parent/$version"
        printf '%s\n' "$output" | tee "/work/exports/$target-latest.txt"
        printf 'Saved locally: artifacts/%s/%s/%s/\n' "$RELEASE" "$target" "$version"
        ;;
esac
