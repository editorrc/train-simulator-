"""Optional offline asset generator; requires Ukrainian TTS v6 model and a separate ESPnet environment.
Usage: python tools/prepare_announcements.py /path/to/v6-model-files
No inference model or Python dependency is shipped with the game.
"""
from pathlib import Path
import hashlib,sys
import yaml
import numpy as np
import soundfile as sf
import torch
from kaldiio import load_ark
from espnet2.bin.tts_inference import Text2Speech

base=Path(sys.argv[1]).resolve()
assert hashlib.sha256((base/'model.pth').read_bytes()).hexdigest()=='0662f619195cebb4db265194528ed79d14a63f19e5163d4cf4866a4be7e13d31'
config=yaml.safe_load((base/'config.yaml').read_text())
config['normalize_conf']['stats_file']=str(base/'feats_stats.npz')
config['g2p']=None
(base/'config-local.yaml').write_text(yaml.safe_dump(config))
torch.set_num_threads(2)
original_load=torch.load
def safe_load(*args,**kwargs):
 kwargs['weights_only']=True
 return original_load(*args,**kwargs)
torch.load=safe_load
model=Text2Speech(train_config=str(base/'config-local.yaml'),model_file=str(base/'model.pth'),device='cpu')
voice={k:v for k,v in load_ark(str(base/'spk_xvector.ark'))}['tetiana'][0]
names=[('sviatoshyn','свят+ошин'),('borshchahivka','борщаг+івка'),('kyiv_volynskyi','к+иїв-вол+инський'),('karavaievi_dachi','карав+аєві д+ачі'),('kyiv_pasazhyrskyi','вокз+альна'),('protasiv_yar','прот+асів яр'),('kyiv_demiiivskyi','к+иїв-дем+іївський'),('vydubychi','в+идубичі'),('berezniaky','березняк+и'),('darnytsia','д+арниця'),('rusanivka','рус+анівка'),('livoberezhna','лівобер+ежна'),('mykilska_slobidka','мик+ільська слоб+ідка'),('voskresenka','воскрес+енка'),('troieshchyna_2','р+айдужний'),('pochaina','поч+айна'),('kurenivka','курен+івка'),('priorka','пр+іорка'),('syrets','сир+ець'),('beresteiska','берест+ейська')]
phrases=[(sid+'_station','ст+анція '+name+'.') for sid,name in names]+[(sid+'_next','наст+упна ст+анція '+name+'.') for sid,name in names]+[('doors_closing','обер+ежно! дв+ері зачин+яються.')]
out=Path(__file__).resolve().parents[1]/'game/audio/announcements';out.mkdir(parents=True,exist_ok=True)
for sid,text in phrases:
 if (out/(sid+'.wav')).exists():continue
 with torch.no_grad():data=model(text,spembs=voice)['wav'].cpu().numpy().reshape(-1)
 data=data/max(np.max(np.abs(data)),1e-6)*.75
 data=np.concatenate([np.zeros(2205),data,np.zeros(4410)])
 sf.write(out/(sid+'.wav'),data,22050,subtype='PCM_16')
 print(sid,len(data)/22050,flush=True)
