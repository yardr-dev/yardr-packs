# A stand-in for Proton Mail Bridge's IMAP, for the proton pack's tests: a
# socket loop that answers the commands proton-imap sends and no others. The
# test starts it in a thread, on 127.0.0.1 and a port the system chooses, so
# nothing here reaches a real Bridge, a network or a secret.
#
# What it takes from Gluon, Bridge's IMAP engine (ProtonMail/gluon d871584),
# because that is what the program is written against: STARTTLS and then
# LOGIN, LIST with attributes (\All, \Sent, \Trash, \Noselect), EXAMINE with
# UIDVALIDITY, UID SEARCH with CHARSET and literals where each of FROM, TO, CC,
# BCC, SUBJECT and HEADER is a case-insensitive substring of the RAW header
# (an RFC 2047 word is not decoded) and TEXT is a substring of the raw
# message, and UID FETCH of FLAGS, INTERNALDATE, RFC822.SIZE and BODY.PEEK
# sections. Like Gluon, no LITERAL+ (a client waits for the "+"), no THREAD
# and no X-GM-THRID.
#
# What it refuses is the point of the test: anything that could change a
# mailbox or leave a trace on it (SELECT, STORE, COPY, MOVE, EXPUNGE, APPEND,
# CREATE, DELETE, RENAME, CLOSE), a body fetched with BODY[] where BODY.PEEK[]
# keeps \Seen alone, and any search key or fetch item it does not know. Each
# is answered NO or BAD and written to Stub.violations, which a test asserts is
# empty, so a read-only program is one a test can hold to it.
#
# Stub.order says where a FETCH response puts its attributes: "normal" has
# UID and FLAGS before the body literal, "after" has them after it, which a
# server may do and a parser of imaplib's answer has to take.
import datetime
import re
import socketserver
import ssl
import threading
import time

CRLF = b"\r\n"
MONTHS = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()
ALLOWED = {"CAPABILITY", "STARTTLS", "LOGIN", "LIST", "EXAMINE", "UID", "LOGOUT", "NOOP"}


class Msg:
    def __init__(self, uid, raw, flags=(), internal="03-Nov-2026 10:00:00 +0000"):
        self.uid, self.flags, self.internal = uid, list(flags), internal
        self.raw = raw.replace(b"\r\n", b"\n").replace(b"\n", CRLF)
        head, _, self.body = self.raw.partition(CRLF + CRLF)
        self.head = head + CRLF + CRLF
        self.lines = re.sub(rb"\r\n[ \t]+", b" ", head).split(CRLF)

    def header(self, name):
        """The RAW value of the first header of that name, folding undone, as Gluon's Get."""
        prefix = name.lower().encode() + b":"
        for line in self.lines:
            if line.lower().startswith(prefix):
                return line[len(prefix):].strip()
        return b""

    def fields(self, names):
        """The header block of just these fields, as BODY[HEADER.FIELDS (...)] answers."""
        keep = {n.lower().encode() + b":" for n in names}
        out, take = [], False
        for line in self.head.split(CRLF)[:-2]:
            if line[:1] in (b" ", b"\t"):
                if take:
                    out.append(line)
                continue
            take = any(line.lower().startswith(k) for k in keep)
            if take:
                out.append(line)
        return CRLF.join(out) + CRLF + CRLF

    def date(self):
        day, mon, year = self.internal.split(" ")[0].split("-")
        return datetime.date(int(year), MONTHS.index(mon) + 1, int(day))


class Mailbox:
    def __init__(self, name, attrs=(), validity=1, messages=()):
        self.name, self.attrs, self.validity, self.messages = name, list(attrs), validity, list(messages)


