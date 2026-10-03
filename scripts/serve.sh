#!/usr/bin/env bash
# Serve the Kurvenrausch site (or any static dir) over HTTP and open a browser.
# Env:
#   PKG                 - directory to serve (default: current directory)
#   KURVENRAUSCH_PORT   - preferred port (default: 8765); exits if the bind fails
#                         so the origin stays stable for local testing
#   BROWSER             - optional browser command
set -euo pipefail

if [ -n "${PKG:-}" ]; then
  cd "$PKG"
fi

port="${KURVENRAUSCH_PORT:-8765}"

port_file=$(mktemp)
server_pid=
trap 'kill "$server_pid" 2>/dev/null || true; rm -f "$port_file"' EXIT

python3 -c '
import http.server, socketserver, sys
port_file, port = sys.argv[1], int(sys.argv[2])
class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
    # Disable caching so wasm/js updates show up on reload during local testing.
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        # Cross-origin isolation not required for this build; keep simple.
        super().end_headers()
socketserver.TCPServer.allow_reuse_address = True
try:
    httpd = socketserver.TCPServer(("127.0.0.1", port), Quiet)
except OSError as e:
    sys.stderr.write(
        "error: cannot bind 127.0.0.1:%s (%s)\n"
        "       set KURVENRAUSCH_PORT to a free port\n" % (port, e))
    sys.exit(1)
open(port_file, "w").write(str(httpd.server_address[1]))
httpd.serve_forever()
' "$port_file" "$port" &
server_pid=$!

for i in $(seq 1 50); do
  [ -s "$port_file" ] && break
  sleep 0.05
done
if [ ! -s "$port_file" ]; then
  echo "error: local HTTP server failed to start on port $port" >&2
  exit 1
fi
port=$(cat "$port_file")
url="http://127.0.0.1:${port}/"
echo "Serving Kurvenrausch site at $url  (Ctrl-C to stop)"
echo "  Wasm build (if present): ${url}play/kurvenrausch.html"

if [ -n "${BROWSER:-}" ]; then
  "$BROWSER" "$url" >/dev/null 2>&1 || true
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$url" >/dev/null 2>&1 || true
fi

wait "$server_pid"
