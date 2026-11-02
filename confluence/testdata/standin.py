# A stand-in for Confluence Cloud's REST API, for the calls the test makes
# through the real yardr. It answers every request with the body and status
# the test has left in its answer files, read again for each request, so
# one process serves every case in turn. It records each request in the log
# it is given: the method, the path and query exactly as they arrived,
# whether Authorization was the Basic value expected, and Accept. Any
# method is recorded, so that a request that is not a GET shows in a
# golden. It writes the port it bound, on 127.0.0.1, to the file it is
# given once it listens. The Basic value it expects is the first line of its
# standard input and not an argument, which anyone on the machine could read.
#
#   python3 -I standin.py <port file> <request log> <answer file> < <expected Basic value>
#
# The status is the first line of <answer file>.status, 200 if there is no
# such file.
import http.server
import os
import sys

port_file, log_file, answer_file = sys.argv[1:4]
expected = sys.stdin.readline().strip()


class Handler(http.server.BaseHTTPRequestHandler):
    def handle_any(self):
        auth = "ok" if self.headers.get("Authorization") == "Basic " + expected else "WRONG"
        with open(log_file, "a") as f:
            f.write("%s %s\n  auth: %s\n  accept: %s\n" % (self.command, self.path, auth, self.headers.get("Accept")))
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
