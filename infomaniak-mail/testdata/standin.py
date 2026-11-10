# A stand-in for Infomaniak's mail API, for the check and the calls the test
# makes through the real yardr. It answers every request with the body and
# status the test has left in its answer files, read again for each request,
# so one process serves every case in turn. It records each request in the
# log it is given: the method, and the path and query exactly as they
# arrived, whether Authorization held the bearer token the test typed into the
# scratch yard (ok, WRONG for another token, missing for none), the Accept,
# Content-Type and User-Agent headers, and the JSON body with its keys in
# order. Any method is recorded, so that a request that is not the one
# expected shows in a golden.
#
# The token is not in the log: it is read from the token file, where the test
# wrote it, and compared there. It writes the port it bound, on 127.0.0.1, to
# the file it is given once it listens.
#
#   python3 -I standin.py <port file> <request log> <answer file> <token file>
#
# The status is the first line of <answer file>.status, 200 if there is no
# such file.
import http.server
import json
import os
import sys

port_file, log_file, answer_file, token_file = sys.argv[1:5]
with open(token_file) as f:
    token = f.readline().strip()


def bearer(header):
    """Returns "ok", "WRONG" or "missing"."""
    if not header or not header.startswith("Bearer "):
        return "missing"
    return "ok" if header[len("Bearer "):] == token else "WRONG"


class Handler(http.server.BaseHTTPRequestHandler):
    def handle_any(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        lines = ["%s %s" % (self.command, self.path), "  auth: %s" % bearer(self.headers.get("Authorization"))]
        for name in ("Accept", "Content-Type", "User-Agent"):
            if self.headers.get(name) is not None:
                lines.append("  %s: %s" % (name.lower(), self.headers.get(name)))
        if raw:
            try:
                lines.append("  body: " + json.dumps(json.loads(raw), separators=(",", ":")))
            except ValueError:
                lines.append("  body: NOT JSON")
        with open(log_file, "a") as f:
            f.write("\n".join(lines) + "\n")
        status = 200
        if os.path.exists(answer_file + ".status"):
            with open(answer_file + ".status") as f:
                status = int(f.readline())
        with open(answer_file, "rb") as f:
            body = f.read()
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
