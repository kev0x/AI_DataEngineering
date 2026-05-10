"""DuckDB UI launcher and reverse proxy for local warehouse inspection.

Purpose:
    Starts DuckDB UI for humans who want to inspect schemas, tables, views, and ad-hoc
    SQL results while learning the warehouse.
Pipeline role:
    Opens a temporary UI catalog and attaches a copied snapshot of the finance warehouse
    so the UI does not hold locks on the live API/ETL database file.
Dependencies:
    DuckDB UI extension, Python HTTP proxy classes, Uvicorn/FastAPI container runtime,
    warehouse/finance.duckdb, and Docker/docker-compose.yml port settings.
"""
from __future__ import annotations

from http.client import HTTPConnection, HTTPResponse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import signal
import shutil
import threading
from typing import ClassVar

import duckdb


WAREHOUSE_PATH = Path(os.getenv("WAREHOUSE_PATH", "/app/warehouse/finance.duckdb"))
UI_CATALOG_PATH = Path(
    os.getenv("DUCKDB_UI_CATALOG_PATH", "/tmp/duckdb_ui_catalog.duckdb")
)
UI_WAREHOUSE_SNAPSHOT_PATH = Path(
    os.getenv("DUCKDB_UI_WAREHOUSE_SNAPSHOT_PATH", "/tmp/duckdb_ui_finance_snapshot.duckdb")
)
UI_DATABASE_ALIAS = os.getenv("DUCKDB_UI_DATABASE_ALIAS", "finance")
UI_INTERNAL_PORT = int(os.getenv("DUCKDB_UI_INTERNAL_PORT", "4214"))
UI_PROXY_PORT = int(os.getenv("DUCKDB_UI_PROXY_PORT", "4213"))


class SqlLiteral:
    """Small helper for safely formatting trusted file paths into DuckDB SQL."""

    @staticmethod
    def string(value: str | Path) -> str:
        """Return a single-quoted SQL string literal."""
        return "'" + str(value).replace("'", "''") + "'"

    @staticmethod
    def identifier(value: str) -> str:
        """Return a double-quoted SQL identifier."""
        return '"' + value.replace('"', '""') + '"'


