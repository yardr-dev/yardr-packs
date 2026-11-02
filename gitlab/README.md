# GitLab

GitLab issues and merge requests as the declared source `gitlab`. A project
webhook delivers issues, merge requests, comments and pipelines to the yard,
and the yard answers in those threads: it replies, opens an issue, and closes
or reopens an issue or a merge request. It also reads a merge request and its
CI back, and an agent can ask GitLab questions through declared reads.
Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /Users/mckean/projects/repos/yardr-packs/gitlab
```

from main of this repository. SETUP.md is the operator's steps.

This is the second slice. The first heard GitLab and spoke in its threads.
This one reads a merge request and its pipelines back (the `events` key) and
declares the calls an agent makes (`calls`, and the `read` preset). Running
the pack against a real GitLab is the next one.

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

`gitlab/mr` reads a merge request back. Its `pr` command answers the head,
base and state of a merge request, and its `ci` command the state of its CI.
The declaration names them as `events.pr` and `events.ci`. Both only send
GETs.

## What it hears

| GitLab sends | `type` | `action` | thread | text |
|---|---|---|---|---|
| Issue Hook | `issue` | `open`, `close`, `reopen`, `update` | the issue | the description |
| Merge Request Hook | `merge_request` | `open`, `close`, `reopen`, `update`, `approval`, `approved`, `unapproval`, `unapproved`, `merge` | the merge request | the description |
| Note Hook on an issue or merge request | `note` | `create`, `update` | that issue or merge request | the comment |
| Note Hook on a commit or snippet | `note` | `create`, `update` | none | the comment |
| Pipeline Hook | `pipeline` | none | the merge request it ran for, if it ran for one | `pipeline <status> on <branch>` |
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
`closed`, `merged` or `locked`. A pipeline carries `conclusion`, and
`number`, `head_branch`, `head_sha`, `head_repo` and `base` where it ran for a
merge request. `train` is the core's to derive from `head_branch`, so no
fixture sets it, and the core adds `speaker`.

A pipeline is a run of CI (`events.runs`), and a merge request's own events
tell its head (`events.head_from`). GitLab sends a Pipeline Hook at each
change of a pipeline's status, so one pipeline makes several events. Only the
last has a `conclusion`, in the words the core judges CI by: `success`,
`failure`, `cancelled` or `skipped`. A pipeline that is created, pending,
running, blocked on a manual job or being canceled has none.

The thread of a pipeline is read from the merge request's own URL in the
payload, not from the project the pipeline ran in. For a merge request,
`repo` names the target project from that URL, so the core can match the
event to the merge request by repo and number. `head_repo` names the pipeline
project when the pipeline ran in the source fork; the core uses it to check
that the event's head belongs to the train's merge request. If the fork's
pipeline ran in the target project, the payload does not give the source
path, so `head_repo` is left out. A pipeline that ran for no merge request
keeps the pipeline project's `repo`, has no thread and no `number`; its
`head_branch` still finds a train.
A merged results or merge train pipeline has no `head_sha`: its commit is
one GitLab made of the merge request and its target branch, not the head, so
the core leaves the run alone ("no head_sha").

The hook drops a delivery whose sender is a crew member's own account (the
core's rule for the yard's echo, after `yardr crew identity`). So a pipeline
that ran as the yard's account is not an event, and neither is a merge request
event of its own. The `pr` and `ci` reads are what cover the yard's own merge
requests; events cover other people's.

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

## What it reads back

| command | request | answer |
|---|---|---|
| `pr` | `GET /projects/<path>/merge_requests/<n>` | `{head, base, state}` |
| `ci` | the same, then `GET /projects/<path>`, then the jobs of the head pipeline: `GET /projects/<id>/pipelines/<id>/jobs`, 100 to a page | `{head, base, state, required, checks}` |

The daemon asks `pr` for the head of a merge request when no event has told
it, and `ci` for a train whose hook has an `event=ci` line; the train's brief
carries the same snapshot. `head` is the merge request's `sha` and `base` its
`target_branch`. `state` is GitLab's word except for `opened`, which becomes
`open` because the core asks whether the state is `open`; `closed`, `merged`
and `locked` pass as they are. `pr` also takes the merge request's address in
`url` when `repo` and `number` are not given. Either command fails, with
GitLab's own message, when a request fails or the answer holds no head or
base. The core logs that and asks again later.

GitLab keeps no list of the checks a branch requires. It gates a merge on the
head pipeline of the merge request, and only where the project requires
pipelines to succeed (`only_allow_merge_if_pipeline_succeeds`). So `ci`
reports the pipeline as one check named `pipeline`, and `required` is
`["pipeline"]` where the project requires it and empty where it does not. The
jobs of the pipeline, the latest attempt of each, follow as checks with the
names they have in GitLab. A project with nothing required is never called
green, and a red check still counts. A project answer without those settings
counts as one with nothing required.

The checks speak the tongue the core judges: completed or not, and a
completed one concluded `success`, `neutral`, `skipped`, `failure` or
`cancelled`.

| GitLab says | status | conclusion |
|---|---|---|
| `success` | `completed` | `success` |
| `failed` | `completed` | `failure`, or `neutral` for a job that GitLab lets fail |
| `canceled` | `completed` | `cancelled`, which the core reads as not run yet |
| `skipped` | `completed` | `skipped`. For the pipeline, only where the project lets a skipped pipeline merge (`allow_merge_on_skipped_pipeline`); otherwise `status` is `skipped`, which the core also reads as not run |
| any other (`created`, `pending`, `running`, `manual`, ...) | GitLab's word | none |

The checks are those of the head pipeline, and only when the merge request's
head is the commit asked about and the pipeline ran on it, or is a merged
results pipeline of the merge request (its `ref` is
`refs/merge-requests/<n>/merge`). For any other commit there are none, and
the core waits ("pipeline (not reported)"). The jobs are read from the
project the pipeline names, since a fork's pipeline runs in the fork; a token
that cannot read that project fails the read. Trigger jobs, the ones that
start a downstream pipeline, are not listed as checks. The core takes an
answer of 64 KB at most. A check is about
150 bytes, so a pipeline of more than 400 jobs makes an answer the core
refuses, and the read fails.

## What an agent may ask

Six reads, all GET, which an agent makes with `yardr call gitlab <call>` once
the operator grants them:

| call | parameters | request |
|---|---|---|
| `user` | none | `GET /user` |
| `project` | `project` | `GET /projects/<project>` |
| `merge_request` | `project`, `iid` | `GET /projects/<project>/merge_requests/<iid>` |
| `pipelines` | `project`; optional `ref`, `sha`, `status`; `limit` (20), `page` (1) | `GET /projects/<project>/pipelines`, newest first |
| `issues` | `project`; optional `labels`, `author`, `search`; `state` (`opened`, `closed` or `all`; opened), `limit` (20), `page` (1) | `GET /projects/<project>/issues`, newest first |
| `issue` | `project`, `iid` | `GET /projects/<project>/issues/<iid>` |

`project` is the path of a project, `group/project` with subgroups to any
depth, or its number. Its slashes go into the request as `%2F`. The pattern
refuses two dots in a row, which the core's own check does not: it refuses a
path segment that is only `..`, and not one that holds it among escaped
slashes. `iid` is the number of an issue or merge request in its project.
GitLab numbers the two apart, so the calls are told apart by name.

Each answer keeps the fields an agent reads and drops the rest, so a field
the call does not name never reaches the agent. A list leaves out
descriptions, which `issue` and `merge_request` carry. `merge_request`
includes the head pipeline with its status, which answers most questions about
CI. The pack's `read` preset names all six. `yardr pack show gitlab` prints
it, and SETUP.md grants it by name, because yardr's `--preset` takes only the
presets of packs inside its binary.

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
- **Required checks.** GitHub lists the checks a branch requires, by name.
  GitLab gates on the head pipeline as a whole, so `ci` names one required
  check, `pipeline`, and only where the project asks for it. A job is never
  required on its own.
- **Words for CI.** GitLab's pipeline hook carries a `status`, and GitHub's
  run events an `action` and a `conclusion`. The pack derives `conclusion`
  from the status in GitHub's words, so the `conclusion` part of a hook line
  reads the same for both: `failed` becomes `failure`, `canceled` becomes
  `cancelled`. A merge request's `opened` is said `open` to the core.
- **Merged results pipelines.** They run on a commit GitLab makes of the
  merge request and its target branch, while GitHub reports its checks on the
  head commit. Their events carry no `head_sha`, and `ci` accepts the head
  pipeline when it is one.
- **No branch thread.** GitHub gives a run on no pull request the thread
  `<repo>@<branch>`, so a bead made for a failed run is found by the next. A
  GitLab pipeline on no merge request has no thread.
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

The `events` key meets the same gap. The thread of a pipeline is the merge
request's, so a run on merge request !7 is found by the bead that tracks issue
#7 when nothing tracks !7, and a `says` line can move that bead. Where the
bead has no head from an event, `pr` is asked for the issue's address, which
names no merge request, and the read fails and is logged.

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
- A Pipeline Hook for a merge request has `merge_request` with the merge
  request's own `url`, and one for a branch with no merge request has it null
  or left out. GitLab's documentation says neither.
- A pipeline run for a merge request has the head of the source branch as
  `object_attributes.sha`. The documentation shows a sample with a branch name
  for `ref`, and an API sample with `refs/merge-requests/<n>/merge` for a
  merged results pipeline, whose `sha` is not the head. The pack reads the
  second from that sample.
- The merge request's `head_pipeline` is present for the token (GitLab shows it
  only to a user who can view pipelines), carries `project_id`, and is the
  pipeline of the head commit a few seconds after a push. Until then `ci`
  reports none.
- `GET /projects/<id>/pipelines/<id>/jobs?include_retried=false&per_page=100`
  pages as the notes do, and lists the latest attempt of each job.
- The token's role sees `only_allow_merge_if_pipeline_succeeds` and
  `allow_merge_on_skipped_pipeline` on the project. GitLab says the fields of
  a project vary with the permissions.
- A project path with its slashes as `%2F` is read by GitLab in a call's path
  as it is in the thread commands'. The test pins that yardr sends them so,
  and nothing more.
- `labels=a%2Cb` is read as the labels `a` and `b`, and `search` and
  `author_username` filter as the documentation says.

## Files

- `pack.yaml`, `gitlab.yaml`: the pack and its declaration.
- `gitlab/normalize`: POSIX sh and jq, the verified body to the envelope.
- `gitlab/thread`: bash, curl and jq, the thread commands.
- `gitlab/mr`: bash, curl and jq, the `pr` and `ci` reads.
- `testdata/hook/`: the webhook bodies and the envelopes made of them,
  goldens beside them.
- `testdata/thread/` and `testdata/mr/`: one directory for each case of a
  thread command or of `pr` and `ci`, with its input, the answers the stand-in
  gives in order, and the requests and output expected. `_answers/` holds the
  answers they share.
- `testdata/calls/`: one file for each case of a call, with its parameters, the
  answer GitLab is made to give and the request and output expected.
- `testdata/core.sh`, `testdata/standin.py`, `testdata/declaration.golden`: the
  part of the test that runs the real yardr, the stand-in for GitLab on a
  loopback port, and the declaration as the yard reads it.
- `testdata/bin/curl`: the stand-in for curl.
- `testdata/link.txt`: paths for the link patterns and what each makes.
- `test`: runs all of it.

## Runtimes

`gitlab/normalize` wants POSIX sh and jq, as the other source packs do.
`gitlab/thread` and `gitlab/mr` want bash 3.2 or later, curl and jq. The gate
knows no language, so this is the pack's word for what its programs need.
The test wants python3 and yardr besides, for its last part.

## Testing

```sh
./test
```

in this directory. It feeds each webhook body to normalize and compares the
envelope with its golden byte for byte, and checks that the fields the
envelopes carry and `hook.keys` agree both ways. A table runs the successful
pipeline through each of the thirteen statuses GitLab lists, and through
bodies with a merge request that is missing, empty or not one. It runs each
thread case and each case of `pr` and `ci` against the stand-in curl, which
makes no request, records the method, URL, headers and body the real one
would have been asked for, answers from the case's fixtures and refuses any
use of curl the script does not make today. A changed request fails its case,
and `mr` is held to GET. A canary token is looked for in every argument,
output and record, and has to be on curl's stdin alone. The link patterns are
run on the paths in `testdata/link.txt` through jq's regex engine.

The last part runs the real yardr, in a scratch yard of its own under `env -i`,
with no agent and one listener, the stand-in for GitLab on a loopback port. It
holds the declaration as the yard reads it to a golden, runs the grant
commands SETUP.md teaches, and makes each call of `testdata/calls/` through
`yardr call`: the golden has the request as it was sent (an encoded slash
stays `%2F`, the query is sorted and escaped), whether the token came in
`PRIVATE-TOKEN`, and what the call kept of the answer. A parameter a call
refuses shows as no request. The token is looked for in every file the run
leaves. The depot's gate runs `yardr pack check` on this directory first.

`UPDATE=1 ./test` writes the goldens again from what the programs print. Read
the diff before keeping it.

## Left out

Each of these waits for a word from mckean: git hosting for a depot whose
origin is on gitlab.com, which wants a `git` credential helper like GitHub's;
group webhooks; links and bases for a self-managed instance, which its
operator writes into a copy; work items that are not issues, such as tasks,
incidents and epics; replies into a discussion's thread; the signing token
above.

Also not here, because the bead did not ask for it: a call that lists merge
requests, one that reads a pipeline's jobs, and the trigger jobs and external
status checks of a pipeline as checks; a thread for a pipeline that ran for no
merge request; and anything that writes beyond the first slice's threads.
