"""Verify the pinned FaceGuard source release without requiring a FaceGuard checkout."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import tarfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verify(recipe_dir, faceguard=None):
    recipe_dir = Path(recipe_dir)
    files = recipe_dir / 'files'
    recipe = (recipe_dir / 'kv260-yunet.bb').read_bytes()
    release = json.loads((files / 'source-release.json').read_text())
    if release['schema_version'] != 1 or sha(recipe) != release['recipe_sha256']:
        raise ValueError('Recipe checksum or release schema mismatch')
    if not re.fullmatch(r'[0-9a-f]{40}', release['source_commit']):
        raise ValueError('Invalid source commit')
    if release['platform_id'] != 'kv260-smartcam-b3136-v1':
        raise ValueError('Wrong source platform')
    archive = files / 'runtime.tar.gz'
    pin = re.search(rb'YUNET_SOURCE_SHA256 = "([0-9a-f]{64})"', recipe)
    if not pin or sha(archive.read_bytes()) != pin[1].decode() or pin[1].decode() != release['archive_sha256']:
        raise ValueError('Source archive does not match recipe pin')
    seen = {}
    with tarfile.open(archive, 'r:gz') as tar:
        for member in tar.getmembers():
            path = PurePosixPath(member.name)
            if (not member.isfile() or path.is_absolute() or '..' in path.parts
                    or not path.parts or path.parts[0] != 'runtime' or member.name in seen):
                raise ValueError('Unsafe or duplicate source archive entry')
            seen[member.name] = tar.extractfile(member).read()
    embedded = json.loads(seen.pop('runtime/SOURCE_RELEASE.json'))
    if embedded != {k: v for k, v in release.items() if k not in ('archive_sha256', 'recipe_sha256')}:
        raise ValueError('Embedded source provenance mismatch')
    actual = {name.removeprefix('runtime/'): sha(data) for name, data in seen.items()}
    if actual != release['files']:
        raise ValueError('Source file checksums differ')
    if faceguard:
        project = Path(faceguard) / 'kv260-yunet'
        template = (project / 'tools/kv260-yunet.bb').read_bytes()
        if sha(template) != release['recipe_template_sha256'] or template.replace(b'@YUNET_SOURCE_SHA256@', pin[1]) != recipe:
            raise ValueError('Recipe template differs from source release')
        for name, digest in actual.items():
            if sha((project / 'runtime' / name).read_bytes()) != digest:
                raise ValueError('Maintained source differs from release: ' + name)
    return release


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recipe', type=Path, default=Path(__file__).resolve().parents[1] / 'yocto/layers/meta-kv260-vision/recipes-apps/yunet')
    parser.add_argument('--faceguard', type=Path)
    args = parser.parse_args()
    result = verify(args.recipe, args.faceguard)
    print('PASS: source release', result['archive_sha256'], 'commit', result['source_commit'], 'dirty:', result['source_dirty'])
