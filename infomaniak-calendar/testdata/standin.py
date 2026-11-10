# A stand-in for Infomaniak's calendar API, for the calls and the check the
# test makes through the real yardr, and for the build command's own reads.
# It answers each request from a routes file, read again for every request,
# so one process serves every case in turn. A line of that file is
#
#   <METHOD> <path> <status> <answer file>
#
# the path without its query, the status an HTTP status, the answer file the
# path of a file whose bytes are the body. A request no line names is
# answered 404 with the service's error shape, so a request that is not the
# one expected shows in a golden. It records each request in the log it is
# given: the method, and the path and query exactly as they arrived; whether
# Authorization held the bearer token it was given; the Accept and
# Content-Type headers, and the User-Agent where it is yardr's (anything else
# is named other, since curl's differs from one machine to the next); and the
# JSON body with its keys in order of the alphabet. Any method is recorded,
# so that a DELETE or a PATCH the pack never sends shows if it ever does.
#
# The token is not in the log: it is read from the token file at the start,
# and a request is "ok" when its header is that token as a bearer, "missing"
# when it has none, "WRONG" otherwise. It writes the port it bound, on
# 127.0.0.1, to the file it is given once it listens.
#
#   python3 -I standin.py <port file> <request log> <routes file> <token file>
import http.server
import json
import os
import sys

port_file, log_file, routes_file, token_file = sys.argv[1:5]
with open(token_file) as f:
    token = f.read().strip()


def route(method, path):
    """Returns (status, body bytes) for the first line that names the request."""
    with open(routes_file) as f:
        for line in f:
            parts = line.split()
            if len(parts) == 4 and parts[0] == method and parts[1] == path:
                with open(parts[3], "rb") as answer:
                    return int(parts[2]), answer.read()
    body = {"result": "error", "error": {"code": "route_not_found", "description": "no route for %s %s" % (method, path)}}
    return 404, json.dumps(body).encode()


class Handler(http.server.BaseHTTPRequestHandler):
    def handle_any(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        header = self.headers.get("Authorization")
        if not header:
            auth = "missing"
        else:
            auth = "ok" if header == "Bearer " + token else "WRONG"
        lines = ["%s %s" % (self.command, self.path), "  auth: %s" % auth]
        for name in ("Accept", "Content-Type"):
            if self.headers.get(name) is not None:
                lines.append("  %s: %s" % (name.lower(), self.headers.get(name)))
        agent = self.headers.get("User-Agent")
        if agent is not None:
            lines.append("  user-agent: %s" % ("yardr" if agent == "yardr" else "other"))
        if raw:
            try:
                lines.append("  body: " + json.dumps(json.loads(raw), sort_keys=True, separators=(",", ":"), ensure_ascii=False))
            except ValueError:
                lines.append("  body: NOT JSON")
        with open(log_file, "a") as f:
            f.write("\n".join(lines) + "\n")
        status, body = route(self.command, self.path.split("?", 1)[0])
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_HEAD = handle_any

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
