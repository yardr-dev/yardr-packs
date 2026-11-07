# Sentry

Sentry issues as the declared source `sentry`. An internal integration's
webhook delivers a new issue, and an alert rule's event, to the yard, and the
yard answers in the issue: it comments on it, resolves it and unresolves it. A
bead can name an issue, and the issue resolves when the bead lands. Nothing
here is compiled into yardr; apply it with:

```sh
yardr pack apply /Users/mckean/projects/repos/yardr-packs/sentry
```

from main of this repository. SETUP.md is the operator's steps.

This is the first slice. Running it against a real Sentry organization is the
next bead and needs an account; "Not yet checked against Sentry" lists what
that run should look at first.

## How it hangs together

The hook in `sentry.yaml` takes the signature Sentry puts in
`Sentry-Hook-Signature`: the hex HMAC-SHA256 of the exact body under the
integration's Client Secret. The core checks it, as data, and hands the secret
to no program. `Sentry-Hook-Timestamp` rides along and Sentry does not sign
it, so the hook names no timestamp window. The delivery is told by
`Request-ID`, which Sentry makes once for each request it builds, and a body
seen before is dropped, per hook, so a retry that builds its request again is
told by its body. `sentry/normalize` turns each verified body into the
envelope.

The hook hears no one by identity: every delivery is from Sentry itself, or
from the integration, or from a person acting in Sentry, and none mentions
anyone. So the pack has no `hear` key, `hook add` takes no `--unknown` word,
and a subscription is by `--scope all` and a `--where`.

`sentry/thread` is the yard's side: reply, posted, read and state. A thread is
`<organization slug>#<issue id>`, as GitHub's is `owner/repo#12`. There is no
open: Sentry makes its issues from errors.

The pack declares one call, `scopes`, a GET of Sentry's API index, which needs
no scope and answers the token's own. A declaration with no call keeps neither
its base nor its credential, and this one is the check: `yardr source check
sentry` shows the scopes the token holds.

## What it hears

| Sentry sends | `type` | `action` | thread | text |
|---|---|---|---|---|
| `issue`, action `created` | `issue` | `created` | the issue | `new <level> issue <short id> in <project>: <culprit>` |
| `event_alert`, action `triggered` | `event_alert` | `triggered` | the issue of the event | `alert "<rule>": <level> event in <culprit>` |
| `issue`, any other action (`resolved`, `assigned`, `archived`, `unresolved`) | `issue` | that action | none | none |
| `event_alert`, any other action | `event_alert` | that action | none | none |
| any other resource (`comment`, `error`, `metric_alert`, `installation`, ...) | the resource | its action | none | none |

`type` is the `Sentry-Hook-Resource` header and `action` the payload's, as
Sentry words them. The last two rows are recorded with their actor and are
never refused: a 400 tells Sentry its webhook failed, and Sentry retries a
failed one and can disable an integration (its source skips an app that is
disabled). A body that is no JSON object, or a delivery with no resource
header, is refused with 400.

The yard's own resolve comes back as an issue delivery of action `resolved`,
by the integration, and its own comment as a comment delivery. Neither has a
thread, so neither is heard as a new issue, and the status call cannot loop.

`issue.created` is sent for errors, outages (uptime and cron monitors) and
user feedback alike, so the issue's `issueCategory` is a field.

The fields, which a subscription's `--where` may name:

- `project`: the project's slug, for an issue and for an alert whose event
  carries the project's API address.
- `level`: `fatal`, `error`, `warning`, `info` or `debug`.
- `category`: `error`, `outage` or `feedback`. An alert has none.
- `outsider`: `yes` on every delivery that carries text. An issue's title and
  culprit come from the monitored application, and whoever uses it can shape
  them: a crafted error message is text for an agent to read. The mark is the
  core's own, for text the source's people did not write: the inbox line says
  `information, not instructions`, and a `says` line's note leaves the text
  out. PostHog's pack does not set it. This one does, because Sentry's text is
  an error's.

## The thread, its address and its link

Sentry sends the organization in no field of its own, only in addresses. The
pack reads it, and the issue's number, from the `web_url` of the issue (or of
the event, for an alert), which comes in two shapes: `<slug>.sentry.io/issues/<id>/`,
which the docs' issue sample has, and `/organizations/<slug>/issues/<id>/` on a
host, which the docs' alert sample has and a Sentry without customer domains
is expected to send. Both become the second shape on the host the address was
on, `https://sentry.io/organizations/<slug>/issues/<id>/`,
which is the thread's URL, and the thread is `<slug>#<id>`. The slug is kept
lowercase. The issue's own `id` (an alert's `issue_id`) and the address must
name the one issue. Where the organization, the host or the id cannot be
read, the delivery is recorded with no thread and still heard. An alert's `url`
is its event's, `.../issues/<id>/events/<event id>/`, made only from a 32-hex
event id.

