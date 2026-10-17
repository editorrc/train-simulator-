#!/usr/bin/env bash
# Optional Linux asset build. End-user desktop builds include all generated WAVs.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
asset_dir="${TRAIN_ASSET_CACHE:-$repo_dir/build/audio-cache}"
mkdir -p "$asset_dir"
if [ ! -d "$asset_dir/opensfx/.git" ]; then
  git clone https://github.com/OpenTTD/OpenSFX.git "$asset_dir/opensfx"
fi
git -C "$asset_dir/opensfx" checkout --detach d0bf8d4deda22d5a7f8d01953433cb2644663e9f
if [ ! -d "$asset_dir/kenney-interface/.git" ]; then
  git clone https://github.com/Calinou/kenney-interface-sounds.git "$asset_dir/kenney-interface"
fi
git -C "$asset_dir/kenney-interface" checkout --detach 4596a49eaf5a533948d49a47467f606bcdea70ff
python3 -m venv "$asset_dir/loops-env"
"$asset_dir/loops-env/bin/pip" install numpy scipy
"$asset_dir/loops-env/bin/python" "$repo_dir/tools/prepare_audio_loops.py" "$asset_dir/opensfx" "$asset_dir/kenney-interface"

python3 -m venv "$asset_dir/tts-env"
"$asset_dir/tts-env/bin/pip" install torch==2.5.1+cpu --index-url https://download.pytorch.org/whl/cpu
"$asset_dir/tts-env/bin/pip" install espnet==202301 --no-deps
"$asset_dir/tts-env/bin/pip" install 'numpy<2' 'scipy<1.12' soundfile PyYAML kaldiio configargparse 'typeguard<3' humanfriendly torch_complex ci_sdr editdistance jamo inflect pypinyin==0.44 unidecode 'librosa==0.10.2.post1' packaging espnet-tts-frontend g2p-en six h5py 'importlib-metadata<5' opt-einsum pytorch-wpe sentencepiece 'protobuf<=3.20.1' Cython wheel setuptools
CXX=g++ CC=gcc "$asset_dir/tts-env/bin/pip" install --no-build-isolation pyworld
mkdir -p "$asset_dir/model"
for name in config.yaml model.pth spk_xvector.ark feats_stats.npz; do
  if [ ! -s "$asset_dir/model/$name" ]; then
    curl --fail --location --retry 3 --output "$asset_dir/model/$name" "https://github.com/robinhad/ukrainian-tts/releases/download/v6.0.0/$name"
  fi
done
"$asset_dir/tts-env/bin/python" "$repo_dir/tools/prepare_announcements.py" "$asset_dir/model"
"$asset_dir/tts-env/bin/python" "$repo_dir/tools/check_audio_assets.py"
