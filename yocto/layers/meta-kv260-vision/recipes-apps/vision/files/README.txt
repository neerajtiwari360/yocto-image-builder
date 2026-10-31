KV260 native C/C++ vision runtime
Camera setup uses media-ctl and v4l2-ctl; see /var/log/kv260-camera.log and /run/kv260-camera.conf.
Deploy the cross-compiled package under /opt/yunet, then run: kv260-infer --frames 300
Use the B3136 model (fingerprint 0x101000016010406).
Set AUTORUN=yes in /etc/default/kv260-vision after deployment to run at boot.
No Python, NumPy, OpenCV or GStreamer is requested by this image.
Physical boot/camera/DPU verification remains required.