class Stub:
    """The server. mailboxes are Mailbox objects; user and password are what
    LOGIN must give; starttls says whether it offers STARTTLS; order is where
    a FETCH response puts its attributes; delay is seconds a UID SEARCH waits
    before it answers, for a test of the program's timeout; hang_up closes a
    connection as soon as it is made; flood answers every UID SEARCH with that
    many UIDs, of messages that are not there, to make a line too long for
    imaplib's own bound; echo makes a refused LOGIN say the password it was
    given, as a careless server might."""

    def __init__(self, mailboxes, user, password, certfile, keyfile, starttls=True, order="normal", delay=0.0, hang_up=False, flood=0, echo=False):
        self.mailboxes, self.user, self.password = mailboxes, user, password
        self.starttls, self.order, self.delay, self.hang_up, self.flood, self.echo = starttls, order, delay, hang_up, flood, echo
        self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        self.context.load_cert_chain(certfile, keyfile)
        self.lock = threading.Lock()
        self.connections = 0
        self.commands = []      # each command's verb, "UID SEARCH" for a UID one, as received
        self.logins = []        # (user, password) of each LOGIN
        self.clear_logins = 0   # LOGINs before TLS: the password sent in the clear
        self.searches = []      # {"charset": ..., "literals": n, "text": ...} per UID SEARCH
        self.violations = []
        self.port = None

    def start(self):
        class Server(socketserver.ThreadingTCPServer):
            allow_reuse_address = True
            daemon_threads = True

        self.server = Server(("127.0.0.1", 0), Handler)
        self.server.stub = self
        self.port = self.server.server_address[1]
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        return self.port

    def stop(self):
        self.server.shutdown()
        self.server.server_close()

    def note(self, verb):
        with self.lock:
            self.commands.append(verb)

    def violate(self, what):
        with self.lock:
            self.violations.append(what)

    def mailbox(self, name):
        for box in self.mailboxes:
            if box.name == name or (name.upper() == "INBOX" and box.name.upper() == "INBOX"):
                return box
        return None


