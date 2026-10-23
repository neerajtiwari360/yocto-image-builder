# Custom Yocto layers
meta-product/ is an initialized Scarthgap layer containing product-minimal.
This parent directory is not itself a layer and must not be added to BBLAYERS.
Third-party BSP repositories live under /work/layers/<release>/.
The build helper copies authored metadata to /work/project-layers/meta-product on Linux storage.
Edit the Windows source in this project, not the generated Linux copy.
