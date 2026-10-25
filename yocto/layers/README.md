# Custom Yocto layers

meta-kv260/ contains the Xilinx Kria KV260 BSP additions and HC-SR04 image.
meta-product/ is the shared Scarthgap product layer.
This parent directory is not itself a layer and must not be added to BBLAYERS.
Third-party BSP repositories live under /work/layers/<release>/.
The build helper copies authored metadata to /work/project-layers/<release>/<target>/<layer> on Linux storage.
Edit the Windows source in this project, not the generated Linux copy.
