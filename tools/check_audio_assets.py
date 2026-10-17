"""Fail a release before export if generated recordings or station phrases are missing/corrupt."""
from pathlib import Path
import json
import wave

ROOT=Path(__file__).resolve().parents[1]
REC=ROOT/'game/audio/recordings'
ANN=ROOT/'game/audio/announcements'
names=['rolling_loop','motor_loop','compressor_loop','hiss_loop','horn_sustain','whistle_sustain','clack','wheel_clack_0','wheel_clack_1','wheel_clack_2','wheel_clack_3','switch_on','switch_off','switch_click','controller_notch','lever_latch','button_click','door_latch']
paths=[REC/(name+'.wav') for name in names]
stations=json.loads((ROOT/'game/content/base/routes/kyiv_city_ring/stations.json').read_text())['stations']
paths.extend(ANN/(station['id']+'_'+kind+'.wav') for station in stations for kind in ['station','next'])
paths.append(ANN/'doors_closing.wav')
for path in paths:
    with wave.open(str(path),'rb') as wav:
        assert wav.getnchannels()==1 and wav.getsampwidth()==2 and wav.getframerate()==22050,path
        assert wav.getnframes()>100,path
print(f'{len(paths)} valid offline PCM16 audio assets')
