Audio sources for demo 0.3.3. These are illustrative licensed effects, not verified
field recordings of the specific ER9M equipment.

OpenSFX: https://github.com/OpenTTD/OpenSFX (LICENSE-OpenSFX.txt):

- rolling_loop, wheel_clack_0..3, clack: osfx_71, "Train passby (tape stop).wav", Metzik; edited Wuzzy. CC BY 3.0.
- motor_loop: osfx_65, "metro.wav", Marec; edits/mixing Janis Lukss. CC BY 3.0.
- compressor_loop: osfx_11, "L'ascenseur - Elevator", Aldor; edits Janis Lukss. Public-domain original, edited recording CC BY 3.0.
- hiss_loop: osfx_13, "Steam (of steam engine)", Janis Lukss. CC BY 3.0.
- horn_sustain: osfx_10, "Locomotive 1 Distant horn.wav", patchen; edits Janis Lukss. CC BY 3.0.
- whistle_sustain: osfx_03, "Factory Whistle", Janis Lukss. CC BY 3.0.
- door_latch: osfx_16, "Dumpster_Diving.wav", 1sticky8; edits Wuzzy. CC0.

https://creativecommons.org/licenses/by/3.0/
https://creativecommons.org/publicdomain/zero/1.0/

Kenney Interface Sounds 1.0 (CC0), https://kenney.nl/assets/interface-sounds,
mirror https://github.com/Calinou/kenney-interface-sounds (LICENSE-Kenney.txt):

- switch_click / switch_on: switch_002.wav
- switch_off: switch_003.wav
- controller_notch: switch_005.wav
- lever_latch: switch_006.wav
- button_click: click_003.wav

Processing in tools/prepare_audio_loops.py: mono PCM16 22050 Hz resampling,
normalization and trimming. Train beds use circular overlap-add (24s/12s).
Rail impacts preserve four distinct recorded transients and their natural attack/ring,
with short tail fades. A sample-timed mixer uses vehicle axle geometry and track joints;
impact pitch remains fixed. Switches retain short dry attacks. Source commits are pinned
in tools/prepare_demo_audio.sh. No TTS or audio-generation dependencies run in the app.

0.3.3: Godot imports these generated recordings as uncompressed PCM16. Loop boundaries
count decoded sample frames, not compressed payload bytes. Held signals retain a continuous
sustain with a separate attack/release envelope; source attribution is unchanged.