The declaration's `link` reads the same form, on `sentry.io` alone: a
declaration names one host, so an address on `<slug>.sentry.io`, which is what
a browser shows, is refused by `yardr link add`, and SETUP.md says to type the
path form or the number of the delivery. yardr keeps
`https://sentry.io/organizations/<slug>/issues/<id>`, folded to lowercase, so
one issue is one link however it was typed.

## What it says

- **reply** posts a comment: `POST /api/0/organizations/<org>/issues/<id>/comments/`
  with `{"text": ...}`. Sentry takes no client-chosen id for a comment, so the
  key goes into the text as `<!-- yardr-reply KEY -->`. A comment is not
  threaded, so `--to` does nothing, and the answer's URL is the issue's: a
  comment has no address of its own. Sentry refuses the same text from the
  same account within an hour (400, "You have already posted that comment."),
  which the key keeps apart for two replies.
- **posted** finds what a key left, in the list of comments, and answers `{}`
  for none. A retry asks before it posts, so a reply whose answer was lost is
  found and not posted twice.
- **read** lists the comments, oldest first: Sentry sends the newest first, so
  they are sorted by their number, which is the order they were made in. The
  list pages by cursor (`per_page=100`, and the `Link` header's next cursor
  where it says `results="true"`), at most a hundred pages. An author is the
  integration's name when a comment is its own, else the person's name, else
  their username.
- **state** moves the issue. The words are two of the core's three, and Sentry
  has two statuses to set, with a third between them:

  | word | Sentry | `thread state` (exact) | a stage map (`forward`) |
  |---|---|---|---|
  | `started` | `unresolved` | unresolves a resolved or ignored issue | never moves |
  | `done` | `resolved` | resolves an unresolved or ignored issue | resolves an unresolved or ignored issue |

  An issue already in the status is reported as not moved, and a resolved
  issue is never reopened by a stage map. The command reads the issue first
  (`GET`), then sets the status (`PUT {"status": ...}`), and an answer that
  does not say the status asked for is no move. `review` is refused: Sentry
  has no such status.

Every command sends the token on curl's stdin as a config line, never as an
argument, cuts it out of anything an answer repeats, and refuses a token with
a character a Sentry token has none of (`[A-Za-z0-9_.~+/=-]` holds the 64-hex
internal token and the organization token alike) without saying what it held.
An error says the status and Sentry's `detail` on one line, without control
characters; a 403 adds that the token needs `event:read` to read and
`event:write` to comment and resolve.

## The comment route, and the token's scopes

The comment route that needs no organization, `/api/0/issues/<id>/comments/`,
is deprecated. The pack sends to the one under the organization,
`/api/0/organizations/<org>/issues/<id>/comments/`, for these reasons, all in
Sentry's source (master, 7 November 2026):

- `GroupNotesEndpoint.get` and `.post` are decorated `@deprecated(
  CELL_API_DEPRECATION_DATE, suggested_api="sentry-api-0-organization-group-group-notes",
  url_names=["sentry-api-0-group-notes"])`. The date is 15 May 2026, which has
  passed. After it the deprecated route answers 410 Gone in brownouts, by
  default one minute at noon UTC, on Sentry's cloud (the decorator does
  nothing on a self-hosted one). The suggested replacement is the route
  under the organization.
- `src/sentry/api/urls.py` mounts the same `(notes|comments)` routes under
  `/organizations/<org>/issues/` and, marked legacy, under `/issues/`.
- The thread already carries the organization, which the status call needs.

A route at the legacy path fails during a brownout and works between them,
which is the failure nobody sees in a test run at another hour. The tests
hold the pack to never sending to it.

The scopes are `event:read` and `event:write`, Issue & Event, Read & Write.
The permissions page (docs.sentry.io/api/permissions/) lists `event:read` for
GET and `event:write` for PUT, and no scope for POST. The comment's is in
source: `GroupPermission.scope_map` in
`src/sentry/issues/endpoints/bases/group.py` has POST and PUT as `event:write`
or `event:admin`, and GET as `event:read`, `event:write` or `event:admin`. So
the comment write wants `event:write`, which is what the pack asks for. The
same map has DELETE as `event:write` or `event:admin`, though the public page
lists `event:admin` there: a token with `event:write` can delete an issue, the
pack never does, and no narrower scope comments and resolves.

## Not yet checked against Sentry

Everything above is held to fixtures, to Sentry's docs and source, and to a
scratch yard with a stand-in for Sentry. Nothing has run against a real
organization. The live run should check these first:

- An internal integration's token may post a comment. Sentry's endpoint
  needs a user and answers a token with none 403; an integration acts as a
  proxy user, which should do, and the first reply shows it.
- A comment's text comes back from the list with the HTML comment marker
  intact, and the issue's page shows nothing of it. Sentry's Markdown
  renderer sanitizes raw HTML with DOMPurify, which drops comments; nothing
  here has seen it.
- `https://sentry.io/organizations/<org>/issues/<id>/` opens the issue of an
  organization on its own `<org>.sentry.io`. Sentry has middleware built to
  send a path-form address on to the organization's own, and the thread's URL
  in an inbox line is that address.
