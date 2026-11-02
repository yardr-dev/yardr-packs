# A stand-in for Jira's REST API, for the one call the test makes through
# the real yardr (the source's check call). It serves GET /rest/api/3/myself
# from the file it is given and 404 for anything else, records each request
# (method, path, whether Authorization was the Basic value expected, Accept)
# in the log it is given, and writes the port it bound, on 127.0.0.1, to the
# file it is given once it listens.
#
#   python3 -I standin.py <port file> <request log> <myself answer> <expected Basic value>
import http.server
import sys

port_file, log_file, myself_file, expected = sys.argv[1:5]
with open(myself_file, "rb") as f:
    myself = f.read()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        auth = "ok" if self.headers.get("Authorization") == "Basic " + expected else "WRONG"
        with open(log_file, "a") as f:
            f.write("%s %s\n  auth: %s\n  accept: %s\n" % (self.command, self.path, auth, self.headers.get("Accept")))
        if self.path == "/rest/api/3/myself":
            status, body = 200, myself
        else:
            status, body = 404, b'{"errorMessages":["the stand-in serves /rest/api/3/myself alone"]}'
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
