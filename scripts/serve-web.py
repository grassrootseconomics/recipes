#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse
import os
import subprocess
import sys


class GodotWebHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()


def open_browser(url: str) -> None:
    if sys.platform == "win32":
        os.startfile(url)  # type: ignore[attr-defined]
        return
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    subprocess.Popen([opener, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve a Godot Web export with the headers Godot expects.")
    parser.add_argument("--root", default="client/web", help="web export directory")
    parser.add_argument("--host", default="127.0.0.1", help="bind host")
    parser.add_argument("--port", default=8081, type=int, help="bind port")
    parser.add_argument("--no-browser", action="store_true", help="do not open a browser")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not (root / "index.html").exists():
        fallback = Path("client/build/web").resolve()
        if args.root == "client/web" and (fallback / "index.html").exists():
            root = fallback
        else:
            print(f"No index.html found in {root}. Run `npm run export:web` first.", file=sys.stderr)
            return 1

    os.chdir(root)
    url = f"http://{args.host}:{args.port}/"
    print(f"Serving {root} at {url}")
    if not args.no_browser and args.host in {"127.0.0.1", "localhost"}:
        open_browser(url)
    HTTPServer((args.host, args.port), GodotWebHandler).serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
