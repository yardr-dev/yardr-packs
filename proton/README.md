# proton

Proton Mail, read only. A yard can search the operator's mail, read a message and read the thread a message is in, as `yardr call proton search|message|thread`. These are the same three reads the `google-mail` source gives. The pack sends no mail, writes no draft and sets no flag.

Proton offers no public API for mail, so the pack reads it through [Proton Mail Bridge](https://proton.me/mail/bridge), which runs on the yard's machine and serves the account over IMAP on a loopback port. The pack declares the source `proton` and carries a program, `proton-imap`, that answers each call by talking IMAP to Bridge. yardr runs the program (a call's `run`; see "A call may be answered by a command" in `yardr docs integrations`). The program needs Python 3.9 or newer and nothing else. [SETUP.md](SETUP.md) lists what the operator sets up. `.yardr/test` runs `yardr pack check` and this pack's `test`.

| file | what it is |
| --- | --- |
| `pack.yaml` | the pack: kind `source`, the source it declares, one suggested preset (`read`) |
| `proton.yaml` | the source: Bridge's default address, one credential, three read calls each run by `proton-imap` |
| `proton-imap` | the program: `proton-imap search\|message\|thread`, parameters on stdin, one JSON object out |
| `SETUP.md` | what the operator does: Bridge, the pack, the login, the grant, a first call |
| `test`, `testdata/` | the pack's tests, a stand-in for Bridge, its mail and the goldens |

## The calls

All three are reads, and `read` grants them together. The yard shows each answer as data from outside the yard. Mail is whatever anyone sent the account, so it carries no instruction.

**`search`** takes `q` (optional) and `maxResults` (1 to 50, and 20 if left out). It answers:

- `mailbox`, the mailbox it read.
- `messages`, newest first. Each has `id`, `from`, `subject`, `date` and `flags`. `date` is ISO 8601 with the message's own offset. `flags` are IMAP's, such as `\Seen`, and a message without `\Seen` is unread.
- `resultSizeEstimate`, how many messages matched. The count is exact, because IMAP returns every match.

"Newest" means the order messages reached the mailbox, which is Bridge's UID order. That matches date order, except for mail Bridge synchronized out of order.

**`message`** takes `id` and `format`, which is `metadata` (the default) or `full`. `metadata` answers the headers: `id`, `mailbox`, `flags`, `from`, `to`, `cc`, `subject`, `date`, `messageId`, `inReplyTo`, `references` and `size`. A header the message lacks is left out. `full` adds two things. `text` is the plain part, or the HTML part with its tags, styles and scripts removed, cut at about 48 KB with `truncated: true`. `attachments` lists the first 100, each with `name`, `type` and `size`, and never the contents. `full` refuses a message over 25 MB, and `metadata` still reads it.

**`thread`** takes the `id` of any message in the thread, and `format` as `message` does. It answers `id` as asked, `threadId` (the Message-ID of the thread's root) and `messages`, oldest first. Each message has the shape `message` gives, without `mailbox` and `references`. With `full`, the messages share one 48 KB budget of text, and a message whose text was cut says `truncated: true`. A thread has at most 50 messages: the newest, plus the one asked about. `omitted` says how many were left out.

An answer is at most 60 KB, under the 64 KB a command may print. Each call stops after 25 seconds, before the yard's 30-second kill, so a failure arrives as a message from the program.

### Ids

A message id is `<mailbox>:<UIDVALIDITY>:<UID>`, with the mailbox name percent-encoded: `INBOX:1111:42`, `All%20Mail:2222:107`. IMAP needs exactly that to find a message again, so `message` and `thread` take nothing else. Bridge gives a mailbox a new UIDVALIDITY when it rebuilds its copy, and after that an old UID may point at another message. The program refuses such an id as stale, and the caller searches again.

### `q`

`q` is a Gmail-like subset that the program turns into IMAP SEARCH keys. It is not raw IMAP. Agents know Gmail's operators, and `google-mail`'s `q` uses them. Every term must match. A term is `operator:value` (`subject:report`, `subject:"quarterly report"`), a word, or a `"phrase"` in quotes. A `-` in front of a term leaves it out.

| operator | means |
| --- | --- |
| `from:` `to:` `cc:` `bcc:` | the header contains the text |
| `subject:` | the subject contains the text |
| `after:` `before:` | received on or after, or before, a date such as `2026-10-01` or `2026/10/01` |
| `newer_than:` `older_than:` | received within, or more than, a span ago: a count and `d`, `w`, `m` (30 days) or `y` (365 days), such as `7d` or `1y` |
| `is:` | `unread`, `read`, `starred` (or `flagged`), `answered`, `draft` |
| `in:` `label:` | the mailbox to search: `inbox`, `sent`, `drafts`, `trash`, `spam`, `archive`, `starred`, `all`, a name as the answer's `mailbox` gives it (`Folders/Work`), or the last path part of a name when only one mailbox ends that way (`Receipts` finds `Labels/Receipts`) |
| a word, or a `"phrase"` | the text appears anywhere in the message |

Without `in:`, the search reads the mailbox Bridge lists with the `\All` attribute, which is All Mail. If the operator hid All Mail in Bridge, it reads the inbox. The answer's `mailbox` says which.

Bridge lists mailbox names in IMAP's modified UTF-7, so `Café` appears as `Caf&AOk-`. Ids and the answer's `mailbox` use that form too.

The program refuses an operator it does not know, such as `has:attachment`, and lists the ones it knows. It does this before it connects. To search for such a word as text, put it in quotes. `OR`, brackets and braces are not supported and count as words.

**What Bridge's search does.** This comes from Gluon's source (see "What was checked"), and it shapes what an agent should expect. Bridge matches against raw text. `from:`, `to:`, `cc:`, `bcc:`, `subject:` and bare words are case-insensitive substring matches on the raw header or message. Bridge does not decode an RFC 2047 word (`=?UTF-8?B?...?=`) first, and most accented subjects and names are sent that way. So `subject:café` can miss a message whose subject shows as "Café", while `from:alice@example.com` matches. A word inside a base64 part is never found. Each of these searches also makes Bridge read every message in the mailbox from its own store, so the time grows with the mailbox. `in:` and the date operators are answered without opening a message, so they keep a search quick. A string with an accent goes to Bridge as a literal under `CHARSET UTF-8`, which Gluon accepts. A search that takes more than 20 seconds fails with "Bridge did not answer in time".

### Thread

Bridge has no thread of its own. Gluon advertises only `IMAP4rev1 UNSELECT UIDPLUS MOVE ID IDLE AUTH=PLAIN STARTTLS`. It has no Gmail extension, so no `X-GM-THRID`, and no `THREAD`, `SORT` or `ESEARCH`. The program builds a thread from `References` and `In-Reply-To`, as mail clients do.

1. The thread's root is the first id in `References`, else the id in `In-Reply-To`, else the message itself.
2. One search finds every message whose `Message-ID`, `In-Reply-To` or `References` names the message or the root. That gives the root, its replies and the message's own replies.
3. The search runs in All Mail, which holds mail from every folder and from Sent. Where All Mail is hidden, it runs in the message's own mailbox. A message in the trash or spam is not in All Mail, so its thread comes from that mailbox, as far as that mailbox has it.

A message without a `Message-ID` is a thread of itself. The program never uses subjects, so two unrelated messages with the same subject are two threads. A reply whose `References` a client cut is not found.

## What it does not do

It sends no mail and writes no drafts. An update call could follow once reads are trusted, but yardr refuses an update that a command answers today. It changes no flags and moves or deletes nothing. It does not hear new mail into the inbox, because Bridge sends nothing out. A check on a timer is a later bead. It reads no attachment contents, only names, types and sizes. It does not use Proton's own web API, only what Bridge shows a mail client.

## How it keeps to that

`proton-imap` sends five commands and no others: `LIST`, `EXAMINE` (which opens a mailbox read-only; the program never sends `SELECT`), `UID SEARCH`, `UID FETCH` of `BODY.PEEK` sections, and `LOGOUT`. One class, `Bridge`, is the only code that touches the connection. The test's stand-in for Bridge answers every other command with `NO` and fails the test, so an edit that sends `STORE`, or fetches a body without `PEEK`, shows at once.

The connection uses STARTTLS before the login, and the program never sends the login in the clear. The test's stand-in refuses a clear login and counts it. Bridge makes itself a self-signed certificate that no client can verify. The program skips certificate checks only where the connection cannot leave the machine: an address in `127.0.0.0/8`, `::1`, or the name `localhost`. It decides without looking up any name. Any other host is verified the way the system verifies every server. What remains is a program of another user on the same machine that listens on Bridge's port while Bridge is not running and collects the login. That password opens Bridge on this machine and nothing else, and Proton's own password is never in it. The program does not speak Bridge's SSL connection mode, so leave IMAP on STARTTLS, which is the default.

`PROTON_BRIDGE` holds `<username>:<password>` as Bridge shows them for the account, split at the first colon. The password is Bridge's own, not the Proton password. The yard gives it to the program in its environment, and the program sends it only to Bridge's login. A failure prints one line, with Bridge's words flattened to one line, and the test searches every output for the password.

The base is `http://127.0.0.1:1143`, Bridge's default address. It says `http://` because yardr accepts only `https://`, or `http://` to this machine, as a source's address, and refuses `imap://`. The program reads the host and port from it and ignores the scheme. [SETUP.md](SETUP.md) shows how to give the yard's copy another port. The source's check call is `search`, the one call with no required parameter. `yardr source check proton` and `yardr doctor --try` make it with no query, so a Bridge that is not running or a login it refuses shows there and not at the first call an agent makes.

## What was checked

- Gluon, Bridge's IMAP engine (ProtonMail/gluon `d871584`, read on 7 November 2026): what it advertises, how `SEARCH` matches, how it parses quoted strings and literals, how it writes LIST and FETCH responses, and that it has no thread extension.
- proton-bridge (`36d7b6a`): the `\All` mailbox, the `Folders/` and `Labels/` names, the default port, and that its certificate is RSA 2048.
- The program and the declaration, against a stand-in for Bridge (`testdata/bridge_stub.py`). The stand-in does STARTTLS with a certificate that `openssl` makes for each run, matches search the way Gluon does, speaks literals, and refuses anything that could change a mailbox.
- The real yardr in a scratch yard, against the same stand-in, through `yardr call`.
- Python 3.9 (the macOS system Python) and 3.14.

**Not checked: a live Bridge.** The stand-in follows Gluon's source, not a running Bridge's answers. The first call against a real Bridge is therefore the real check. Look at how it greets, what `LIST` returns (the program relies on the `\All`, `\Sent`, `\Trash`, `\Junk` and `\Archive` attributes), the `UIDVALIDITY` values, how long a search of a large mailbox takes, and how an old message's headers and parts look. A difference there is a bug in this pack, not in Bridge.

## The tests

Run `./test` in this directory, or `sh .yardr/test` from the repository, which also runs `yardr pack check`. The test needs `openssl` (for the stand-in's throwaway certificate), `yardr` and Python 3.9 or newer, and it fails if any is missing instead of skipping. It needs no network and no secret, never touches a live Bridge, and takes under half a minute. It has four parts, cheapest first:

1. The program's own functions, called in the test's process. They cover the query translator (tables of what each `q` becomes and is refused for), how a search with accents splits into commands, which hosts skip certificate checks, the parsers for imaplib's answers, HTML to text, the 60 KB bound, the deadline and the timeout.
2. The program as a process, run the way the yard runs it, against the stand-in. This covers each call's answer (in goldens where the shape matters), big, odd and missing mail, each way a call fails, and an audit of every command the stand-in saw.
3. The test itself, run again as a process that dies after its temp dir is made. The copy gets an `openssl` that fails, so it exits at the certificate, and the test checks that it removed its temp dir. That holds the test to cleaning up on every exit, not only after its last line.
4. The real yardr in a scratch yard. It applies the pack from this directory, reads the declaration back, runs the grants SETUP.md teaches exactly as written, and makes each call through `yardr call`, comparing the answer with what the program gives on its own.

`UPDATE_GOLDEN=1 ./test` rewrites the goldens in `testdata/golden/` from what the program prints. Read the diff before you keep it.
