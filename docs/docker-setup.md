# Docker foundations for Yocto
The project layout is described in ../README.md. No Yocto repositories or Raspberry Pi image have been built.

## Layout
Windows project: D:\Github\yocto-image-builder
Build environment: Ubuntu 22.04, x86_64, user builder (UID/GID 1000).
Persistent Linux workspace: Docker volume yocto-foundation-workspace mounted at /work.
Future layers, downloads, sstate and builds belong under /work, not on a Windows bind mount.
The volume survives disposable container removal and image rebuilds. It is not a backup.
Do not use docker compose down --volumes or Docker Desktop factory reset unless you intend to lose this workspace.

## Use from PowerShell
    Set-Location D:\Github\yocto-image-builder
    docker compose build
    docker compose run --rm builder validate-foundation
    docker compose run --rm builder

Inside the shell:
    id
    cd /work
    ls
    exit

Each run starts a disposable container. Files in /work persist. Install additional system packages by editing docker/Dockerfile and rebuilding.
No privileged mode, Docker socket mount or passwordless sudo is provided.
Docker Desktop must be running in Linux containers mode.

## WSL
Docker Desktop itself uses WSL2; this has been verified. Ubuntu is also installed as a WSL2 distro.
Docker integration inside the separate Ubuntu distro is currently disabled. PowerShell commands above work without it.
If you want to run Docker directly from Ubuntu later, enable Settings > Resources > WSL Integration > Ubuntu in Docker Desktop.
Do not install a second Docker daemon in Ubuntu.

## Before the first Yocto build
Choose the Raspberry Pi model, Yocto release, required software/services and storage layout.
This container uses packages suitable as a Scarthgap foundation; check the exact release's host requirements before building.
The container architecture is the build host architecture; Yocto will cross-compile for Raspberry Pi.
Docker currently sees 12 CPUs and about 7.4 GiB RAM. Existing services also consume resources.
Review memory, swap and free physical disk space before a full build. The initial check found about 104 GiB free on C: and 200 GiB on D:.
The Linux virtual disk's advertised free capacity is not the same as free Windows host storage.
Do not assume the Docker volume is stored on D: just because these setup files are there.
Full builds and caches can exceed 100 GiB; plan storage before proceeding.
Export final images to Windows after a build rather than building on the Windows filesystem.
No global Docker or WSL settings were changed.

References:
https://docs.docker.com/desktop/features/wsl/best-practices/
https://docs.yoctoproject.org/5.0.14/ref-manual/system-requirements.html
