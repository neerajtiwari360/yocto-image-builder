# yocto-image-builder

Build custom Linux OS images for multiple device models using one shared Docker build environment.

## What belongs where?

| Location | Purpose | Runs on the device? |
| --- | --- | --- |
| docker/ | Ubuntu build tools, non-root build user, foundation checks | No |
| compose.yaml | Starts the local builder and attaches its persistent Linux workspace | No |
| yocto/layers/ | Future version-controlled OS recipes, packages, services and configuration | Selected contents become part of the OS |
| yocto/targets/ | Future named build selections: release + machine + distro + image | Controls what is built |
| docs/ | Setup, architecture and usage guides | No |
| artifacts/ | Copies of completed device images and their release records | Images here can be flashed |
| /work inside builder | Linux sources, caches and separate build directories in a persistent Docker volume | No; contains generated device images |

The Docker image is a development tool. The Yocto image is the operating system you flash onto a device.
Adding software to docker/Dockerfile only installs it in the builder.
Adding software to a Yocto image recipe controls installation in the device OS.

## Folder layout

    yocto-image-builder/
      compose.yaml
      docker/
        Dockerfile
        .dockerignore
        validate-foundation.sh
      yocto/
        layers/
          README.md
        targets/
          README.md
      docs/
        docker-setup.md
        project-structure.md
      artifacts/
        README.md

## Start the local builder

From PowerShell in D:\Github\yocto-image-builder:

    docker compose build
    docker compose run --rm builder validate-foundation
    docker compose run --rm builder

Inside the container, work in /work. Type exit to leave.
Your /work files survive disposable container removal.
Do not remove the Docker volume unless you intend to delete the workspace.

## Scaling to more boards and images

Keep hardware support (MACHINE), shared OS policy (DISTRO), and software selection (image recipe) separate.
One device model can have minimal, gateway and graphical image variants.
Many physical devices of the same model can use the same image; give each its own identity during provisioning.
Keep each target's build directory separate. Reuse compatible download and sstate caches.

Read docs/project-structure.md before adding a target.
No Yocto release, machine or image is configured yet. The yocto/ directories are documented placeholders, not a runnable build system.
