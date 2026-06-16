"""Local host and reverse proxy for the installed Windows web application."""

from __future__ import annotations

import json
import mimetypes
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


APP_HOST = "127.0.0.1"
APP_PORT = 8787
BACKENDS = {
    "/calculator": "http://127.0.0.1:8080",
    "/knowledge": "http://127.0.0.1:8090",
}
HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}


ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
REPOSITORY_ROOT = PROJECT_ROOT.parents[1]
INSTALLED_WEB_ROOT = ROOT / "web"
SOURCE_WEB_ROOT = PROJECT_ROOT / "build" / "web"
WEB_ROOT = INSTALLED_WEB_ROOT if (INSTALLED_WEB_ROOT / "index.html").is_file() else SOURCE_WEB_ROOT
LOG_ROOT = ROOT / "logs"
CONFIG_PATH = Path(os.environ.get("MED_APP_CONFIG", ROOT / "config.json"))


def default_config() -> dict[str, dict[str, str]]:
    calculator_root = REPOSITORY_ROOT / "services" / "calculator-api"
    knowledge_root = REPOSITORY_ROOT / "services" / "knowledge-api"
    return {
        "calculator": {
            "python": str(calculator_root / ".venv" / "Scripts" / "python.exe"),
            "cwd": str(calculator_root),
            "module": "src.infrastructure.api.server",
        },
        "knowledge": {
            "python": str(knowledge_root / ".venv" / "Scripts" / "python.exe"),
            "cwd": str(knowledge_root),
            "module": "medical_kb.api",
        },
    }


def port_is_open(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as connection:
        connection.settimeout(0.3)
        return connection.connect_ex(("127.0.0.1", port)) == 0


def start_backend(name: str, config: dict[str, str], port: int) -> None:
    if port_is_open(port):
        return
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    log_handle = (LOG_ROOT / f"{name}.log").open("ab", buffering=0)
    creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    subprocess.Popen(
        [config["python"], "-m", config["module"]],
        cwd=config["cwd"],
        env={**os.environ, "PYTHONIOENCODING": "utf-8", "PYTHONUTF8": "1"},
        stdin=subprocess.DEVNULL,
        stdout=log_handle,
        stderr=subprocess.STDOUT,
        creationflags=creation_flags,
        close_fds=True,
    )


def open_app_window() -> None:
    if os.environ.get("MED_APP_NO_BROWSER") == "1":
        return
    edge = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
    if not edge.is_file():
        edge = Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe")
    if not edge.is_file():
        return
    subprocess.Popen(
        [
            str(edge),
            f"--app=http://{APP_HOST}:{APP_PORT}",
            "--start-maximized",
            "--disable-features=msEdgeSidebarV2",
        ],
        close_fds=True,
    )


class AppHandler(BaseHTTPRequestHandler):
    server_version = "MedSpravochnik/0.0.0.01"

    def do_GET(self) -> None:  # noqa: N802
        if self._proxy_if_needed():
            return
        self._serve_static()

    def do_POST(self) -> None:  # noqa: N802
        if not self._proxy_if_needed():
            self.send_error(405)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        LOG_ROOT.mkdir(parents=True, exist_ok=True)
        with (LOG_ROOT / "desktop-host.log").open("a", encoding="utf-8") as log:
            log.write(f"{self.log_date_time_string()} {format % args}\n")

    def _proxy_if_needed(self) -> bool:
        for prefix, backend in BACKENDS.items():
            if self.path == prefix or self.path.startswith(f"{prefix}/"):
                path = self.path[len(prefix) :] or "/"
                self._proxy(f"{backend}{path}")
                return True
        return False

    def _proxy(self, target: str) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else None
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() != "host"
        }
        request = urllib.request.Request(target, data=body, headers=headers, method=self.command)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read()
                self.send_response(response.status)
                for key, value in response.headers.items():
                    if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() != "content-length":
                        self.send_header(key, value)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
        except urllib.error.HTTPError as error:
            payload = error.read()
            self.send_response(error.code)
            self.send_header("Content-Type", error.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (urllib.error.URLError, TimeoutError) as error:
            payload = json.dumps({"detail": f"Сервис временно недоступен: {error}"}, ensure_ascii=False).encode("utf-8")
            self.send_response(503)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    def _serve_static(self) -> None:
        relative = self.path.split("?", 1)[0].lstrip("/") or "index.html"
        candidate = (WEB_ROOT / relative).resolve()
        if WEB_ROOT.resolve() not in candidate.parents and candidate != WEB_ROOT.resolve():
            self.send_error(403)
            return
        if not candidate.is_file():
            candidate = WEB_ROOT / "index.html"
        payload = candidate.read_bytes()
        content_type = mimetypes.guess_type(candidate.name)[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-cache" if candidate.name == "index.html" else "public, max-age=86400")
        self.end_headers()
        self.wfile.write(payload)


def main() -> None:
    os.chdir(ROOT)
    if not (WEB_ROOT / "index.html").is_file():
        raise FileNotFoundError(
            f"Flutter web build not found at {WEB_ROOT}. Run start_project.ps1 to build it."
        )
    config = default_config()
    if CONFIG_PATH.is_file():
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    if port_is_open(APP_PORT):
        open_app_window()
        return
    start_backend("calculator-api", config["calculator"], 8080)
    start_backend("knowledge-api", config["knowledge"], 8090)
    server = ThreadingHTTPServer((APP_HOST, APP_PORT), AppHandler)
    time.sleep(1)
    open_app_window()
    server.serve_forever()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        LOG_ROOT.mkdir(parents=True, exist_ok=True)
        (LOG_ROOT / "fatal.log").write_text(f"{type(error).__name__}: {error}\n", encoding="utf-8")
        sys.exit(1)
