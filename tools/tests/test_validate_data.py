"""Run with: python -m unittest discover -s tools/tests"""
import io
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import validate_data  # noqa: E402

HERE = Path(__file__).resolve().parent


def run(*args: str) -> tuple[int, str]:
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = validate_data.main(list(args))
    return code, buf.getvalue()


class ValidateDataTest(unittest.TestCase):
    def test_repository_content_is_valid(self) -> None:
        code, out = run()
        self.assertEqual(code, 0, out)

    def test_broken_mod_is_rejected(self) -> None:
        code, out = run(str(HERE / "fixtures" / "bad_mod"))
        self.assertEqual(code, 1)
        for expected in [
            "[mod_manifest] version",            # not semver
            "no schema mapped",                  # unknown_kind.json
            "s1:b is not connected",             # dangling end
            "speed_limits range 0..150 outside", # limit beyond segment
            "unknown segment 'nope'",            # platform reference
            "unknown vehicle 'ghost'",           # consist reference
        ]:
            self.assertIn(expected, out)


if __name__ == "__main__":
    unittest.main()
