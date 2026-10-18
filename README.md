# ARTEM · Train Emulator · demo 0.3.4

Source: [codex/desktop-demo @ a9ee1d7](https://github.com/editorrc/train-simulator-/tree/a9ee1d700f3eca5782b334553bdf90ca5ae66c12).

- [Windows ZIP with standalone EXE](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/ARTEM-Windows.zip). Extract, run ARTEM.exe.
- [macOS universal DMG](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/ARTEM-macOS-universal.dmg). Open, drag ARTEM.app to Applications.
- [SHA256SUMS.txt](SHA256SUMS.txt), [licenses](ARTEM-Licenses.txt).

0.3.4: series selector — ЕР9М, ЕД9М, ЕПЛ9Т and ЕКр1 «Тарпан», each with its own
formations, traction, controller and speedometer scales and six liveries (new series
parameters are estimates, not yet checked against documentation). Route scenery is
streamed around the train instead of built at once (startup ~2x faster, 4x fewer scene
nodes); desk, map and charts redraw only when their readings change (~3x fewer draw
calls at standstill). Held horn/whistle: the attack plays once, then a level-flattened,
phase-matched sustain loop, so holding no longer sounds like the signal restarting.

106 Godot tests, 2 Python tests, 801 physics parity samples, audio/camera/desktop/
navigation/window regressions passed in Linux (Xvfb + llvmpipe; not a native FPS figure).
Universal Mach-O (x86_64 + arm64) ad-hoc signatures and full UDIF/HFS+ round-trip checked.
macOS has no Developer ID/notarization: first launch may need Privacy & Security →
Open Anyway. Native Windows/macOS runs of 0.3.4 are not yet confirmed.

Compiled packages live on this downloads branch because Git LFS quota is exhausted and
Actions cannot publish release assets while the account is locked.
