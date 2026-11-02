# GitLab

GitLab issues and merge requests as the declared source `gitlab`. A project
webhook delivers issues, merge requests and comments to the yard, and the
yard answers in those threads: it replies, opens an issue, and closes or
reopens an issue or a merge request. Nothing here is compiled into yardr;
apply it with:

```sh
yardr pack apply /Users/mckean/projects/repos/yardr-packs/gitlab
```

from main of this repository. SETUP.md is the operator's steps.

This is the first slice. Reading a merge request and its pipelines back
(the `events` key) and the calls an agent makes (`calls`, presets) are the
next one, and running the pack against a real GitLab is the one after.

## How it hangs together

The hook in `gitlab.yaml` compares the secret token GitLab sends in
`X-Gitlab-Token` as it arrives, tells a retry by `Idempotency-Key`, and
drops a body it has seen before. The dedupe is per hook, because GitLab
sends an event's body to every webhook of the project.
`gitlab/normalize` turns each verified body into the envelope.

The sender is matched by identity, `hear: {field: sender, by: identity}`. A
delivery is kept when its sender is a user of the yard, and the hook's
`--unknown` word says what an unmapped sender gets. Usernames are the same
in any case, so the identity folds to lowercase, as GitHub's logins do.

`gitlab/thread` is the yard's side. One script serves issues and merge
requests. A thread is GitLab's own reference to one, `group/project#12` for
an issue and `group/project!12` for a merge request, and the character says
which. The project path may nest to any depth.

## What it hears

| GitLab sends | `type` | `action` | thread | text |
|---|---|---|---|---|
| Issue Hook | `issue` | `open`, `close`, `reopen`, `update` | the issue | the description |
| Merge Request Hook | `merge_request` | `open`, `close`, `reopen`, `update`, `approval`, `approved`, `unapproval`, `unapproved`, `merge` | the merge request | the description |
| Note Hook on an issue or merge request | `note` | `create`, `update` | that issue or merge request | the comment |
| Note Hook on a commit or snippet | `note` | `create`, `update` | none | the comment |
| any other hook | its `object_kind` | the action it carries, if any | none | none |

The thread's URL is the project's `web_url` and `/-/issues/<n>` or
`/-/merge_requests/<n>`, the same for a thread's own events and for its
comments, whose payloads carry the comment's URL and not the thread's. The
envelope's `url` is the comment's own for a note.

`actor.id` is the sender's username, lowercased, and it is also
`fields.sender`, which `hear` matches. The assignee is the first assignee's
username. A comment on a merge request carries the merge request's. A
comment on an issue carries ids alone, so it has none. `entity` is the
thread for an issue or merge request and `note-<id>` for a comment, so an
edit does not mention again the people it mentioned before.

The fields a subscription may filter on, beside `type`, `action`, `repo` and
`label`, are `number`, `state`, `noteable` for what a comment is on,
`sender`, and for merge requests and their comments `head_branch`,
`head_sha`, `head_repo` and `base`. `state` is GitLab's word: `opened`,
`closed`, `merged` or `locked`. `train` is the core's to derive from
`head_branch`, so no fixture sets it, and the core adds `speaker`.

A mention is an `@username` in the text, once each, in order, lowercased.
A group mention such as `@group/subgroup` is left out, because a group is not
a crew member. So are an `@name` in code and an email address. A comment on a
commit or snippet is read for its text and mentions, but it has no thread to
answer in.

A delivery of a kind this does not read is recorded with its type, action,
repo and sender, and never refused, because GitLab disables a webhook after
four failed answers in a row. A body that is no JSON object is refused with
400.

## What it says

| command | request | answer |
|---|---|---|
| `reply` | `POST /projects/<path>/issues/<n>/notes`, or under `merge_requests`, with the key as a marker comment in the body | `{id, url}` |
| `posted` | the same notes, a comment whose body holds the key's marker | `{id, url}` or `{}` |
| `read` | the same notes, oldest first, without GitLab's system notes | `{messages}` |
| `open` | `POST /projects/<path>/issues`, the key as a marker in the description; for an assignee, `GET /users?username=` first | `{id, title, url}` |
| `opened` | `GET /projects/<path>/issues?state=all`, newest first, bounded by `created_after` when `since` is given | `{id, title, url}` or `{}` |
| `state` | `GET` the issue or merge request, then `PUT` with `state_event` `close` or `reopen`, or `add_labels` | `{status, moved, was?}` |

GitLab takes no client-chosen id, so the marker is how a retry finds what an
earlier attempt left. The project path goes into the URL with its slashes
as `%2F`. Lists ask for 100 and stop on a short page, since gitlab.com can
leave out the headers that count pages.

## Where it differs from GitHub's pack

- **Quick actions.** GitLab's notes API runs a line that starts with a slash
  as a quick action, such as `/close`, `/assign` or `/approve`, and drops the
  line from the text. The same holds for an issue's description. So what an
  agent quotes from an issue could close, assign or approve as the yard. A
  reply and a description are posted with one space before any line that
  starts with a slash, which renders the same and runs nothing. It does this
  inside code blocks too, since telling a closed fence from an open one is
  GitLab's job and a wrong guess here would be a hole. Carriage returns go
  first, because GitLab removes them before it looks.