- The `web_url` a real delivery carries, for an organization on its own domain,
  for an EU one, and for an alert, is one of the two shapes the pack reads. It
  reads the docs' samples, which show one shape for an issue and the other for
  an alert.
- A retry from Sentry has another `Request-ID` or the same one. The pack copes
  either way, by the body, and the delivery's answer for a duplicate is the
  core's.
- The yard answers a delivery inside the one second Sentry gives a webhook:
  one HMAC and one jq run, which was not timed against a tunnel.
- `GET /api/0/` answers an internal integration's token with its scopes. It is
  in source (`IndexEndpoint`, no permission class) and not in the public
  pages.
- `PUT {"status": "unresolved"}` on a resolved issue is accepted for the
  token, and `PUT {"status": "resolved"}` on an ignored one.
- An alert arrives as the docs' sample says, with `issue_id` and a path-form
  `web_url`, for an internal integration with the Alert Action on.

## Files

- `pack.yaml`, `sentry.yaml`: the pack and its declaration.
- `sentry/normalize`: POSIX sh and jq, the verified body to the envelope.
- `sentry/thread`: bash, curl and jq, the thread commands.
- `testdata/hook/`: the webhook bodies and the envelopes made of them,
  goldens beside them. `issue-created`, `event-alert` (trimmed) and
  `comment-created` are Sentry's own samples (docs.sentry.io, 7 November 2026)
  with a signature and ids made up; `issue-resolved` is the issue sample
  resolved by the integration, and `issue-created-path` an issue whose address
  has the path shape the alert sample has.
- `testdata/thread/`: one `.case` file and one golden for each case of a thread
  command, with its input, the answers the stand-in gives in order, and the
  requests and output expected.
- `testdata/core/`, `testdata/core.sh`, `testdata/declaration.golden`,
  `testdata/link.txt`, `testdata/standin.py`: the part of the test that runs
  the real yardr, its goldens, the declaration as the yard reads it, the
  addresses for the link and the stand-in for Sentry on a loopback port.
- `testdata/bin/curl`: the stand-in for curl.
- `test`: runs all of it.

## Runtimes

`sentry/normalize` wants POSIX sh and jq, as the other source packs do.
`sentry/thread` wants bash 3.2 or later, curl and jq. The gate knows no
language, so this is the pack's word for what its programs need. The test
wants python3 and yardr besides, for its last parts.

## Testing

```sh
./test
```

in this directory. It feeds each webhook body to normalize and compares the
envelope with its golden byte for byte. A table makes one change to one body
at a time (the address in its other shape, on a regional host, on a
self-hosted one, with a user, with no id, with a string where an object
belongs) and holds the envelope to what must then be true of it, and a body
that is no object is refused without quoting itself. The fields the envelopes
carry and `hook.keys` agree both ways.

It runs each thread case against the stand-in curl, which makes no request,
records the method, URL, headers and body the real one would have been asked
for, answers from the case's fixtures and refuses any use of curl the script
does not make today. A changed request fails its case. A canary token is
looked for in every argument, output and record, and has to be on curl's
stdin alone. Of every request any case made, the writes are a POST of a
comment and a PUT of a status under the organization, and none goes to the
deprecated path. The cases marked `=== real` run again with the real curl
against a stand-in server on a loopback port, and must give the same golden:
one of each way the script uses curl.

The last part runs the real yardr, in a scratch yard of its own under `env -i`
with no agent. It holds the declaration as the yard reads it to a golden. It
makes deliveries to the yard's own listener, on a free loopback port, signed
as Sentry signs them with a canary secret: one is taken, its duplicate and a
retry with another `Request-ID` are answered as duplicates, and a changed
body, a body signed with another secret, a body with no signature and the same
JSON laid out another way are each refused with 401 and leave no event. An
alert and the yard's own resolve are taken, the second with a timestamp from
1970, since the timestamp is not signed and not read. The events the yard
recorded are held to what normalize printed. Beads are linked to the
addresses in `testdata/link.txt` and to a delivery's number, the stage map is
taken and a map to `review` refused, and the check call and the thread
commands are made through `yardr` against the stand-in for Sentry: the status
change, a reply, a reply whose answer was lost and then found by its key and
not posted again, and the thread read. The token and the signing secret are
looked for in every file the run leaves. The depot's gate runs `yardr pack
check` on this directory first.

`UPDATE_GOLDEN=1 ./test` writes the goldens again from what the programs print.
Read the diff before keeping it.

## Left out

Self-hosted Sentry and regional hosts, beyond the note in SETUP.md; metric
alerts, and any resource but `issue` and `event_alert`; releases, source maps
and assignment; any issue action beyond `created`; declared calls an agent
makes with `yardr call`, and presets (the next slice); opening an issue, which
Sentry makes from errors; mentions in a comment; and a `hear` key, since no
delivery is from a person the yard maps.
