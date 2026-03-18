from __future__ import annotations

import argparse
import http.server
import socketserver
from pathlib import Path


class SpaRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, directory: str | None = None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def do_GET(self) -> None:
        requested_path = self.path.split("?", 1)[0].split("#", 1)[0]
        # If a route does not map to a physical file, serve index.html for SPA routing.
        if requested_path not in ("/", "") and "." not in Path(requested_path).name:
            self.path = "/index.html"
        return super().do_GET()

    def end_headers(self) -> None:
        # Avoid stale Flutter web assets during iterative local deployments.
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve Flutter web build as SPA.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8088)
    parser.add_argument("--dir", default="build/web")
    args = parser.parse_args()

    web_dir = Path(args.dir).resolve()
    if not web_dir.exists():
        raise SystemExit(f"Directory not found: {web_dir}")

    handler = lambda *h_args, **h_kwargs: SpaRequestHandler(
        *h_args, directory=str(web_dir), **h_kwargs
    )
    with socketserver.ThreadingTCPServer((args.host, args.port), handler) as httpd:
        print(f"Serving {web_dir} on http://{args.host}:{args.port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
