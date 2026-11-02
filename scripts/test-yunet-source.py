"""Source-integration regression tests; no BitBake, network or hardware required."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('verify_source', Path(__file__).with_name('verify-yunet-source.py'))
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
RECIPE = Path(__file__).resolve().parents[1] / 'yocto/layers/meta-kv260-vision/recipes-apps/yunet'


class SourceTests(unittest.TestCase):
    def test_current_release(self):
        checker.verify(RECIPE)

    def test_tamper_rejected(self):
        for name in ('files/runtime.tar.gz', 'kv260-yunet.bb'):
            with self.subTest(file=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / 'recipe'
                shutil.copytree(RECIPE, root)
                with (root / name).open('ab') as output:
                    output.write(b'corruption')
                with self.assertRaises(ValueError):
                    checker.verify(root)


if __name__ == '__main__':
    unittest.main()
