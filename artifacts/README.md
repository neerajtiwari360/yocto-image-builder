# Exported device images

Future release layout: <release>/<target>/<version>/.
Store final image files with checksums, package manifests, size measurements and exact build revision records.
These are device OS deliverables. The local Docker build image is managed by Docker, not stored here.
Generated release files are ignored by Git; only this guide is tracked.

Current retained HDMI release:
`scarthgap-kv260/kv260-vision-hdmi/yocto-5.0.19-20261102T132521922766719Z/`.
It contains the boot UUID fix, `.img`, compressed WIC, checksums and build records.
Eight older release bundles were moved intact to
`D:\Github\kv260-project-archive-20261102\image-exports`.
See [the cleanup record](../docs/project-cleanup.md) for verification and recovery.
