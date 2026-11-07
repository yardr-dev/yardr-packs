# A stand-in for Sentry's REST API, for the second pass of the thread cases:
# the same cases the stand-in curl answers, answered over loopback to the real
# curl, so that what the stand-in curl accepts is shown to be what curl does.
#
# It serves one case at a time, as a case's directory holds it: the nth
# request since the test last set the case gets answer_n, whose first line is
# the status and the rest the body, and headers_n for the response headers
# (a raw header block, as curl -D writes it; the status line and a blank line
# in it are skipped). A request with no answer for it gets 599, as the
# stand-in curl's does. It records each request in the same words as the
# stand-in curl: the method and the address as it arrived, whether the
# credential was the one expected, the Content-Type, and the body as sorted
# compact JSON.
#
# It writes the port it bound, on 127.0.0.1, to the file it is given once it
# listens. The token it expects is the first line of its standard input and
# not an argument, which anyone on the machine could read.
#
#   python3 -I standin.py <state dir> < <expected token>
#
# The state dir holds, written by the test: case (the case's directory),
# port (written here) and requests (the log, emptied by the test between
# cases). n is the count of requests of the case, kept here and removed by
# the test.
import http.server
import json
import os
import sys

state = sys.argv[1]
expected = sys.stdin.readline().strip()


def read(name, default=""):
    try:
        with open(os.path.join(state, name), encoding="utf-8") as f:
            return f.read()
    except OSError:
        return default


class Handler(http.server.BaseHTTPRequestHandler):
    def handle_any(self):
        case = read("case").strip()
        n = int(read("n", "0") or 0) + 1
        with open(os.path.join(state, "n"), "w") as f:
            f.write(str(n))
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length).decode("utf-8") if length else ""
        got = self.headers.get("Authorization")
        if got == "Bearer " + expected:
            auth = "ok"
        elif got is None:
            auth = "missing"
        else:
            auth = "WRONG"
        lines = ["%s http://127.0.0.1:%s%s" % (self.command, self.server.server_address[1], self.path), "  auth: %s" % auth]
        if self.headers.get("Content-Type"):
            lines.append("  header: Content-Type: %s" % self.headers["Content-Type"])
        if body:
            try:
                shown = json.dumps(json.loads(body), sort_keys=True, separators=(",", ":"), ensure_ascii=False)
            except ValueError:
                shown = "NOT JSON"
            lines.append("  body: %s" % shown)
        with open(os.path.join(state, "requests"), "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

        status, answer, headers = 599, '{"detail":"the stand-in has no answer for this request"}', []
        path = os.path.join(case, "answer_%d" % n)
        if case and os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                first, _, rest = f.read().partition("\n")
            status, answer = int(first), rest
            hpath = os.path.join(case, "headers_%d" % n)
            if os.path.exists(hpath):
                with open(hpath, encoding="utf-8") as f:
                    for raw in f.read().splitlines():
                        name, sep, value = raw.partition(":")
                        if sep and not raw.startswith("HTTP/"):
                            headers.append((name.strip(), value.strip()))
        data = answer.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = handle_any

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(os.path.join(state, "port"), "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
