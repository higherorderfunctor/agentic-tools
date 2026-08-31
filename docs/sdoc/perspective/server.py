#!/usr/bin/env python3
"""Serve a read-only Perspective UI backed by request-time JSON exports."""

from __future__ import annotations

import argparse
import json
import mimetypes
import shutil
import sys
from collections.abc import Callable
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

from exporter import ExportError, export_project

HERE = Path(__file__).resolve().parent
STATIC_ROUTES = {
    "/": HERE / "index.html",
    "/index.html": HERE / "index.html",
    "/assets/app.css": HERE / "assets" / "app.css",
    "/assets/app.js": HERE / "assets" / "app.js",
}
CONTENT_SECURITY_POLICY = (
    "default-src 'self'; "
    "connect-src 'self' https://cdn.jsdelivr.net; "
    "font-src 'self' https://cdn.jsdelivr.net data:; "
    "img-src 'self' https://cdn.jsdelivr.net data:; "
    "object-src 'none'; base-uri 'none'; "
    "script-src 'self' https://cdn.jsdelivr.net blob: 'wasm-unsafe-eval'; "
    "style-src 'self' https://cdn.jsdelivr.net 'unsafe-inline'; "
    "worker-src 'self' https://cdn.jsdelivr.net blob:"
)
mimetypes.add_type("text/javascript", ".js")

DataLoader = Callable[[Path, Path], dict]


def find_project_root(start: Path) -> Path:
    """Walk upward to this repository's StrictDoc project marker."""
    current = start.expanduser().resolve()
    if current.is_file():
        current = current.parent
    for candidate in (current, *current.parents):
        if (candidate / "strictdoc_config.py").is_file():
            return candidate
    raise FileNotFoundError(f"no strictdoc_config.py above {start}")


def _default_loader(project_root: Path, strictdoc_bin: Path) -> dict:
    return export_project(project_root, strictdoc_bin)


class PerspectiveServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self,
        address: tuple[str, int],
        project_root: Path,
        strictdoc_bin: Path,
        data_loader: DataLoader,
    ) -> None:
        super().__init__(address, PerspectiveHandler)
        self.project_root = project_root
        self.strictdoc_bin = strictdoc_bin
        self.data_loader = data_loader


class PerspectiveHandler(BaseHTTPRequestHandler):
    server: PerspectiveServer

    def do_HEAD(self) -> None:
        self._serve(include_body=False)

    def do_GET(self) -> None:
        self._serve(include_body=True)

    def do_POST(self) -> None:
        self._method_not_allowed()

    def do_PUT(self) -> None:
        self._method_not_allowed()

    def do_PATCH(self) -> None:
        self._method_not_allowed()

    def do_DELETE(self) -> None:
        self._method_not_allowed()

    def _method_not_allowed(self) -> None:
        self.send_response(HTTPStatus.METHOD_NOT_ALLOWED)
        self.send_header("Allow", "GET, HEAD")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _serve(self, *, include_body: bool) -> None:
        path = urlsplit(self.path).path
        if path == "/api/data":
            self._serve_data(include_body=include_body)
            return

        asset = STATIC_ROUTES.get(path)
        if asset is None or not asset.is_file():
            self._respond(
                HTTPStatus.NOT_FOUND,
                "text/plain; charset=utf-8",
                b"not found\n",
                include_body=include_body,
            )
            return
        media_type = mimetypes.guess_type(asset.name)[0] or "application/octet-stream"
        self._respond(
            HTTPStatus.OK,
            f"{media_type}; charset=utf-8"
            if media_type.startswith(("text/", "application/javascript"))
            else media_type,
            asset.read_bytes(),
            include_body=include_body,
        )

    def _serve_data(self, *, include_body: bool) -> None:
        try:
            payload = self.server.data_loader(
                self.server.project_root, self.server.strictdoc_bin
            )
        except ExportError as error:
            body = json.dumps(
                {"error": "export_failed", "detail": str(error)},
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")
            self._respond(
                HTTPStatus.BAD_GATEWAY,
                "application/json; charset=utf-8",
                body,
                include_body=include_body,
                cache="no-store",
            )
            return

        body = json.dumps(
            payload, ensure_ascii=False, separators=(",", ":")
        ).encode("utf-8")
        self._respond(
            HTTPStatus.OK,
            "application/json; charset=utf-8",
            body,
            include_body=include_body,
            cache="no-store",
        )

    def _respond(
        self,
        status: HTTPStatus,
        content_type: str,
        body: bytes,
        *,
        include_body: bool,
        cache: str = "no-cache",
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", cache)
        self.send_header("Content-Security-Policy", CONTENT_SECURITY_POLICY)
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if include_body:
            self.wfile.write(body)


def build_server(
    project_root: Path,
    strictdoc_bin: Path,
    host: str,
    port: int,
    *,
    data_loader: DataLoader = _default_loader,
) -> PerspectiveServer:
    return PerspectiveServer(
        (host, port), project_root, strictdoc_bin, data_loader
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="StrictDoc project or a path below it (default: cwd)",
    )
    parser.add_argument("--host", default="127.0.0.1", help="bind address")
    parser.add_argument("--port", type=int, default=8770, help="bind port")
    parser.add_argument(
        "--strictdoc-bin",
        type=Path,
        help="StrictDoc CLI to invoke (default: strictdoc from PATH)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    project_root = find_project_root(args.root)
    strictdoc_bin = args.strictdoc_bin
    if strictdoc_bin is None:
        found = shutil.which("strictdoc")
        if found is None:
            raise RuntimeError("strictdoc is not on PATH; pass --strictdoc-bin")
        strictdoc_bin = Path(found)
    strictdoc_bin = strictdoc_bin.expanduser().resolve()
    if not strictdoc_bin.is_file():
        raise FileNotFoundError(f"StrictDoc CLI does not exist: {strictdoc_bin}")

    server = build_server(project_root, strictdoc_bin, args.host, args.port)
    host, port = server.server_address[:2]
    print(f"sdoc-perspective: http://{host}:{port}/", flush=True)
    print(f"sdoc-perspective: fresh exports from {project_root}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nsdoc-perspective: stopping", flush=True)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
