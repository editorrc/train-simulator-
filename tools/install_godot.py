"""Download the pinned official editor/templates, checking every archive against SHA512-SUMS."""
from pathlib import Path
import hashlib
import os
import platform
import sys
import urllib.request
import zipfile

VERSION='4.7.2'
BASE=f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable'
CACHE=Path(os.environ.get('TRAIN_BUILD_CACHE',Path(__file__).resolve().parents[1]/'build/toolchain'))

def fetch(name):
    CACHE.mkdir(parents=True,exist_ok=True)
    path=CACHE/name
    if not path.exists():urllib.request.urlretrieve(BASE+'/'+name,path)
    return path

def verified(name):
    sums=fetch('SHA512-SUMS.txt').read_text()
    expected=[line.split()[0] for line in sums.splitlines() if line.split()[-1]==name]
    assert len(expected)==1, f'No unique checksum for {name}'
    path=fetch(name)
    with path.open('rb') as f: actual=hashlib.file_digest(f,'sha512').hexdigest()
    assert actual==expected[0], f'SHA512 mismatch: {path}'
    return path

def main():
    system=platform.system()
    suffix={'Linux':'linux.x86_64','Darwin':'macos.universal','Windows':'win64.exe'}[system]
    name=f'Godot_v{VERSION}-stable_{suffix}.zip'
    target=CACHE/'editor'
    target.mkdir(exist_ok=True)
    with zipfile.ZipFile(verified(name)) as archive:
        archive.extractall(target)
    if system=='Darwin':
        executable=target/'Godot.app/Contents/MacOS/Godot'
        template_root=Path.home()/'Library/Application Support/Godot/export_templates'
    elif system=='Windows':
        executable=next(target.glob('Godot_v*.exe'))
        template_root=Path(os.environ['APPDATA'])/'Godot/export_templates'
    else:
        executable=target/f'Godot_v{VERSION}-stable_linux.x86_64'
        template_root=Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'godot/export_templates'
    executable.chmod(0o755)
    if '--templates' in sys.argv:
        out=template_root/f'{VERSION}.stable'
        out.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(verified(f'Godot_v{VERSION}-stable_export_templates.tpz')) as archive:
            for name in ['windows_release_x86_64.exe','linux_release.x86_64','macos.zip']:
                (out/name).write_bytes(archive.read('templates/'+name))
    print(executable.resolve())

if __name__=='__main__':main()
