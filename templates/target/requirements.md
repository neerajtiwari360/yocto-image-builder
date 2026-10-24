# Image requirements

Complete this before creating a configured target.

- Target name and intended use:
- Board/model/revision and CPU architecture:
- Vendor BSP layer and supported Yocto release:
- Exact upstream commits and release tag:
- Boot medium, bootloader and required output format:
- Console/display, networking and required drivers/firmware:
- Required applications and services:
- Maximum image size, RAM and storage budget:
- Authentication, updates and provisioning:
- Licenses and redistribution requirements:
- Structural checks and physical boot acceptance criteria:

Use one target per board/software combination. Keep shared software in
yocto/layers/meta-product. Add local machine changes in a BSP layer only when needed.
