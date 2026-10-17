"""Fetch pinned CC BY 4.0 e-Ukraine fonts without committing binaries outside LFS."""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def main():
    sources = json.loads((ROOT / 'tools/font_sources.json').read_text())
    target = ROOT / 'game/ui/fonts'
    target.mkdir(parents=True, exist_ok=True)
    for name, expected in sources['sha256'].items():
        path = target / name
        if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == expected:
            print('Verified', name)
            continue
        with urllib.request.urlopen(sources['base_url'] + name, timeout=40) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError('Font checksum mismatch: ' + name)
        path.write_bytes(data)
        print('Downloaded and verified', name)


if __name__ == '__main__':
    main()
