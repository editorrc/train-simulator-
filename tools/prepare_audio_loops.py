"""Offline preparation of OpenSFX recordings (numpy/scipy). No audio synthesis at runtime.
Usage: python tools/prepare_audio_loops.py /path/to/OpenSFX
"""
from pathlib import Path
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly, butter, sosfilt
from math import gcd

RATE=22050
OUT=Path(__file__).resolve().parents[1]/'game/audio/recordings'

def source(root, number):
    rate,data=wavfile.read(root/f'src/wav/osfx_{number:02d}.wav')
    info=np.iinfo(data.dtype)
    data=(data.astype(np.float64)-(128 if data.dtype==np.uint8 else 0))/max(abs(info.min),info.max)
    if data.ndim>1:data=data.mean(axis=1)
    common=gcd(rate,RATE)
    return resample_poly(data,RATE//common,rate//common)

def save(name,data):
    data=data-data.mean()
    data=data/max(np.max(np.abs(data)),1e-8)*.72
    wavfile.write(OUT/(name+'.wav'),RATE,(data*32767).astype(np.int16))

def loop(data,seconds,grain=.22):
    # Circular overlap-add: no silent seam, deterministic playback; audio thread sets rhythm.
    n=int(seconds*RATE); width=int(grain*RATE); step=width//2
    result=np.zeros(n);weight=np.zeros(n)
    window=np.hanning(width);rng=np.random.default_rng(1520)
    for at in range(0,n,step):
        start=int(rng.integers(0,max(1,len(data)-width)))
        sample=np.resize(data[start:start+width],width)
        indices=(np.arange(width)+at)%n
        result[indices]+=sample*window;weight[indices]+=window
    return result/np.maximum(weight,1e-8)

def sustain(data,start,end):
    sample=data[int(start*RATE):int(end*RATE)].copy()
    if len(sample)<100:raise ValueError('Invalid source interval')
    n=min(int(.06*RATE),len(sample)//4)
    fade=np.linspace(0,1,n)
    sample[:n]=sample[-n:]*(1-fade)+sample[:n]*fade
    return sample[:-n]

def main(root):
    OUT.mkdir(parents=True,exist_ok=True)
    rolling=source(root,71);motor=source(root,65)
    save('rolling_loop',loop(rolling,4,.28))
    save('motor_loop',loop(motor,2,.6))
    save('compressor_loop',loop(source(root,11),3,.3))
    save('hiss_loop',loop(source(root,13),2,.25))
    save('horn_sustain',sustain(source(root,10),.25,1.25))
    save('whistle_sustain',sustain(source(root,3),.2,.9))
    # A percussive excerpt of the recorded train pass-by, filtered to remove rumble.
    high=sosfilt(butter(2,700,fs=RATE,btype='highpass',output='sos'),rolling)
    peak=int(np.argmax(np.abs(high)))
    clack=np.resize(high[max(0,peak-100):max(0,peak-100)+int(.10*RATE)],int(.10*RATE))
    clack*=np.exp(-np.arange(len(clack))/(.025*RATE))
    save('clack',clack)
    # 25m rail joints, 15m/s reference; axle spacings from the demo vehicle data.
    for count in [4,6,10]:
        cycle=np.zeros(round(25/15*RATE))
        for car in range(count):
            for axle in [2.2,4.8,17.2,19.8]:
                at=round(((car*20+axle)%25)/15*RATE)
                indices=(at+np.arange(len(clack)))%len(cycle)
                cycle[indices]+=clack*(.75**car)
        save('wheel_rhythm_'+str(count),cycle)
    # Mechanical excerpts: CC0 original dumpster latch, with different trim lengths.
    mech=source(root,16)
    for name,start,length in [('switch_click',.05,.09),('controller_notch',.18,.12),('lever_latch',.3,.18),('button_click',.4,.07),('door_latch',.1,.28)]:
        chunk=mech[int(start*RATE):int((start+length)*RATE)].copy()
        chunk*=np.hanning(len(chunk));save(name,chunk)
    (OUT/'LICENSE-OpenSFX.txt').write_bytes((root/'LICENSE').read_bytes())
    print('Prepared continuous recorded loops, signal sustains and mechanical effects')

if __name__=='__main__':main(Path(sys.argv[1]))
