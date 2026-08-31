#!/usr/bin/env python3
"""Run a fresh StrictDoc JSON export and adapt it to Perspective rows."""

from __future__ import annotations

import json
import subprocess
import tempfile
import time
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA = "sdoc-perspective/1"
EXPORT_FILE = Path("json/index.json")


class ExportError(RuntimeError):
    """A request-time export failed or returned an unexpected schema."""


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace(
        "+00:00", "Z"
    )


def _relation_text(relations: list[dict[str, Any]], field: str) -> str:
    return ", ".join(
        str(relation[field])
        for relation in relations
        if relation.get(field) not in (None, "")
    )


def adapt_export(payload: object) -> tuple[list[dict[str, Any]], dict[str, int]]:
    """Flatten StrictDoc's exported documents without inspecting source files."""
    if not isinstance(payload, dict):
        raise ExportError("StrictDoc JSON root is not an object")
    documents = payload.get("DOCUMENTS")
    if not isinstance(documents, list):
        raise ExportError("StrictDoc JSON has no DOCUMENTS array")

    rows: list[dict[str, Any]] = []
    relation_count = 0
    for document_number, document in enumerate(documents, start=1):
        if not isinstance(document, dict):
            raise ExportError(f"DOCUMENTS[{document_number - 1}] is not an object")
        title = document.get("TITLE")
        nodes = document.get("NODES")
        if not isinstance(title, str) or not isinstance(nodes, list):
            raise ExportError(
                f"DOCUMENTS[{document_number - 1}] has no TITLE or NODES array"
            )

        for node_number, node in enumerate(nodes, start=1):
            if not isinstance(node, dict):
                raise ExportError(
                    f"document {document_number} NODES[{node_number - 1}] "
                    "is not an object"
                )
            row: dict[str, Any] = {}
            for field, value in node.items():
                if field == "RELATIONS":
                    continue
                if value is not None and not isinstance(
                    value, (str, int, float, bool)
                ):
                    raise ExportError(
                        f"node {node.get('UID', node_number)!r} field {field} "
                        "is not scalar"
                    )
                row[field] = value

            relations = node.get("RELATIONS", [])
            if not isinstance(relations, list) or not all(
                isinstance(relation, dict) for relation in relations
            ):
                raise ExportError(
                    f"node {node.get('UID', node_number)!r} RELATIONS is invalid"
                )
            relation_count += len(relations)
            row.update(
                {
                    "DOCUMENT_TITLE": title,
                    "RELATION_COUNT": len(relations),
                    "RELATION_ROLES": _relation_text(relations, "ROLE"),
                    "RELATION_TARGETS": _relation_text(relations, "VALUE"),
                    "RELATIONS_JSON": json.dumps(
                        relations,
                        ensure_ascii=False,
                        separators=(",", ":"),
                        sort_keys=True,
                    ),
                }
            )
            rows.append(row)

    return rows, {
        "documents": len(documents),
        "nodes": len(rows),
        "relations": relation_count,
    }


def export_project(
    project_root: Path,
    strictdoc_bin: Path,
    *,
    timeout: float = 120,
    run: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
) -> dict[str, Any]:
    """Export after this call begins, adapt in-place, then discard the export."""
    project_root = project_root.resolve()
    started_at = _utc_now()
    started = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix="sdoc-perspective-export-") as output:
        output_dir = Path(output)
        command = [
            str(strictdoc_bin),
            "export",
            str(project_root),
            "--formats=json",
            "--output-dir",
            str(output_dir),
        ]
        try:
            result = run(
                command,
                cwd=project_root,
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ExportError(f"cannot run StrictDoc exporter: {error}") from error
        if result.returncode != 0:
            detail = (result.stderr or result.stdout or "no diagnostic").strip()
            raise ExportError(
                f"StrictDoc exporter exited {result.returncode}: {detail}"
            )

        export_file = output_dir / EXPORT_FILE
        try:
            source_bytes = export_file.stat().st_size
            raw_export = json.loads(export_file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise ExportError(f"cannot read {EXPORT_FILE}: {error}") from error
        rows, stats = adapt_export(raw_export)

    return {
        "schema": SCHEMA,
        "export": {
            "startedAt": started_at,
            "durationMs": round((time.perf_counter() - started) * 1000, 1),
            "sourceBytes": source_bytes,
            **stats,
        },
        "rows": rows,
    }
