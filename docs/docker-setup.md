# Reusable Docker foundation

Requires Docker Desktop running Linux containers. Use PowerShell in the repository root:

```powershell
docker compose build
docker compose run --rm builder bash /project/scripts/setup.sh
docker compose run --rm builder
```

The image uses Ubuntu 22.04 and a non-root builder with UID/GID 1000.
It contains host compilers, Python, Git and other Yocto prerequisites, not the device OS.
No privileged mode or Docker socket is needed. Add host dependencies to docker/Dockerfile
and rebuild; select device packages in Yocto image recipes.

/project is the read-only Windows checkout. /work is the named Linux volume
`yocto-foundation-workspace`. Sources, caches and generated files belong in /work.
Do not use `docker compose down --volumes` or reset Docker Desktop unless deleting that data is intended.
Check host disk space as well as Docker filesystem space before large builds.

Foundation setup does not choose a device. Follow ../README.md to select and prepare a target.

## Automatic local output

Compose mounts ./artifacts read-write at /artifacts alongside the read-only /project mount.
The build command automatically exports the completed image and copies the release into
artifacts/<release>/<target>/<version>/ on Windows. Checksums are checked after copying;
the final directory appears only after the copy and verification succeed. A failed copy
may leave a hidden .partial directory; the original Linux export remains available.
Run the export command to retry without rebuilding. No docker cp is required.
Containers already running before this mount was added must be exited and recreated
with docker compose run. Linux build files and caches remain in the named workspace volume.