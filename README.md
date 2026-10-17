# Train Simulator demo 0.3.3

Source: [demo-v0.3.3](https://github.com/editorrc/train-simulator-/tree/demo-v0.3.3).

- [Windows ZIP with standalone EXE](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/TrainSimulator-Windows.zip). Extract, run TrainSimulator.exe.
- [macOS universal DMG](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/TrainSimulator-macOS-universal.dmg). Open, drag app to Applications.
- [SHA256SUMS.txt](SHA256SUMS.txt), [licenses](TrainSimulator-Licenses.txt).

0.3.3 fixes compressed-byte loop lengths: held horn/whistle sustain continuously,
recorded effects are PCM16, and the axle mixer avoids per-sample dictionary work.
Grade/curve resistance is integrated along every vehicle instead of sampling its centre.
Rigid parts are merged and wheelsets instanced, with screen-size LOD. Cab side windows,
grab rails and a folding pantograph follow the model/electrical state.

Window starts maximized, manual size is remembered, and 100% 3D matches the actual image
including Retina, rather than the stretched logical texture dimensions. MSAA 0/2/4x.
The origin camera is hidden before first pose. F8 returns to the platform side.
A second illustrative track/platform is visible; it is not yet a routed opposite line.
Models/platform layouts are illustrative, not surveyed IRL station reconstructions.

F2 views; RMB drag orbit (Mac alternative: Control + left drag); Shift + RMB pan;
wheel zoom; F3 graphics/audio/window settings; F4 desk; F5 map; F8 platform view;
I announcements; Space/V horn/whistle; Z/C doors; W/S controller; Q/E brakes;
R reverser while stopped; P pause.

101 Godot tests, 2 Python tests, 801 updated physics parity samples passed.
Linux graphical/camera/window/audio QA passed; recorded held signals exceed 3 seconds
without gaps, and the PCM worker had 0 underruns under artificial 350ms frame stalls.
Universal Mach-O signatures and full UDIF/HFS+ round-trip are checked.
The user confirmed native Windows/macOS launch of 0.3.2. New 0.3.3 packages were checked
in Linux; automated native Actions remains blocked by GitHub account billing.
macOS uses ad-hoc signing without Apple Developer ID/notarization; first launch may
require Privacy & Security → Open Anyway. No installed Godot/Python or browser needed.

Compiled packages are hosted on this downloads branch because Git LFS quota is
exhausted and Actions cannot publish release assets while the account is locked.
