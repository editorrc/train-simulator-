"""Export self-contained desktop builds and create a real macOS DMG (native hdiutil by default)."""
from pathlib import Path
import argparse
import hashlib
import os
import platform
import shutil
import stat
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'game'

def run(*args,env=None):
    print('+',*map(str,args),flush=True)
    result=subprocess.run(list(map(str,args)),env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    print(result.stdout,flush=True)
    result.check_returncode()
    if 'SCRIPT ERROR:' in result.stdout or '\nERROR:' in result.stdout:
        raise RuntimeError('Tool reported an error; see output above')

def licenses(out):
    parts=[]
    for path in [ROOT/'LICENSE',ROOT/'game/audio/recordings/CREDITS.md',ROOT/'game/audio/recordings/LICENSE-OpenSFX.txt',ROOT/'game/audio/recordings/LICENSE-Kenney.txt',ROOT/'game/audio/announcements/CREDITS.md',ROOT/'game/audio/announcements/LICENSE-Ukrainian-TTS.txt',ROOT/'game/ui/fonts/CREDITS.md',ROOT/'game/ui/fonts/LICENSE-e-Ukraine.txt']:
        if path.exists():parts.append(path.name+'\n'+path.read_text())
    # Godot's official copyright inventory includes bundled third-party libraries.
    cache=ROOT/'build/licenses'
    cache.mkdir(parents=True,exist_ok=True)
    import urllib.request
    for name in ['LICENSE.txt','COPYRIGHT.txt']:
        path=cache/('GODOT-'+name)
        if not path.exists():urllib.request.urlretrieve('https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/'+name,path)
        parts.append(path.name+'\n'+path.read_text())
    target=out/'ARTEM-Licenses.txt'
    target.write_text('\n\n'.join(parts),encoding='utf-8')
    return target

def extract_app(archive,stage):
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            relative=Path(info.filename)
            if relative.is_absolute() or '..' in relative.parts:raise ValueError('Unsafe zip entry')
            target=stage/relative
            mode=info.external_attr>>16
            if info.is_dir():target.mkdir(parents=True,exist_ok=True)
            else:
                target.parent.mkdir(parents=True,exist_ok=True)
                if stat.S_ISLNK(mode):target.symlink_to(z.read(info).decode())
                else:
                    target.write_bytes(z.read(info))
                    target.chmod(0o755 if mode&0o111 else 0o644)
    app=next(stage.glob('*.app'))
    app.rename(stage/'ARTEM.app')
    for path in stage.rglob('*'):
        if path.is_dir():path.chmod(0o755)
    return stage/'ARTEM.app'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',default=os.environ.get('GODOT','godot'))
    parser.add_argument('--target',choices=['windows','macos','linux','all'],default='all')
    parser.add_argument('--out',type=Path,default=ROOT/'build/release')
    parser.add_argument('--xorriso',type=Path)
    parser.add_argument('--dmg-tool',type=Path)
    parser.add_argument('--xorriso-library-dir',type=Path)
    args=parser.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    run('python3',ROOT/'tools/prepare_fonts.py')
    license_file=licenses(out)
    run(args.godot,'--headless','--path',GAME,'--import')
    targets=['windows','macos'] if args.target=='all' else [args.target]
    for target in targets:
        if target=='windows':
            exe=out/'ARTEM-Windows.exe'
            run(args.godot,'--headless','--path',GAME,'--export-release','Windows Demo',exe)
            with zipfile.ZipFile(out/'ARTEM-Windows.zip','w',zipfile.ZIP_DEFLATED) as z:
                z.write(exe,'ARTEM.exe')
                z.write(license_file,license_file.name)
                z.write(ROOT/'docs/DEMO.md','README.md')
        elif target=='linux':
            binary=out/'ARTEM-Linux.x86_64'
            run(args.godot,'--headless','--path',GAME,'--export-release','Linux Demo',binary)
            binary.chmod(0o755)
        else:
            archive=out/'ARTEM-macOS.zip'
            run(args.godot,'--headless','--path',GAME,'--export-release','macOS Demo',archive)
            stage=out/'macos-stage'
            if stage.exists():shutil.rmtree(stage)
            stage.mkdir()
            app=extract_app(archive,stage)
            (stage/'Applications').symlink_to('/Applications',target_is_directory=True)
            shutil.copy2(license_file,stage/license_file.name)
            shutil.copy2(ROOT/'docs/DEMO.md',stage/'README.md')
            dmg=out/'ARTEM-macOS-universal.dmg'
            if platform.system()=='Darwin':
                run('codesign','--verify','--deep','--strict',app)
                run('hdiutil','create','-volname','ARTEM','-srcfolder',stage,'-ov','-format','UDZO',dmg)
                run('hdiutil','verify',dmg)
            elif args.xorriso and args.dmg_tool:
                raw=out/'macos-hfs.img'
                env=os.environ.copy()
                if args.xorriso_library_dir:env['LD_LIBRARY_PATH']=str(args.xorriso_library_dir)
                run(args.xorriso,'-as','mkisofs','-V','ARTEM','-R','-J','-hfsplus','-apm-block-size','512','-o',raw,stage,env=env)
                # zlib = UDZO like hdiutil; libdmg-hfsplus may default to bzip2.
                run(args.dmg_tool,'-c','zlib','dmg',raw,dmg)
            else:
                raise RuntimeError('DMG needs native macOS hdiutil, or explicitly supplied Linux HFS+ and UDIF tools')
    sums=[]
    for path in sorted(out.iterdir()):
        if path.is_file() and path.suffix in ['.exe','.zip','.dmg','.txt'] and path.name!='SHA256SUMS.txt':
            with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
            sums.append(digest+'  '+path.name)
    (out/'SHA256SUMS.txt').write_text('\n'.join(sums)+'\n')

if __name__=='__main__':main()