- **Merge request status.** GitHub's pack refuses a pull request's status,
  because it would close it unmerged. Here an issue and a merge request are
  both open or closed. `done` closes, `started` reopens, and a merged merge
  request stands at `done` and is never reopened. A stage map's move goes
  forward only, so it never reopens anything.
- **Replies are top-level.** A comment on an issue or merge request has no
  parent in this API, as on GitHub. GitLab's discussions would thread
  them, and that waits.
- **Order.** GitLab lists notes newest first by default, so `read` and
  `posted` ask for oldest first.
- **The token.** It goes in a `PRIVATE-TOKEN` header, to curl on its stdin
  as a config line and never as an argument. A token with a character a
  GitLab token never has is refused before anything is sent. An answer that
  repeats the token has it cut out of the message. Request bodies go to curl
  as files, not arguments, so a long reply fits.

## A known gap: issue 7 and merge request 7

GitLab numbers its issues and its merge requests apart. Issue #7 and merge
request !7 are two things in one project. The core reads the two link shapes
as one numbered thread. For an event on a thread no bead tracks, it also
looks for a bead that tracks the same number in the other shape. So a bead
that tracks issue #7 is found by an event on merge request !7 when nothing
tracks !7, and the other way round. A `says` line can then move the wrong
bead, a `makes` line for the merge request finds a tracker and makes
nothing, and the same goes for a bead that closed.

The pack declares both shapes all the same. `yardr reply` and `yardr thread
state` check an event's thread URL against them, so without the merge
request shape both are refused for a merge request. A hook with no `says` or
`makes` lines is not touched by this. The fix is an option in the core, filed
as yardr-dmfh, and this section goes when it lands.

## The secret token and the signing token

The pack checks the secret token, as the first slice's bead asks. GitLab's
docs now recommend a signing token for new webhooks, from GitLab 19.0, and
call the secret token weaker: a plain value in a header, with no check of the
body and no age. The core already verifies that signature, so a variant is a
change to `hook.verify` in `gitlab.yaml` and no more. It is filed as
yardr-packs-3rgk. The secret token stays the default until it is decided,
since every GitLab version sends it, self-managed ones older than 19.0
included.

## Not yet checked against GitLab

Everything above is held to fixtures and to a scratch yard with a stand-in
for curl. Nothing has run against a real GitLab. The live run should check
these first:

- A note's `body` comes back from the API with the HTML comment markers
  intact. `posted` and `opened` find a retry's work by them.
- A reply with a line that starts with `/close` shows its text, and does not
  close the issue.
- GitLab resolves a project path in any case, since the thread commands send
  it as a delivery spelled it, and `link` folds it to lowercase.
- An issue made with `assignee_id` on a Free project is assigned, and
  `GET /users?username=` matches a username in any case.
- The answer to creating an issue carries `references.full`, which names the
  thread's project as GitLab spells it.
- A retry or a resend from GitLab's Recent events page carries the same
  `Idempotency-Key`, and the hook answers it as a duplicate.

## Files

- `pack.yaml`, `gitlab.yaml`: the pack and its declaration.
- `gitlab/normalize`: POSIX sh and jq, the verified body to the envelope.
- `gitlab/thread`: bash, curl and jq, the thread commands.
- `testdata/hook/`: the webhook bodies and the envelopes made of them,
  goldens beside them.
- `testdata/thread/`: one directory for each case of a thread command, with
  its input, the answers the stand-in gives in order, and the requests and
  output expected. `_answers/` holds the answers they share.
- `testdata/bin/curl`: the stand-in for curl.
- `testdata/link.txt`: paths for the link patterns and what each makes.
- `test`: runs all of it.

## Runtimes

`gitlab/normalize` wants POSIX sh and jq, as the other source packs do.
`gitlab/thread` wants bash 3.2 or later, curl and jq. The gate knows no
language, so this is the pack's word for what its programs need.

## Testing

```sh
./test
```

in this directory. It feeds each webhook body to normalize and compares the
envelope with its golden byte for byte, and checks that the fields the
envelopes carry and `hook.keys` agree both ways. It runs each thread case
against the stand-in curl, which makes no request, records the method, URL,
headers and body the real one would have been asked for, answers from the
case's fixtures and refuses any use of curl the script does not make today.
A changed request fails its case. A canary token is looked for in every
argument, output and record, and has to be on curl's stdin alone. The link
patterns are run on the paths in `testdata/link.txt` through jq's regex
engine. The depot's gate runs `yardr pack check` on this directory first.

`UPDATE=1 ./test` writes the goldens again from what the programs print. Read
the diff before keeping it.

## Left out

Reading a merge request and its pipelines back, and the declared calls and
presets, are the next slice. The rest each wait for a word from mckean: git
hosting for a depot whose origin is on gitlab.com, which wants a `git`
credential helper like GitHub's; group webhooks; links and bases for a
self-managed instance, which its operator writes into a copy; work items that
are not issues, such as tasks, incidents and epics; replies into a
discussion's thread; the signing token above.
