#!/usr/bin/env python3
"""Contracts for the ephemeral export adapter and read-only HTTP server."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

from exporter import SCHEMA, ExportError, adapt_export, export_project
from server import build_server

FIXTURE = {
    "_COMMENT": "fixture",
    "DOCUMENTS": [
        {
            "_NODE_TYPE": "DOCUMENT",
            "TITLE": "Fixture document",
            "GRAMMAR": {"ELEMENTS": [{"NODE_TYPE": "MECHANISM"}]},
            "NODES": [
                {
                    "_NODE_TYPE": "MECHANISM",
                    "UID": "MECH-FIXTURE",
                    "TITLE": "Fixture node",
                    "DEPTH": "implemented",
                    "STATEMENT": "A fixture.",
                    "RELATIONS": [
                        {
                            "TYPE": "Parent",
                            "VALUE": "DEC-FIXTURE",
                            "ROLE": "Governed_By",
                        }
                    ],
                }
            ],
        }
    ],
}


class ExportAdapterTest(unittest.TestCase):
    def test_adapter_flattens_nodes_and_preserves_relations_as_text(self) -> None:
        rows, stats = adapt_export(FIXTURE)

        self.assertEqual(stats, {"documents": 1, "nodes": 1, "relations": 1})
        self.assertEqual(rows[0]["UID"], "MECH-FIXTURE")
        self.assertEqual(rows[0]["DOCUMENT_TITLE"], "Fixture document")
        self.assertEqual(rows[0]["RELATION_COUNT"], 1)
        self.assertEqual(rows[0]["RELATION_ROLES"], "Governed_By")
        self.assertEqual(rows[0]["RELATION_TARGETS"], "DEC-FIXTURE")
        self.assertEqual(
            json.loads(rows[0]["RELATIONS_JSON"]),
            FIXTURE["DOCUMENTS"][0]["NODES"][0]["RELATIONS"],
        )
        self.assertNotIn("GRAMMAR", rows[0])

    def test_export_uses_and_cleans_a_fresh_temporary_directory(self) -> None:
        observed_outputs: list[Path] = []
        project_root = Path(__file__).resolve().parents[3]

        def fake_run(command, **kwargs):
            self.assertEqual(kwargs["cwd"], project_root)
            self.assertEqual(command[1:3], ["export", str(project_root)])
            output_dir = Path(command[command.index("--output-dir") + 1])
            observed_outputs.append(output_dir)
            export_file = output_dir / "json" / "index.json"
            export_file.parent.mkdir(parents=True)
            export_file.write_text(json.dumps(FIXTURE), encoding="utf-8")
            return subprocess.CompletedProcess(command, 0, stdout="", stderr="")

        payload = export_project(
            project_root,
            Path("/fake/strictdoc"),
            run=fake_run,
        )

        self.assertEqual(payload["schema"], SCHEMA)
        self.assertEqual(payload["export"]["nodes"], 1)
        self.assertEqual(len(observed_outputs), 1)
        self.assertFalse(observed_outputs[0].exists())

    def test_adapter_rejects_non_export_shapes(self) -> None:
        with self.assertRaisesRegex(ExportError, "DOCUMENTS"):
            adapt_export({"documents": []})

    def test_real_cli_export_is_the_only_strictdoc_boundary(self) -> None:
        strictdoc_bin = shutil.which("strictdoc")
        if strictdoc_bin is None:
            self.skipTest("strictdoc is not on PATH")
        project_root = Path(__file__).resolve().parents[3]

        payload = export_project(project_root, Path(strictdoc_bin))

        self.assertNotIn("strictdoc", sys.modules)
        self.assertEqual(payload["schema"], SCHEMA)
        self.assertGreater(payload["export"]["sourceBytes"], 1_000_000)
        self.assertGreater(payload["export"]["nodes"], 350)
        self.assertEqual(payload["export"]["nodes"], len(payload["rows"]))
        self.assertIn(
            "WORK-SDOC-PERSPECTIVE-SPIKE",
            {row.get("UID") for row in payload["rows"]},
        )


class HttpContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.project_root = Path(__file__).resolve().parents[3]
        cls.calls = 0

        def data_loader(project_root: Path, strictdoc_bin: Path) -> dict:
            cls.calls += 1
            rows, stats = adapt_export(FIXTURE)
            return {
                "schema": SCHEMA,
                "export": {
                    "startedAt": f"request-{cls.calls}",
                    "durationMs": 1.0,
                    "sourceBytes": 100,
                    **stats,
                },
                "rows": rows,
            }

        cls.server = build_server(
            cls.project_root,
            Path("/fake/strictdoc"),
            "127.0.0.1",
            0,
            data_loader=data_loader,
        )
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        host, port = cls.server.server_address[:2]
        cls.base_url = f"http://{host}:{port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)

    def test_each_data_request_invokes_the_loader_and_disables_cache(self) -> None:
        before = self.calls
        started_at = []
        for _ in range(2):
            with urllib.request.urlopen(f"{self.base_url}/api/data") as response:
                payload = json.load(response)
                self.assertEqual(response.headers["Cache-Control"], "no-store")
                started_at.append(payload["export"]["startedAt"])

        self.assertEqual(self.calls, before + 2)
        self.assertEqual(len(set(started_at)), 2)

    def test_head_builds_fresh_data_without_returning_a_body(self) -> None:
        before = self.calls
        request = urllib.request.Request(
            f"{self.base_url}/api/data", method="HEAD"
        )
        with urllib.request.urlopen(request) as response:
            self.assertEqual(response.read(), b"")
            self.assertGreater(int(response.headers["Content-Length"]), 0)
        self.assertEqual(self.calls, before + 1)

    def test_static_routes_are_allowlisted(self) -> None:
        with urllib.request.urlopen(f"{self.base_url}/") as response:
            page = response.read()
            self.assertIn(b"SDOC PERSPECTIVE", page)
            policy = response.headers["Content-Security-Policy"]
            self.assertIn("https://cdn.jsdelivr.net", policy)
            self.assertIn("script-src", policy)
            self.assertIn("blob:", policy)
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(f"{self.base_url}/server.py")
        self.assertEqual(error.exception.code, 404)
        error.exception.close()

    def test_mutating_methods_are_rejected(self) -> None:
        request = urllib.request.Request(
            f"{self.base_url}/api/data", data=b"{}", method="POST"
        )
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(request)
        self.assertEqual(error.exception.code, 405)
        self.assertEqual(error.exception.headers["Allow"], "GET, HEAD")
        error.exception.close()


if __name__ == "__main__":
    unittest.main()