class DuckDbUiProxyRequestHandler(BaseHTTPRequestHandler):
    """HTTP proxy handler for exposing DuckDB UI outside the container."""

    upstream_host: ClassVar[str] = "127.0.0.1"
    upstream_port: ClassVar[int] = 4214
    protocol_version = "HTTP/1.1"
    server_version = "DuckDbUiProxy/1.0"
    hop_by_hop_headers: ClassVar[set[str]] = {
        "connection",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailers",
        "transfer-encoding",
        "upgrade",
    }

    def do_GET(self) -> None:
        """Forward a browser GET request to DuckDB UI."""
        self.proxy_request_to_duckdb_ui()

    def do_HEAD(self) -> None:
        """Forward a browser HEAD request to DuckDB UI."""
        self.proxy_request_to_duckdb_ui()

    def do_OPTIONS(self) -> None:
        """Forward a browser OPTIONS request to DuckDB UI."""
        self.proxy_request_to_duckdb_ui()

    def do_POST(self) -> None:
        """Forward a browser POST request to DuckDB UI."""
        self.proxy_request_to_duckdb_ui()

    def do_PUT(self) -> None:
        """Forward a browser PUT request to DuckDB UI."""
        self.proxy_request_to_duckdb_ui()

    def do_PATCH(self) -> None:
        """Forward a browser PATCH request to DuckDB UI."""
        self.proxy_request_to_duckdb_ui()

    def do_DELETE(self) -> None:
        """Forward a browser DELETE request to DuckDB UI."""
        self.proxy_request_to_duckdb_ui()

    def proxy_request_to_duckdb_ui(self) -> None:
        """Send the current HTTP request to DuckDB UI and return its response."""
        request_body = self.read_request_body()
        upstream_headers = self.build_upstream_headers()
        upstream_connection = HTTPConnection(
            self.upstream_host,
            self.upstream_port,
            timeout=120,
        )

        try:
            upstream_connection.request(
                method=self.command,
                url=self.path,
                body=request_body,
                headers=upstream_headers,
            )
            upstream_response = upstream_connection.getresponse()
            if self.is_streaming_response(upstream_response):
                self.send_streaming_response(upstream_response)
                return

            response_body = upstream_response.read()

            self.send_response(upstream_response.status, upstream_response.reason)
            for header_name, header_value in upstream_response.getheaders():
                normalized_header_name = header_name.lower()
                if normalized_header_name in self.hop_by_hop_headers:
                    continue
                if normalized_header_name == "content-length":
                    continue
                self.send_header(header_name, header_value)
            self.send_header("Content-Length", str(len(response_body)))
            self.end_headers()

            if self.command != "HEAD":
                self.wfile.write(response_body)
        finally:
            upstream_connection.close()

    def is_streaming_response(self, upstream_response: HTTPResponse) -> bool:
        """Return true when DuckDB UI is sending a long-lived event stream."""
        content_type_header = upstream_response.getheader("Content-Type", "")
        return content_type_header.startswith("text/event-stream")

    def send_streaming_response(self, upstream_response: HTTPResponse) -> None:
        """Forward a DuckDB UI event stream without buffering it first."""
        self.send_response(upstream_response.status, upstream_response.reason)
        for header_name, header_value in upstream_response.getheaders():
            normalized_header_name = header_name.lower()
            if normalized_header_name in self.hop_by_hop_headers:
                continue
            if normalized_header_name == "content-length":
                continue
            self.send_header(header_name, header_value)
        self.end_headers()

        while True:
            event_stream_line = upstream_response.readline()
            if not event_stream_line:
                break
            try:
                self.wfile.write(event_stream_line)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                break

    def read_request_body(self) -> bytes | None:
        """Read the request body when the browser sends one."""
        content_length_header = self.headers.get("Content-Length")
        if content_length_header is None:
            return None
        content_length = int(content_length_header)
        if content_length == 0:
            return b""
        return self.rfile.read(content_length)

    def build_upstream_headers(self) -> dict[str, str]:
        """Copy safe request headers to the internal DuckDB UI server."""
        headers: dict[str, str] = {}
        for header_name, header_value in self.headers.items():
            normalized_header_name = header_name.lower()
            if normalized_header_name in self.hop_by_hop_headers:
                continue
            if normalized_header_name == "host":
                headers["Host"] = f"localhost:{self.upstream_port}"
                continue
            if normalized_header_name == "origin":
                headers["Origin"] = self.upstream_local_url()
                continue
            if normalized_header_name == "referer":
                headers["Referer"] = self.upstream_local_url() + "/"
                continue
            headers[header_name] = header_value
        return headers

    def upstream_local_url(self) -> str:
        """Return the local origin expected by DuckDB UI's request guard."""
        return f"http://localhost:{self.upstream_port}"

    def log_message(self, format: str, *args: object) -> None:
        """Write access logs to Docker logs with a DuckDB UI proxy prefix."""
        print(f"DuckDB UI proxy: {format % args}", flush=True)


class HttpReverseProxy:
    """Expose DuckDB UI's localhost HTTP server on a Docker-published port."""

    def __init__(
        self,
        listen_host: str,
        listen_port: int,
        upstream_host: str,
        upstream_port: int,
    ) -> None:
        """Store listener and upstream HTTP coordinates."""
        self.listen_host = listen_host
        self.listen_port = listen_port
        self.upstream_host = upstream_host
        self.upstream_port = upstream_port
        self.http_server: ThreadingHTTPServer | None = None
        self.thread: threading.Thread | None = None

    def start(self) -> None:
        """Start the proxy server in a background thread."""
        handler_class = self.build_request_handler_class()
        self.http_server = ThreadingHTTPServer(
            (self.listen_host, self.listen_port),
            handler_class,
        )
        self.thread = threading.Thread(
            target=self.http_server.serve_forever,
            name="duckdb-ui-http-proxy",
            daemon=True,
        )
        self.thread.start()
        print(
            f"DuckDB UI proxy listening on http://{self.listen_host}:{self.listen_port}",
            flush=True,
        )

    def build_request_handler_class(self) -> type[DuckDbUiProxyRequestHandler]:
        """Create a handler class bound to this proxy's upstream address."""
        upstream_host = self.upstream_host
        upstream_port = self.upstream_port

        class ConfiguredDuckDbUiProxyRequestHandler(DuckDbUiProxyRequestHandler):
            """Request handler with proxy instance settings attached."""

            pass

        ConfiguredDuckDbUiProxyRequestHandler.upstream_host = upstream_host
        ConfiguredDuckDbUiProxyRequestHandler.upstream_port = upstream_port
        return ConfiguredDuckDbUiProxyRequestHandler

    def stop(self) -> None:
        """Stop the proxy server and wait briefly for its thread to exit."""
        if self.http_server is not None:
            self.http_server.shutdown()
            self.http_server.server_close()
        if self.thread is not None:
            self.thread.join(timeout=5)