class Handler(socketserver.BaseRequestHandler):
    def setup(self):
        self.stub = self.server.stub
        self.sock = self.request
        self.rfile = self.sock.makefile("rb")
        self.tls = False
        self.authed = False
        self.box = None

    def send(self, data):
        self.sock.sendall(data if isinstance(data, bytes) else data.encode())

    def line(self, text):
        self.send(text.encode() + CRLF if isinstance(text, str) else text + CRLF)

    def caps(self):
        return "IMAP4rev1 ID UIDPLUS UNSELECT MOVE IDLE AUTH=PLAIN" + (" STARTTLS" if self.stub.starttls and not self.tls else "")

    def handle(self):
        stub = self.stub
        with stub.lock:
            stub.connections += 1
        if stub.hang_up:
            return
        self.line("* OK [CAPABILITY %s] Bridge stand-in ready" % self.caps())
        while True:
            try:
                got = self.read_command()
            except (OSError, ssl.SSLError):
                return
            if got is None:
                return
            tag, verb, text, literals = got
            try:
                if self.dispatch(tag, verb, text, literals) == "bye":
                    return
            except (OSError, ssl.SSLError):
                return

    def read_command(self):
        """(tag, verb, the rest of the line with each literal as \\0<n>\\0, the literals)."""
        text, literals = b"", []
        while True:
            line = self.rfile.readline()
            if not line:
                return None
            m = re.search(rb"\{(\d+)(\+?)\}\r\n$", line)
            if not m:
                text += line.rstrip(b"\r\n")
                break
            text += line[: m.start()] + b"\x00%d\x00" % len(literals)
            if not m.group(2):
                self.line("+ Ready for literal data")
            literals.append(self.rfile.read(int(m.group(1))))
        parts = text.split(b" ", 2)
        tag = parts[0].decode("ascii", "replace")
        verb = parts[1].decode("ascii", "replace").upper() if len(parts) > 1 else ""
        return tag, verb, parts[2] if len(parts) > 2 else b"", literals

    @staticmethod
    def tokens(text, literals):
        """Atoms as str, quoted strings and literals as bytes, ( and ) as str."""
        out, i = [], 0
        while i < len(text):
            c = text[i : i + 1]
            if c == b" ":
                i += 1
            elif c in (b"(", b")"):
                out.append(c.decode())
                i += 1
            elif c == b'"':
                j, buf = i + 1, b""
                while text[j : j + 1] != b'"':
                    if text[j : j + 1] == b"\\":
                        j += 1
                    buf += text[j : j + 1]
                    j += 1
                out.append(buf)
                i = j + 1
            elif c == b"\x00":
                j = text.index(b"\x00", i + 1)
                out.append(literals[int(text[i + 1 : j])])
                i = j + 1
            else:
                j = i
                while j < len(text) and text[j : j + 1] not in (b" ", b"(", b")"):
                    j += 1
                out.append(text[i:j].decode("ascii", "replace"))
                i = j
        return out

    def dispatch(self, tag, verb, text, literals):
        stub = self.stub
        toks = self.tokens(text, literals)
        if verb == "UID" and toks:
            stub.note("UID " + str(toks[0]).upper())
        else:
            stub.note(verb)
        if verb not in ALLOWED:
            stub.violate("command %s %s" % (verb, text[:60].decode("ascii", "replace")))
            self.line("%s NO [CANNOT] this is a read-only stand-in" % tag)
            return None
        if verb == "CAPABILITY":
            self.line("* CAPABILITY %s" % self.caps())
            self.line("%s OK CAPABILITY" % tag)
        elif verb == "NOOP":
            self.line("%s OK NOOP" % tag)
        elif verb == "LOGOUT":
            self.line("* BYE logging out")
            self.line("%s OK LOGOUT" % tag)
            return "bye"
        elif verb == "STARTTLS":
            if not stub.starttls:
                self.line("%s NO TLS unavailable" % tag)
                return None
            self.line("%s OK Begin TLS negotiation now" % tag)
            self.sock = stub.context.wrap_socket(self.request, server_side=True)
            self.rfile = self.sock.makefile("rb")
            self.tls = True
        elif verb == "LOGIN":
            user, password = (t.decode() if isinstance(t, bytes) else t for t in toks[:2])
            with stub.lock:
                stub.logins.append((user, password))
                if not self.tls:
                    stub.clear_logins += 1
            if not self.tls:
                self.line("%s NO [PRIVACYREQUIRED] TLS first" % tag)
            elif (user, password) == (stub.user, stub.password):
                self.authed = True
                self.line("%s OK [CAPABILITY %s] Logged in" % (tag, self.caps()))
            else:
                self.line("%s NO [AUTHENTICATIONFAILED] Invalid credentials%s" % (tag, " for %s:%s" % (user, password) if stub.echo else ""))
        elif not self.authed:
            self.line("%s BAD not authenticated" % tag)
        elif verb == "LIST":
            for box in stub.mailboxes:
                self.line('* LIST (%s) "/" "%s"' % (" ".join(box.attrs), box.name))
            self.line("%s OK LIST" % tag)
        elif verb == "EXAMINE":
            box = stub.mailbox(toks[0].decode() if toks and isinstance(toks[0], bytes) else "")
            if box is None or "\\Noselect" in box.attrs:
                self.line("%s NO [NONEXISTENT] no such mailbox" % tag)
                return None
            self.box = box
            self.line("* FLAGS (\\Seen \\Answered \\Flagged \\Deleted \\Draft)")
            self.line("* %d EXISTS" % len(box.messages))
            self.line("* 0 RECENT")
            self.line("* OK [UIDVALIDITY %d] UIDs valid" % box.validity)
            self.line("* OK [UIDNEXT %d] Predicted next UID" % (max([m.uid for m in box.messages] or [0]) + 1))
            self.line("%s OK [READ-ONLY] EXAMINE completed" % tag)
        elif verb == "UID":
            sub = str(toks[0]).upper() if toks else ""
            if sub == "SEARCH":
                self.search(tag, toks[1:], literals)
            elif sub == "FETCH":
                self.fetch(tag, text, literals)
            else:
                stub.violate("UID %s" % sub)
                self.line("%s NO [CANNOT] this is a read-only stand-in" % tag)
        return None

    # ---- UID SEARCH ---------------------------------------------------------
    def search(self, tag, toks, literals):
        stub = self.stub
        charset = None
        if toks and isinstance(toks[0], str) and toks[0].upper() == "CHARSET":
            charset = toks[1] if isinstance(toks[1], str) else toks[1].decode()
            toks = toks[2:]
            if charset.upper() not in ("UTF-8", "US-ASCII"):
                self.line("%s NO [BADCHARSET (UTF-8 US-ASCII)] unknown charset" % tag)
                return
        with stub.lock:
            stub.searches.append({"charset": charset, "literals": len(literals),
                                  "text": " ".join(t.decode("utf-8", "replace") if isinstance(t, bytes) else t for t in toks)})
        if stub.delay:
            time.sleep(stub.delay)
        it = iter(toks)
        try:
            tests = []
            while True:
                try:
                    tests.append(self.key(it))
                except StopIteration:
                    break
        except ValueError as e:
            stub.violate("search %s" % e)
            self.line("%s BAD %s" % (tag, e))
            return
        found = [m.uid for m in self.box.messages if all(t(m) for t in tests)]
        if stub.flood:
            found = list(range(1, stub.flood + 1))
        self.line("* SEARCH" + "".join(" %d" % u for u in found))
        self.line("%s OK UID SEARCH completed" % tag)

    @staticmethod
    def string(it):
        value = next(it)
        if not isinstance(value, bytes):
            raise ValueError("search wants a string, got %r" % (value,))
        return value

    def key(self, it):
        word = next(it)
        if not isinstance(word, str):
            raise ValueError("search wants a key, got a string")
        up = word.upper()
        if up == "ALL":
            return lambda m: True
        if up in ("FROM", "TO", "CC", "BCC", "SUBJECT"):
            want = self.string(it).lower()
            return lambda m: want in m.header(up).lower()
        if up == "HEADER":
            field = next(it)
            field = field if isinstance(field, str) else field.decode()
            want = self.string(it).lower()
            return lambda m: want in m.header(field).lower()
        if up == "TEXT":
            want = self.string(it).lower()
            return lambda m: want in m.raw.lower()
        if up in ("SINCE", "BEFORE"):
            day, mon, year = next(it).split("-")
            when = datetime.date(int(year), MONTHS.index(mon) + 1, int(day))
            return (lambda m: m.date() >= when) if up == "SINCE" else (lambda m: m.date() < when)
        flags = {"SEEN": ("\\Seen", True), "UNSEEN": ("\\Seen", False), "FLAGGED": ("\\Flagged", True),
                 "UNFLAGGED": ("\\Flagged", False), "ANSWERED": ("\\Answered", True),
                 "UNANSWERED": ("\\Answered", False), "DRAFT": ("\\Draft", True), "UNDRAFT": ("\\Draft", False),
                 "DELETED": ("\\Deleted", True), "UNDELETED": ("\\Deleted", False)}
        if up in flags:
            flag, has = flags[up]
            return lambda m: (flag in m.flags) == has
        if up == "NOT":
            inner = self.key(it)
            return lambda m: not inner(m)
        if up == "OR":
            a, b = self.key(it), self.key(it)
            return lambda m: a(m) or b(m)
        raise ValueError("unknown search key %s" % word)

    # ---- UID FETCH ----------------------------------------------------------
    def fetch(self, tag, text, literals):
        stub = self.stub
        m = re.match(rb"FETCH ([0-9,:*]+) \((.*)\)\s*$", text, re.S)
        if not m:
            stub.violate("fetch %r" % text[:80])
            self.line("%s BAD fetch syntax" % tag)
            return
        wanted = self.uid_set(m.group(1).decode())
        items = m.group(2).decode("ascii", "replace")
        sections = re.findall(r"BODY(\.PEEK)?\[([^\]]*)\]", items)
        for peek, section in sections:
            if not peek:
                stub.violate("BODY[%s] without PEEK" % section)
        plain = re.sub(r"BODY(\.PEEK)?\[[^\]]*\]", "", items).split()
        for item in plain:
            if item not in ("UID", "FLAGS", "INTERNALDATE", "RFC822.SIZE"):
                stub.violate("fetch item %s" % item)
        for seq, msg in enumerate(self.box.messages, 1):
            if msg.uid not in wanted:
                continue
            attrs = ["UID %d" % msg.uid]
            if "FLAGS" in plain:
                attrs.append("FLAGS (%s)" % " ".join(msg.flags))
            if "INTERNALDATE" in plain:
                attrs.append('INTERNALDATE "%s"' % msg.internal)
            if "RFC822.SIZE" in plain:
                attrs.append("RFC822.SIZE %d" % len(msg.raw))
            bodies = []
            for _, section in sections:
                name = section.upper()
                if name == "":
                    data = msg.raw
                elif name == "HEADER":
                    data = msg.head
                elif name.startswith("HEADER.FIELDS ("):
                    data = msg.fields(name[len("HEADER.FIELDS ("):-1].split())
                else:
                    stub.violate("body section %s" % section)
                    data = b""
                bodies.append(("BODY[%s]" % section, data))
            self.respond(seq, attrs, bodies)
        self.line("%s OK UID FETCH completed" % tag)

    def respond(self, seq, attrs, bodies):
        """One FETCH response: the attributes before the literal, or after it."""
        stub = self.stub
        if not bodies:
            self.line("* %d FETCH (%s)" % (seq, " ".join(attrs)))
            return
        out = b"* %d FETCH (" % seq
        if stub.order == "normal":
            out += " ".join(attrs).encode() + b" "
        for i, (name, data) in enumerate(bodies):
            out += (b" " if i else b"") + name.encode() + b" {%d}\r\n" % len(data) + data
        if stub.order == "after":
            out += b" " + " ".join(attrs).encode()
        self.send(out + b")" + CRLF)

    @staticmethod
    def uid_set(text):
        out = set()
        for part in text.split(","):
            lo, _, hi = part.partition(":")
            if hi:
                out.update(range(int(lo), (10**9 if hi == "*" else int(hi)) + 1))
            else:
                out.add(int(lo))
        return out
