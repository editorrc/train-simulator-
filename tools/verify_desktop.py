"""Structural validation of the Windows executable, universal Mac bundle, and Linux-built UDIF/HFS+ DMG.
This supplements, and does not replace, native codesign/hdiutil/runtime checks on macOS.
"""
from pathlib import Path
import argparse
import hashlib
import plistlib
import struct
import zlib


def mac_app(app):
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    executable=app/'Contents/MacOS'/info['CFBundleExecutable']
    data=executable.read_bytes()
    assert data[:4]==b'\xca\xfe\xba\xbe','Expected universal Mach-O'
    count=struct.unpack_from('>I',data,4)[0]
    arches=set()
    for i in range(count):
        cpu,sub,offset,size,align=struct.unpack_from('>IIIII',data,8+i*20)
        arches.add(cpu)
        thin=data[offset:offset+size]
        assert thin[:4]==b'\xcf\xfa\xed\xfe'
        commands=struct.unpack_from('<I',thin,16)[0]
        cursor=32;signature=None
        for _ in range(commands):
            cmd,length=struct.unpack_from('<II',thin,cursor)
            if cmd==0x1d:
                at,n=struct.unpack_from('<II',thin,cursor+8)
                signature=thin[at:at+n]
            cursor+=length
        assert signature and signature[:4]==b'\xfa\xde\x0c\xc0','Missing signature'
        entries=struct.unpack_from('>I',signature,8)[0]
        checked=False
        for j in range(entries):
            kind,at=struct.unpack_from('>II',signature,12+j*8)
            if kind==0:
                assert signature[at:at+4]==b'\xfa\xde\x0c\x02'
                flags=struct.unpack_from('>I',signature,at+12)[0]
                assert flags&2,'Expected ad-hoc signature'
                checked=True
        assert checked
    assert arches=={0x1000007,0x100000c},arches
    assert (app/'Contents/_CodeSignature/CodeResources').exists()
    assert list((app/'Contents/Resources').glob('*.pck'))
    print('Universal Mach-O: x86_64 + arm64, ad-hoc code directories, app resources present')
    return hashlib.sha256(data).hexdigest()


def dmg_roundtrip(dmg,raw,hfs_out):
    data=dmg.read_bytes()
    footer=data[-512:]
    assert footer[:4]==b'koly','Not UDIF'
    xml_at,xml_n=struct.unpack_from('>QQ',footer,216)
    plist=plistlib.loads(data[xml_at:xml_at+xml_n])
    sectors=struct.unpack_from('>Q',footer,492)[0]
    restored=bytearray(sectors*512)
    hfs_region=None
    for table in plist['resource-fork']['blkx']:
        block=table['Data'];assert block[:4]==b'mish'
        first,count,data_start=struct.unpack_from('>QQQ',block,8)
        runs=struct.unpack_from('>I',block,200)[0]
        crc=0
        for i in range(runs):
            kind,reserved,start,n,at,length=struct.unpack_from('>IIQQQQ',block,204+40*i)
            if kind in [0xffffffff,0x7ffffffe]:continue
            payload=data[data_start+at:data_start+at+length]
            if kind in [0,2]:decoded=bytes(n*512)
            elif kind==1:decoded=payload
            elif kind==0x80000005:decoded=zlib.decompress(payload)
            else:raise ValueError(f'Unsupported block {kind:x}')
            assert len(decoded)==n*512
            restored[(first+start)*512:(first+start+n)*512]=decoded
            crc=zlib.crc32(decoded,crc)
        checksum,bits,expected=struct.unpack_from('>III',block,64)
        if checksum==2 and bits==32:assert crc==expected,'Block CRC mismatch'
        if 'Apple_HFS' in table['Name']:hfs_region=(first*512,(first+count)*512)
    fork_at,fork_n=struct.unpack_from('>QQ',footer,24)
    kind,bits,expected=struct.unpack_from('>III',footer,80)
    if kind==2 and bits==32:assert zlib.crc32(data[fork_at:fork_at+fork_n])==expected
    assert hfs_region,'Missing HFS+ volume'
    a,b=hfs_region
    original=raw.read_bytes()
    assert restored[a:b]==original[a:b],'HFS+ decompression differs from source volume'
    assert restored[a+1024:a+1026] in [b'H+',b'HX'],'Invalid HFS+ header'
    hfs_out.write_bytes(restored[a:b])
    print('UDIF tables/CRC verified; decompressed HFS+ volume matches source byte-for-byte')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('release',type=Path)
    parser.add_argument('--hfs-out',type=Path)
    args=parser.parse_args()
    out=args.release
    exe=(out/'ARTEM-Windows.exe').read_bytes()
    assert exe[:2]==b'MZ'
    pe=struct.unpack_from('<I',exe,0x3c)[0]
    assert exe[pe:pe+4]==b'PE\0\0'
    assert struct.unpack_from('<H',exe,pe+4)[0]==0x8664
    assert exe[-4:]==b'GDPC','Missing embedded PCK'
    print('Windows GUI PE x86_64 with embedded PCK:',len(exe),'bytes')
    digest=mac_app(out/'macos-stage/ARTEM.app')
    print('Mac executable SHA256:',digest)
    if args.hfs_out:dmg_roundtrip(out/'ARTEM-macOS-universal.dmg',out/'macos-hfs.img',args.hfs_out)

if __name__=='__main__':main()
