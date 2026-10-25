# ARTEM · Train Emulator · demo 0.3.5

Source: [codex/desktop-demo @ 31a4150](https://github.com/editorrc/train-simulator-/tree/31a4150001232fe4741c500be3899ba0a7543319).

- [Windows ZIP with standalone EXE](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/ARTEM-Windows.zip). Extract, run ARTEM.exe.
- [macOS universal DMG](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/ARTEM-macOS-universal.dmg). Open, drag ARTEM.app to Applications.
- [SHA256SUMS.txt](SHA256SUMS.txt), [licenses](ARTEM-Licenses.txt).

0.3.5: in-trip interface in the Panorama style — one graphite band on top with the next
station and distance, speed with the limit sign (red when exceeded), controller / brake
valve / reverser positions, clock and text navigation; panels as tidy cards; announcer
subtitles in a pill under the header. ЕПЛ9Т: three vestibules per side, two
Ukrzaliznytsia liveries after photos of the related ЕПЛ2Т (cream-blue, cherry-cream)
and a new front after those photos — mask around one wide windscreen, route boards,
lamps, coloured pilot (no «УЗ» emblem yet: a neutral pad; dimensions are estimates from
photos). Kyiv ring: 2024 names — Вокзальна (was Київ-Пасажирський) and Райдужний (was
Троєщина-2), announcer voice updated. Fixed: the waist stripe was hidden under the lower
paint on two-tone liveries; sound stops before leaving a trip.

Known issue: on Intel Macs (native OpenGL 4.1, e.g. Iris Plus) the train in the menu
preview looks dark and matte — the front gets almost no light and there are no
reflections. The same code is lit on other renderers; the fix is the next slice.

109 Godot tests, 7 Python tests, 801 physics parity samples, and audio/camera/desktop/
navigation/window/lifecycle regressions passed in Linux (Xvfb + llvmpipe). Universal
Mach-O (x86_64 + arm64) ad-hoc signatures and full UDIF/HFS+ round-trip checked.
macOS has no Developer ID/notarization: first launch may need Privacy & Security →
Open Anyway. Native Windows/macOS runs of 0.3.5 are not yet confirmed.

Compiled packages live on this downloads branch because Git LFS quota is exhausted and
Actions cannot publish release assets while the account is locked.
