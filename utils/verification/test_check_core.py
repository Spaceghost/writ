"""Negative controls for the development output gate, not Bend test counts."""

import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from check_core import check_output, read_count, SUCCESS


class OutputChecks(unittest.TestCase):
    def test_both_existing_pass_forms_and_crlf(self):
        self.assertEqual(check_output(io.StringIO(f"Suite\r\nPASS: one\r\nPASS two\r\n{SUCCESS}\r\n"), 2), 2)

    def test_failures_and_incomplete_runs_are_rejected(self):
        for output in ["", "PASS: one\n", f"{SUCCESS}\n", f"PASS: one\nFAIL: two\n{SUCCESS}\n",
                       f"PASS: one\n{SUCCESS}\ntrailing error\n", f"PASS: one\n{SUCCESS}\n\n",
                       f"PASS: one\n{SUCCESS}\nPASS: two\n{SUCCESS}\n",
                       f"PASSENGER\n{SUCCESS}\n", f"PASS: one\nPASS: extra\n{SUCCESS}\n"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                check_output(io.StringIO(output), 1)

    def test_count_file_rejects_malformed_or_unbounded_values(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "count.txt"
            for raw in [b"", b"0\n", b"-1\n", b"01\n", b" 1\n", b"1", b"1\r\n", b"1\n2\n",
                        b"1.0\n", b"100000\n", b"1e3\n", b"true\n", b"\xff\n"]:
                path.write_bytes(raw)
                with self.subTest(raw=raw), self.assertRaises(ValueError):
                    read_count(path)
            path.write_bytes(b"3072\n")
            self.assertEqual(read_count(path), 3072)

    def test_cli_exits_unsuccessfully_on_bad_or_missing_output(self):
        script = Path(__file__).with_name("check_core.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            count, log = root / "count", root / "log"
            count.write_text("1\n")
            command = [sys.executable, str(script), "--count-file", str(count)]
            for output in [f"PASS: one\n{SUCCESS}\n", "PASS: one\n", f"FAIL: one\n{SUCCESS}\n"]:
                log.write_text(output)
                result = subprocess.run(command + [str(log)], capture_output=True)
                self.assertEqual(result.returncode, 0 if output.startswith("PASS") and SUCCESS in output else 1)
            self.assertEqual(subprocess.run(command + [str(root / "missing")], capture_output=True).returncode, 1)
            count.write_text("0\n")
            self.assertEqual(subprocess.run(command + ["--print-count"], capture_output=True).returncode, 1)


if __name__ == "__main__":
    unittest.main()
