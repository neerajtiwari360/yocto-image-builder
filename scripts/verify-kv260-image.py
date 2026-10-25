"""Use the shared SD layout checker with KV260 boot-file requirements."""
import pathlib
import runpy
import sys

sys.argv = [sys.argv[0], sys.argv[1], "kv260"]
runpy.run_path(str(pathlib.Path(__file__).with_name("verify-sd-image.py")), run_name="__main__")
