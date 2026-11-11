# A stand-in for Postiz's public API, for the check and the calls the test
# makes through the real yardr. It answers every request with the body and
# status the test has left in its answer files, read again for each request,
# so one process serves every case in turn. It records each request in the
# log it is given: the method, and the path and query exactly as they
# arrived, whether Authorization held the bare API key the test typed into
# the scratch yard (ok, WRONG for another value, missing for none), the
# Accept, Content-Type and User-Agent headers, and the body: a JSON body with
# its keys in order, a multipart upload as its fields and parts, anything
# else as NOT JSON. Any method is recorded, so that a request that is not the
# one expected shows in a golden.
#
# A multipart upload is logged part by part, sorted by name: a text field as
# its value, a file as its name, type, size and sha256, never its bytes. The
# yard's boundary is random per request and is left out, so the log is stable.
#
# The key is not in the log: it is read from the token file, where the test
# wrote it, and compared there. It writes the port it bound, on 127.0.0.1, to
# the file it is given once it listens.
#
#   python3 -I standin.py <port file> <request log> <answer file> <token file>
#
# The status is the first line of <answer file>.status, 200 if there is no
# such file.
import email.parser
import email.policy
import hashlib
import http.server
import json
import os
import sys

port_file, log_file, answer_file, token_file = sys.argv[1:5]
with open(token_file) as f:
    token = f.readline().strip()


def auth(header):
    """Returns "ok", "WRONG" or "missing": the key goes bare, no Bearer."""
    if not header:
        return "missing"
    return "ok" if header == token else "WRONG"


def multipart_lines(content_type, raw):
    """The upload's parts, sorted by name, or None when it is no upload."""
    prefix = "multipart/form-data;"
    if not content_type.startswith(prefix):
        return None
    head = ("Content-Type: %s\r\nMIME-Version: 1.0\r\n\r\n" % content_type).encode()
    msg = email.parser.BytesParser(policy=email.policy.default).parsebytes(head + raw)
    if msg.get_content_type() != "multipart/form-data" or msg.defects:
        return None
    parts = []
    for part in msg.iter_parts():
        name = part.get_param("name", header="content-disposition")
        filename = part.get_filename()
        payload = part.get_payload(decode=True)
        if payload is None:
            return None
        if filename is None:
            try:
                text = payload.decode("utf-8")
            except UnicodeDecodeError:
                return None
            parts.append("  field: %s=%s" % (name, text))
        else:
            digest = hashlib.sha256(payload).hexdigest()
            parts.append(
                "  part: %s filename=%s type=%s size=%d sha256=%s"
                % (name, filename, part.get_content_type(), len(payload), digest)
            )
    return sorted(parts)


class Handler(http.server.BaseHTTPRequestHandler):
    def handle_any(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        lines = ["%s %s" % (self.command, self.path), "  auth: %s" % auth(self.headers.get("Authorization"))]
        for name in ("Accept", "Content-Type", "User-Agent"):
            value = self.headers.get(name)
            if value is not None:
                if name == "Content-Type" and value.startswith("multipart/form-data;"):
                    # The boundary is random per request; the parts below pin the upload.
                    value = "multipart/form-data"
                lines.append("  %s: %s" % (name.lower(), value))
        if raw:
            parts = multipart_lines(self.headers.get("Content-Type") or "", raw)
            if parts is not None:
                lines.extend(parts)
            else:
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
