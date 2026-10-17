"""Offline preparation of OpenSFX recordings (numpy/scipy). No audio synthesis at runtime.
Usage: python tools/prepare_audio_loops.py /path/to/OpenSFX /path/to/kenney-interface-sounds
"""
from pathlib import Path
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly, butter, sosfilt, find_peaks
from scipy.ndimage import uniform_filter1d
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
    save('rolling_loop',loop(rolling,24,.85))
    save('motor_loop',loop(motor,12,.8))
    save('compressor_loop',loop(source(root,11),3,.3))
    save('hiss_loop',loop(source(root,13),2,.25))
    save('horn_sustain',sustain(source(root,10),.25,1.25))
    save('whistle_sustain',sustain(source(root,3),.2,.9))
    # Keep the natural attack/ring of distinct recorded rail impacts; no short rhythm loop.
    high=sosfilt(butter(2,[140,7500],fs=RATE,btype='bandpass',output='sos'),rolling)
    energy=uniform_filter1d(high*high,size=round(.004*RATE))
    peaks,_=find_peaks(energy,distance=round(.12*RATE))
    peaks=sorted(peaks,key=lambda i:energy[i],reverse=True)
    if not peaks:raise ValueError('No impact transients in the source')
    for index in range(4):
        peak=peaks[index%len(peaks)]
        start=max(0,peak-round(.007*RATE))
        chunk=high[start:start+round(.16*RATE)].copy()
        fade=min(len(chunk)//3,round(.035*RATE))
        chunk[-fade:]*=np.linspace(1,0,fade)**2
        chunk[:min(12,len(chunk))]*=np.linspace(0,1,min(12,len(chunk)))
        save('wheel_clack_'+str(index),chunk)
    save('clack',high[:round(.15*RATE)])
    kenney=Path(sys.argv[2])/'addons/kenney_interface_sounds'
    for name,original in [('switch_click','switch_002'),('switch_on','switch_002'),('switch_off','switch_003'),('controller_notch','switch_005'),('lever_latch','switch_006'),('button_click','click_003')]:
        rate,raw=wavfile.read(kenney/(original+'.wav'))
        if raw.ndim>1:raw=raw.mean(axis=1)
        if np.issubdtype(raw.dtype,np.integer):raw=raw.astype(np.float64)/max(abs(np.iinfo(raw.dtype).min),np.iinfo(raw.dtype).max)
        common=gcd(rate,RATE)
        raw=resample_poly(raw,RATE//common,rate//common)
        # Preserve the dry attack. Remove only leading/trailing near-silence.
        active=np.flatnonzero(np.abs(raw)>np.max(np.abs(raw))*.015)
        if len(active):raw=raw[max(0,active[0]-20):min(len(raw),active[-1]+100)]
        save(name,raw)
    (OUT/'LICENSE-Kenney.txt').write_bytes((kenney/'LICENSE.txt').read_bytes())
    mech=source(root,16)
    chunk=mech[int(.1*RATE):int(.38*RATE)].copy()*np.hanning(int(.38*RATE)-int(.1*RATE))
    save('door_latch',chunk)
    (OUT/'LICENSE-OpenSFX.txt').write_bytes((root/'LICENSE').read_bytes())
    print('Prepared continuous recorded loops, signal sustains and mechanical effects')

if __name__=='__main__':main(Path(sys.argv[1]))
