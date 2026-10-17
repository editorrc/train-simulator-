# Train Simulator demo 0.3.1

Ready-to-run desktop downloads. Source commit: [ce6ab07dfbb2e69a60f42ad63e7d3a173e42edc2](https://github.com/editorrc/train-simulator-/tree/ce6ab07dfbb2e69a60f42ad63e7d3a173e42edc2).

- Windows: [ZIP containing the standalone EXE](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/TrainSimulator-Windows.zip). Extract and run TrainSimulator.exe.
- macOS: [universal DMG](https://raw.githubusercontent.com/editorrc/train-simulator-/demo-downloads/TrainSimulator-macOS-universal.dmg). Open and drag TrainSimulator.app to Applications.
- [SHA256SUMS.txt](SHA256SUMS.txt), [licenses](TrainSimulator-Licenses.txt).

The application includes the engine, all sounds and offline Ukrainian station announcements.
No Python, Godot installation, browser, or Windows environment is required to launch it.

F2: view; wheel: zoom; F3: settings; F4: desk; F5: map; I: announcer;
Space/V: horn/whistle; Z/C: doors; W/S: controller; Q/E: brake; R: reverser.

Local validation: 83 Godot tests, 2 Python tests, 801 parity samples, native Linux graphical
and audio checks, PE/universal Mach-O signature structure, complete DMG/HFS+ round-trip.
Windows/macOS runtime checks could not run: GitHub Actions reports the account is locked
because of a billing issue. These are cross-exported interim builds.

macOS uses an ad-hoc signature, without Apple Developer ID/notarization. First launch may
need System Settings → Privacy & Security → Open Anyway. Do not disable system protection.
The model/route geometry are illustrative; station names/order are sourced. Announcements
are synthesized with Ukrainian TTS, not original railway operator recordings.

These release packages are held on a separate downloads branch because this repository's
LFS budget is exhausted and hosted Actions cannot run. See the source branch's desktop
release workflow for native build and GitHub Releases publishing when Actions is available.
