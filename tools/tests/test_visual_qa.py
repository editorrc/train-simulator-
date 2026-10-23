"""A PASS marker must not hide a failed engine or its shutdown diagnostics."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "run_visual_qa.sh"


class VisualQaRunnerTests(unittest.TestCase):
    def run_runner(self, engine_body: str) -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as tmp:
            engine = Path(tmp) / "godot"
            engine.write_text("#!/usr/bin/env bash\n" + engine_body)
            engine.chmod(0o755)
            env = dict(os.environ, GODOT=str(engine), DISPLAY=":test")
            return subprocess.run(
                ["bash", str(RUNNER), "lifecycle"], env=env,
                capture_output=True, text=True, check=False,
            )

    def test_accepts_successful_engine(self):
        result = self.run_runner('echo "LIFECYCLE_QA PASS []"\n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_nonzero_exit_after_pass(self):
        result = self.run_runner(
            '[[ "$*" == *--import* ]] && exit 0\n'
            'echo "LIFECYCLE_QA PASS []"\nexit 7\n'
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exit=7", result.stdout)

    def test_rejects_shutdown_diagnostics_after_pass(self):
        for diagnostic in (
            "WARNING: ObjectDB instances leaked at exit",
            "WARNING: 10 ObjectDB instances were leaked at exit",
            "ERROR: 2 resources still in use at exit",
            "ERROR: 1 RID allocations of type 'Mesh' were leaked at exit",
            "SCRIPT ERROR: Invalid call",
        ):
            with self.subTest(diagnostic=diagnostic):
                result = self.run_runner(
                    f'echo "LIFECYCLE_QA PASS []"\necho "{diagnostic}" >&2\n'
                )
                self.assertNotEqual(result.returncode, 0, diagnostic)

    def test_rejects_missing_or_failed_verdict(self):
        for verdict in ("", "LIFECYCLE_QA FAIL []"):
            with self.subTest(verdict=verdict):
                self.assertNotEqual(
                    self.run_runner(f'echo "{verdict}"\n').returncode, 0
                )

    def test_stops_after_import_failure(self):
        result = self.run_runner('echo "LIFECYCLE_QA PASS []"\nexit 9\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Godot import failed", result.stderr)
        self.assertNotIn("lifecycle:", result.stdout)
