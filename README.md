# Train Simulator demo 0.3.2

Source: [demo-v0.3.2](https://github.com/editorrc/train-simulator-/tree/demo-v0.3.2).

- [Windows ZIP with standalone EXE](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/TrainSimulator-Windows.zip). Extract, run TrainSimulator.exe.
- [macOS universal DMG](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/TrainSimulator-macOS-universal.dmg). Open, drag app to Applications.
- [SHA256SUMS.txt](SHA256SUMS.txt), [licenses](TrainSimulator-Licenses.txt).

0.3.2: car bodies supported by two independently steered bogies, coupled poses and
mass-dependent suspension; curved platform edges; longer audio beds, sample-timed
individual axle impacts in an independent PCM worker, dry Kenney switch clicks;
RMB/Control-click camera orbit, trackpad gestures, native HiDPI/MSAA and render scale.
Cab view follows the physical active cab, with free look. Models have rounded roofs
and wheel flange/hub profiles. Infrastructure/models remain illustrative, not a full
multibody wheel/rail dynamics model or a factory CAD reconstruction.

F2 views; RMB drag orbit (Mac alternative: Control + left drag); Shift + RMB pan;
wheel zoom; F3 graphics/audio/window resolution; F4 desk; F5 map; I announcements;
Space/V horn/whistle; Z/C doors; W/S controller; Q/E brakes; R reverser; P pause.

90 Godot tests, 2 Python tests, 801 parity samples passed. Graphical/input/audio QA
was run on Linux; the PCM worker had 0 underruns under artificial 350ms main-thread
stalls. Universal Mach-O signatures and full UDIF/HFS+ round-trip are checked.
Native Windows/macOS runtime is not confirmed; hosted Actions was blocked by billing.
macOS uses ad-hoc signing without Apple Developer ID/notarization; first launch may
require Privacy & Security → Open Anyway. No installed Godot/Python or browser needed.

Compiled packages are hosted on this downloads branch because Git LFS quota is
exhausted and Actions cannot publish release assets while the account is locked.
