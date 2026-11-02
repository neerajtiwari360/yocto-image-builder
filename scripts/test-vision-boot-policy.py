"""Exercise the image recipe's real boot-policy QA, including absolute unit links."""
from pathlib import Path
from types import SimpleNamespace
import argparse
import os
import posixpath
import shutil
import tempfile

repo=Path(__file__).resolve().parents[1]
recipe=repo/'yocto/layers/meta-kv260-vision/recipes-core/images/product-vision-minimal.bb'
body=recipe.read_text().split('python verify_vision_rootfs() {\n',1)[1].rsplit('\n}',1)[0]
def fatal(message):
    raise RuntimeError(message)
def verify(root,autostart='1'):
    values={'IMAGE_ROOTFS':str(root),'YUNET_HDMI_IMAGE':'1','YUNET_HDMI_AUTOSTART':autostart}
    namespace={'bb':SimpleNamespace(fatal=fatal,note=lambda value:None),
               'd':SimpleNamespace(getVar=values.get)}
    exec('def check():\n'+body,namespace)
    namespace['check']()

p=argparse.ArgumentParser()
p.add_argument('--rootfs',type=Path)
p.add_argument('--model',type=Path,default=repo.parent/'FaceGuard/kv260-yunet/runtime/model/yunet_smartcam.xmodel')
a=p.parse_args()
if a.rootfs:
    verify(a.rootfs)
    print('PASS: generated rootfs assets, HDMI boot link and manual ML policy')
    raise SystemExit(0)

fixture_parent=(Path(tempfile.gettempdir())/'kv260-boot-policy-tests').resolve()
fixture_parent.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='rootfs-',dir=fixture_parent) as directory:
    root=Path(directory).resolve()
    assert root.is_relative_to(fixture_parent)
    assets='''lib/firmware/ap1302_ar1335_single_fw.bin
lib/firmware/kv260-smartcam.bit.bin
lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.dtbo
lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin
usr/bin/media-ctl
usr/bin/v4l2-ctl
usr/bin/kv260-camera-setup
usr/bin/kv260-infer
usr/libexec/kv260-vision/boot.sh
opt/yunet/bin/yunet-kv260
opt/yunet/bin/yunet-hdmi
opt/yunet/run.sh
opt/yunet/config/yunet.conf
usr/bin/systemctl
usr/bin/timeout
usr/lib/systemd/system/yunet-hdmi.service
usr/lib/systemd/system/yunet-inference.service
usr/lib/systemd/system/kv260-vision.service
etc/default/yunet-hdmi'''.splitlines()
    for name in assets:
        f=root/name;f.parent.mkdir(parents=True,exist_ok=True);f.write_text('fixture\n')
    config=root/'etc/vart.conf';config.parent.mkdir(parents=True,exist_ok=True)
    config.write_text('firmware: /lib/firmware/xilinx/kv260-smartcam/kv260-smartcam.xclbin\n')
    model=root/'opt/yunet/model/yunet_smartcam.xmodel';model.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(a.model,model)
    wants=root/'etc/systemd/system/multi-user.target.wants';wants.mkdir(parents=True)
    link=wants/'yunet-hdmi.service'
    def expect_failure(fragment,autostart='1'):
        try:verify(root,autostart)
        except RuntimeError as e:
            assert fragment in str(e),(fragment,str(e))
        else:raise AssertionError('Expected QA failure: '+fragment)
    os.symlink('/usr/lib/systemd/system/yunet-hdmi.service',link)
    assert link.is_symlink()
    verify(root);print('PASS: absolute target-root symlink')
    expect_failure('boot policy differs','0')
    link.unlink()
    relative=posixpath.relpath('usr/lib/systemd/system/yunet-hdmi.service',
                              'etc/systemd/system/multi-user.target.wants')
    os.symlink(relative,link);verify(root);print('PASS: relative target-root symlink')
    link.unlink();expect_failure('boot policy differs');verify(root,'0')
    print('PASS: missing enablement rejected when required, accepted when disabled')
    os.symlink('/usr/lib/systemd/system/other.service',link)
    expect_failure('unexpected target');link.unlink()
    print('PASS: wrong unit target rejected')
    link.write_text('not a symlink');expect_failure('enablement symlink');link.unlink()
    print('PASS: regular-file enablement rejected')
    os.symlink('/usr/lib/systemd/system/yunet-hdmi.service',link)
    ml=wants/'yunet-inference.service'
    os.symlink('/usr/lib/systemd/system/yunet-inference.service',ml)
    expect_failure('ML inference must remain manually controlled');ml.unlink()
    print('PASS: accidental ML autostart rejected')
    # Remove the links explicitly; temporary cleanup remains inside fixture_parent.
    link.unlink()
print('All boot-policy regression tests passed')
