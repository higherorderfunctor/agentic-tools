"""Exercise both extracted engine shapes without redistributing vendor bundles."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SPLICER = Path(sys.argv.pop(1)).resolve()
CLI = b"Vendor identity. Terminal guidance.\n\n"
IDE = b"IDE identity. Editor guidance.\n\n"
LEGACY = (
    b'function getIdentity(client24) {\n  if (client24 === "kiro-cli") {\n'
    b"    return `" + CLI + b"`;\n  }\n"
    b'  if (client24 === "kiro-ide") {\n    return `' + IDE + b"`;\n  }\n"
    b'  return "";\n}\n'
)
# Syntax transcribed from the 2.21.2 bundle; prose is synthetic. Include the
# adjacent session dispatcher that must never satisfy the identity controls.
COMPACT = (
    b'function xSs(e){return e==="kiro-cli"?`' + CLI
    + b'`:e==="kiro-ide"?`' + IDE + b'`:""}'
)
ADJACENT = b'function sessions(e){return e==="kiro-web"?`Web session`:`Local session`}'


class SpliceTests(unittest.TestCase):
    def run_splice(self, data, replacement=b"Custom identity. Another sentence!"):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src, dst, repl = (root / name for name in ("source.js", "patched.js", "identity"))
            src.write_bytes(data)
            repl.write_bytes(replacement)
            result = subprocess.run(
                [sys.executable, str(SPLICER), str(src), str(dst), str(repl)],
                capture_output=True,
            )
            self.assertEqual(src.read_bytes(), data)
            return result, dst.read_bytes() if dst.exists() else None

    def test_splice_and_execute_both_shapes(self):
        for function, name in ((LEGACY, "getIdentity"), (COMPACT, "xSs")):
            with self.subTest(name=name):
                data = function + ADJACENT
                result, patched = self.run_splice(data)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    patched, data.replace(b"Vendor identity.", b"Custom identity. Another sentence!", 1)
                )
                evaluated = subprocess.check_output(
                    ["node", "-e", patched.decode() + f'\nconsole.log(JSON.stringify(["kiro-cli","kiro-ide","kiro-web"].map({name})))']
                )
                self.assertEqual(json.loads(evaluated), [
                    "Custom identity. Another sentence! Terminal guidance.\n\n", IDE.decode(), ""
                ])

    def test_print_both_shapes(self):
        for data in (LEGACY, COMPACT):
            with self.subTest(data=data), tempfile.TemporaryDirectory() as tmp:
                src = Path(tmp) / "source.js"
                src.write_bytes(data + ADJACENT)
                result = subprocess.run(
                    [sys.executable, str(SPLICER), str(src), "--print"], capture_output=True
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, b"Vendor identity.")
                self.assertEqual(src.read_bytes(), data + ADJACENT)

    def test_renaming_spacing_and_prose_changes(self):
        for data in (
            COMPACT.replace(b"xSs", b"renamed_$123").replace(b"(e)", b"($arg2)").replace(b"e===", b"$arg2==="),
            COMPACT.replace(b"xSs", b"getIdentity"),
            COMPACT.replace(b"===", b" === ").replace(b"?", b" ? ").replace(b"}", b"; }"),
            COMPACT.replace(b"Vendor identity.", b"New vendor identity!"),
            COMPACT.replace(b"Terminal guidance.", rb"Terminal with \`escaped\` examples."),
        ):
            with self.subTest(data=data):
                result, patched = self.run_splice(data)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(b"Custom identity. Another sentence!", patched)

    def test_reject_ambiguous_or_restructured_functions(self):
        for data, message in (
            (COMPACT + COMPACT, b"found 2"),
            (LEGACY + COMPACT, b"found 2"),
            (COMPACT.replace(b'"kiro-ide"', b'"kiro-web"'), b"found 0"),
            (COMPACT.replace(b':e===', b':other==='), b"found 0"),
            (COMPACT.replace(b'(e)', b'(other)'), b"found 0"),
            (COMPACT.replace(b'`:""}', b'`:"";extra()}'), b"found 0"),
            (LEGACY.replace(b'"kiro-ide"', b'"other"'), b"positive control failed"),
            (COMPACT.replace(b"Vendor identity. Terminal guidance.", b"No sentence boundary"), b"no sentence boundary"),
            (ADJACENT, b"found 0"),
        ):
            with self.subTest(data=data):
                result, patched = self.run_splice(data + ADJACENT)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
                self.assertIsNone(patched)


if __name__ == "__main__":
    unittest.main()
