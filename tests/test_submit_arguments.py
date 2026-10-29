"""Run panda submit and its generated Bash jobs without Slurm or network access.

Run with: python3 -m unittest discover -s tests -v
The Julia executable is stubbed; Python, Bash, and executable dispatch run locally.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SubmitArgumentsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="panda-argv-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.repo = self.work / "panda"
        for directory in ("bin", "lib", "config"):
            shutil.copytree(ROOT / directory, self.repo / directory)
        self.home = self.work / "home"
        self.home.mkdir()
        self.tools = self.work / "tools"
        self.tools.mkdir()
        self.capture = self.work / "job.slurm"
        self.result = self.work / "argv.json"
        self.finish = self.work / "finish.txt"
        self.env = dict(os.environ, HOME=str(self.home), HOSTNAME="testnode",
                        PATH=f"{self.tools}:{os.environ['PATH']}",
                        CAPTURE=str(self.capture), ARGV_RESULT=str(self.result),
                        FINISH_RESULT=str(self.finish), SLURMD_NODENAME="testnode",
                        SLURM_JOB_ID="123", LC_ALL="C")
        # Do not inherit shell startup hooks from the test runner.
        self.env.pop("BASH_ENV", None)
        (self.home / ".panda.conf").write_text(
            f'PANDA_ROOT[testnode]="{self.repo}"\n'
            'PATH_MAP[testnode]=""\nREPO_MAP[testnode]=""\n'
        )
        self.write_tool("hostname", '#!/bin/bash\nprintf "testnode\\n"\n')
        self.write_tool("conda", "#!/bin/bash\nexit 0\n")
        self.write_tool("julia", '#!/bin/bash\nexec python3 "$@"\n')
        self.write_tool("python", '#!/bin/bash\nexec python3 "$@"\n')
        self.write_tool("sbatch", '''#!/usr/bin/env python3
import os, pathlib, shutil, sys
source = pathlib.Path(sys.argv[1])
shutil.copyfile(source, os.environ["CAPTURE"])
source.unlink()
print("Submitted batch job 123")
''')
        for name in ("ssh", "rsync"):
            self.write_tool(name, '#!/bin/bash\necho "Unexpected network call" >&2\nexit 88\n')
        # Record the job's completion callback independently of cluster history.
        finish = self.repo / "lib" / "finish.sh"
        finish.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$FINISH_RESULT"\n')
        self.programs = self.work / "programs with spaces"
        self.programs.mkdir()

    def write_tool(self, name, content):
        path = self.tools / name
        path.write_text(content)
        path.chmod(0o755)

    def program(self, kind="py", exitcode=0):
        path = self.programs / ("probe" if kind == "executable" else f"probe.{kind}")
        source = (
            "import json, os, pathlib, sys\n"
            'pathlib.Path(os.environ["ARGV_RESULT"]).write_text(json.dumps(sys.argv[1:]))\n'
            f"sys.exit({exitcode})\n"
        )
        if kind == "sh":
            path.write_text('#!/bin/bash\npython3 - "$@" <<\'PY\'\n' + source + "PY\n")
        else:
            path.write_text("#!/usr/bin/env python3\n" + source)
        path.chmod(0o755)
        return path

    def submit(self, path, args):
        return subprocess.run(
            [str(self.repo / "bin" / "panda"), "submit", str(path), *args],
            cwd=self.work, env=self.env, capture_output=True, text=True, timeout=5,
        )

    def assert_roundtrip(self, args, expected, kind="py", exitcode=0):
        result = self.submit(self.program(kind, exitcode), ["--node", "testnode", *args])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        batch = self.capture.read_text()
        self.assertEqual(batch.count("#SBATCH --job-name="), 1)
        subprocess.run(["bash", "-n", str(self.capture)], check=True, capture_output=True)
        result = subprocess.run(["bash", str(self.capture)], cwd=self.work, env=self.env,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, exitcode, result.stdout + result.stderr)
        self.assertEqual(json.loads(self.result.read_text()), expected)
        self.assertEqual(self.finish.read_text().splitlines()[1], str(exitcode))

    def test_omitted_arguments_for_every_dispatch(self):
        for kind in ("py", "sh", "jl", "executable"):
            with self.subTest(kind=kind):
                self.assert_roundtrip([], [], kind)

    def test_existing_station_syntax(self):
        self.assert_roundtrip(["--args", "ARIG", "--cpus", "2"], ["ARIG"])
        self.assertIn("#SBATCH --cpus-per-task=2", self.capture.read_text())

    def test_repeated_args_for_every_dispatch(self):
        for kind in ("py", "sh", "jl", "executable"):
            with self.subTest(kind=kind):
                self.assert_roundtrip(["--args", "ARIG", "--args", "two words",
                                       "--args", "", "--args", "--flag"],
                                      ["ARIG", "two words", "", "--flag"], kind)

    def test_separator_preserves_program_flags_for_every_dispatch(self):
        expected = ["ARIG", "--cpus", "8", "--wait", "--", "-3", "file with spaces"]
        for kind in ("py", "sh", "jl", "executable"):
            with self.subTest(kind=kind):
                self.assert_roundtrip(["--cpus", "2", "--", *expected], expected, kind)
                self.assertIn("#SBATCH --cpus-per-task=2", self.capture.read_text())

    def test_empty_separator(self):
        self.assert_roundtrip(["--"], [])

    def test_mixed_args_and_separator(self):
        self.assert_roundtrip(["--args", "first", "--", "second", ""],
                              ["first", "second", ""])

    def test_literal_shell_characters(self):
        marker = self.work / "must-not-exist"
        values = [f'$(touch "{marker}")', f'`touch "{marker}"`',
                  f'"; touch "{marker}"; #', "$HOME", "*.sac", "a;b|c&d",
                  "single'quote", 'double"quote', "back\\slash", "line1\nline2",
                  "tab\there", "á日本", "--foo 1 --bar 2"]
        self.assert_roundtrip(["--", *values], values)
        self.assertFalse(marker.exists())

    def test_program_failure_is_preserved(self):
        self.assert_roundtrip(["--", "failure case"], ["failure case"], exitcode=7)

    def test_missing_option_values_fail_without_submitting(self):
        for option in ("--gpu", "--env", "--cpus", "--node", "--mem", "--job-name", "--args"):
            with self.subTest(option=option):
                result = self.submit(self.program(), [option])
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("requires a value", result.stdout + result.stderr)
                self.assertFalse(self.capture.exists())

    def test_option_cannot_consume_next_option_as_value(self):
        result = self.submit(self.program(), ["--cpus", "--mem", "8G"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires a value", result.stdout + result.stderr)
        self.assertFalse(self.capture.exists())

    def test_unseparated_extra_arguments_are_rejected(self):
        result = self.submit(self.program(), ["ARIG"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Use '--'", result.stdout + result.stderr)
        self.assertFalse(self.capture.exists())

    def test_separator_requires_program(self):
        result = subprocess.run([str(self.repo / "bin" / "panda"), "submit", "--", "ARIG"],
                                cwd=self.work, env=self.env, capture_output=True,
                                text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Specify the program", result.stdout + result.stderr)
        self.assertFalse(self.capture.exists())


if __name__ == "__main__":
    unittest.main()