class DuckDbUiService:
    """Starts DuckDB UI against a read-only attached finance warehouse."""

    def __init__(
        self,
        warehouse_path: Path,
        ui_catalog_path: Path,
        warehouse_snapshot_path: Path,
        database_alias: str,
        ui_internal_port: int,
        ui_proxy_port: int,
    ) -> None:
        """Store DuckDB paths, alias, and UI port settings."""
        self.warehouse_path = warehouse_path
        self.ui_catalog_path = ui_catalog_path
        self.warehouse_snapshot_path = warehouse_snapshot_path
        self.database_alias = database_alias
        self.ui_internal_port = ui_internal_port
        self.ui_proxy_port = ui_proxy_port
        self.connection: duckdb.DuckDBPyConnection | None = None
        self.stop_event = threading.Event()

    def run(self) -> None:
        """Attach the warehouse, start DuckDB UI, and serve the exposed proxy."""
        self.install_signal_handlers()
        self.connection = self.open_connection()
        self.refresh_warehouse_snapshot()
        self.attach_finance_warehouse(self.connection)
        self.start_duckdb_ui_server(self.connection)
        reverse_proxy = HttpReverseProxy(
            listen_host="0.0.0.0",
            listen_port=self.ui_proxy_port,
            upstream_host="127.0.0.1",
            upstream_port=self.ui_internal_port,
        )
        reverse_proxy.start()
        try:
            self.stop_event.wait()
        finally:
            reverse_proxy.stop()
            self.shutdown_duckdb_connection()

    def open_connection(self) -> duckdb.DuckDBPyConnection:
        """Open the writable UI catalog database used for UI notebooks/state."""
        self.ui_catalog_path.parent.mkdir(parents=True, exist_ok=True)
        return duckdb.connect(str(self.ui_catalog_path))

    def attach_finance_warehouse(self, connection: duckdb.DuckDBPyConnection) -> None:
        """Attach the finance warehouse snapshot read-only so the UI cannot mutate it."""
        warehouse_literal = SqlLiteral.string(self.warehouse_snapshot_path)
        alias_identifier = SqlLiteral.identifier(self.database_alias)
        connection.execute(
            f"ATTACH IF NOT EXISTS {warehouse_literal} AS {alias_identifier} (READ_ONLY)"
        )
        connection.execute(f"USE {alias_identifier}")

    def refresh_warehouse_snapshot(self) -> None:
        """Copy the live warehouse to a UI-only file so browsing does not lock writes."""
        self.warehouse_snapshot_path.parent.mkdir(parents=True, exist_ok=True)
        if self.warehouse_snapshot_path.exists():
            self.warehouse_snapshot_path.unlink()
        shutil.copy2(self.warehouse_path, self.warehouse_snapshot_path)

    def start_duckdb_ui_server(self, connection: duckdb.DuckDBPyConnection) -> None:
        """Start DuckDB's embedded UI server on the internal localhost port."""
        connection.execute(f"SET ui_local_port = {self.ui_internal_port}")
        message = connection.execute("CALL start_ui_server()").fetchone()[0]
        print(message, flush=True)
        print(
            f"DuckDB UI available at http://localhost:{self.ui_proxy_port}",
            flush=True,
        )

    def install_signal_handlers(self) -> None:
        """Register SIGINT/SIGTERM handlers for graceful container shutdown."""
        for signal_name in (signal.SIGINT, signal.SIGTERM):
            signal.signal(signal_name, self.handle_shutdown_signal)

    def handle_shutdown_signal(
        self,
        received_signal: int,
        current_stack_frame: object,
    ) -> None:
        """Mark the service for shutdown after Docker sends a stop signal."""
        self.stop_event.set()

    def shutdown_duckdb_connection(self) -> None:
        """Stop the DuckDB UI server and close the DuckDB connection."""
        if self.connection is None:
            return
        self.connection.execute("CALL stop_ui_server()")
        self.connection.close()


def build_service_from_environment() -> DuckDbUiService:
    """Create a DuckDbUiService using Docker environment variables."""
    return DuckDbUiService(
        warehouse_path=WAREHOUSE_PATH,
        ui_catalog_path=UI_CATALOG_PATH,
        warehouse_snapshot_path=UI_WAREHOUSE_SNAPSHOT_PATH,
        database_alias=UI_DATABASE_ALIAS,
        ui_internal_port=UI_INTERNAL_PORT,
        ui_proxy_port=UI_PROXY_PORT,
    )


def main() -> None:
    """Start the DuckDB UI service."""
    build_service_from_environment().run()


if __name__ == "__main__":
    main()
