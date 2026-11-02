# Jira

Jira Cloud as a pack of kind source, for a company whose tracker is Jira. An
admin webhook delivers issue and comment events to the yard as envelopes it
subscribes to, and the yard answers in the issue, opens issues and moves them
along their workflow, as it does in Linear. Two reads let an agent look at an
issue or search by JQL. Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/jira
```

SETUP.md is the operator's steps. `packs/linear` in the yardr repository is the
pattern, and this file says where Jira differs.

## How it hangs together

**Hearing.** A Jira admin webhook with a secret signs each delivery
`X-Hub-Signature: sha256=<hex>`, the HMAC-SHA256 of the body, and names it in
`X-Atlassian-Webhook-Identifier`. The core checks both (`hook.verify` in
`jira.yaml`). It uses the identifier to drop a retry, and the body to drop a
second webhook's copy of the same event. `jira/normalize` turns a verified body
into the envelope, with Linear's vocabulary:

| Jira event | type | action | text |
|---|---|---|---|
| `jira:issue_created` | `issue` | `create` | the description |
| `jira:issue_updated` | `issue` | `update` | `changed summary, status`, or `commented` |
| `jira:issue_deleted` | `issue` | `remove` | none |
| `comment_created`, `comment_updated`, `comment_deleted` | `comment` | `create`, `update`, `remove` | the comment |
| any other event | its own name | none | none |

The thread is the issue, named by its key (`SHED-7`) and addressed by its browse
page. The actor and `fields.sender` are the Atlassian account id of who did it,
which `hear` matches against the identities users and crew members hold in
`jira`. `mentions` holds the account ids a text mentions. A deleted comment's
delivery may name no user, and then the envelope has no actor and no sender,
rather than crediting the delete to the comment's author. `fields` carries
`project`, `issuetype`, `status`, `label` and `sender`.

A text is read as a wiki string (`[~accountid:<id>]` for a mention) or as an ADF
document (a `mention` node), because Atlassian's page names the comment's shape
"as the REST API returns it" without saying which version. Both have goldens.

**Speaking.** `jira/thread` runs reply, posted, read, open, opened and state:

| command | requests |
|---|---|
| reply | `GET serverInfo`, `POST issue/{key}/comment` with the key as a comment property |
| posted | the issue's comments newest first, then `POST comment/list?expand=properties` for each page's properties |
| read | every page of `GET issue/{key}/comment`, oldest first |
| open | `GET issue/createmeta/{project}/issuetypes`, then `POST issue` with the key as an issue property |
| opened | one `POST search/jql` for what this account made in the project since the attempt, asking for the key's property |
| state | `GET issue/{key}?fields=status`, `GET issue/{key}/transitions`, and `POST transitions` when it moves |

A thread id is an issue key, checked before it goes in a path. A text becomes ADF:
a paragraph at each blank line and a line break at each other. `read` keeps the
newest messages that fit the 64 KB a command may answer. Browse addresses are
built from `serverInfo`, because under a scoped token the base is Atlassian's
gateway and the site names itself.

Jira takes no id of ours for a comment or an issue, so `yardr.key` rides along as
an entity property and `posted` and `opened` read it back. A comment is found
exactly. An issue is found through a JQL search, which lags the write by a few
seconds, so an `open` retried within them can make a second issue.

`state` reads a status by its category (new, indeterminate, done), which every
workflow has, and takes the transition that leads to one. Its rules are in
SETUP.md step 8 and pinned by the `state-*` cases.

**Reading.** `viewer` (the check call), `issue` and `search` are declared calls at
the base, all kind read. `issue` asks for the fields an agent reads an issue by,
the comments among them. `search` is the new `search/jql` endpoint, a POST that
is still a read.

**The credential.** Atlassian takes an API token as Basic, `email:token`. A
command is handed one variable and a call's header takes one, so the two are
mint inputs and `jira/mint` makes the base64 both use (`JIRA_AUTH`). A token with
scopes is called at `https://api.atlassian.com/ex/jira/<cloud id>` and one
without at the site. Both take Basic, so only the base differs.

**The base.** Jira is per site, so the declaration ships the placeholder
`https://example.atlassian.net` and SETUP.md has the operator write their own
into the yard's copy. A pack applied again puts the placeholder back; the test
pins that, and SETUP.md step 10 says what to do. `jira/thread` refuses to send
anything to the placeholder. If a real user trips on this, a core `base_url`
setting becomes its own bead.

**No link key.** An issue's address starts with the site's host, which the shared
file cannot name. Without the key a bead cannot track a Jira issue and a stage
map has nothing to move, but the thread commands work, since they take the issue
key. `link.example.yaml` is the key for the yard's copy, and the test holds it to
the real yardr.

## Files

- `pack.yaml`, `jira.yaml`: the pack, with the `read` preset, and the declaration.
- `jira/normalize`: POSIX sh and jq, a verified body to the envelope.
- `jira/thread`: bash and curl and jq. The credential goes to curl on its stdin
  as a config line, never in an argument, and `-q` keeps a `.curlrc` from
  tracing it into an error. Written for bash 3.2, which macOS ships.
- `jira/mint`: sh and jq, the Basic credential from the email and the token. It
  prints a fixed line on failure, since jq's own errors quote the value.
- `link.example.yaml`: the optional link key.
- `testdata/`: webhook bodies and goldens, thread cases and goldens, a stand-in
  `curl`, a stand-in for Jira's API, and the declaration golden.

## Runtimes

`jira/normalize` and `jira/mint` need `sh` and `jq` 1.6 or later. `jira/thread`
also needs `bash` and `curl`. The test needs those too, and for its last part
`yardr`, `python3` and `openssl`; without `yardr` or `python3` it says so and goes
on.

## Testing

```sh
./test
```

in this directory, about five seconds, no network and no secret. The gate
(`.yardr/test`) runs `yardr pack check` first.

- `normalize` against each body in `testdata/hook`, byte for byte, and three
  bodies it must refuse without quoting them.
- `mint`: the value, the expiry, and what it says when an input is missing.
- `thread`: each `testdata/thread/*.case` is one run against a stand-in `curl`.
  The case's golden holds the requests the program made (method, address,
  headers, body, and whether the credential was the right one), the exit status,
  stdout and stderr. A changed request is a changed golden. The run fails if the
  token or the credential is in an argument, an output or the log.
- the declaration as the yard reads it, calls included, against
  `testdata/declaration.golden`; the signature the declaration describes against
  Atlassian's published example; the check call made through the real yardr and
  minted by `jira/mint`, against a stand-in on a loopback port; and a pack
  applied again over an edited address.

`UPDATE_GOLDEN=1 ./test` writes the goldens again. Read the diff before you
commit it.

## What was checked, and what was not

Checked on 2 November 2026 against Atlassian's pages: the webhook signature, its
identifier and retry rules, the `search/jql` endpoint and its parameters, the
comment, transition, issue and property endpoints in the OpenAPI description,
which tokens go where and with what scheme, and the scopes each call needs.
Seen on public Atlassian sites without a login: the shapes of comments and
issues, `tenant_info`, and `serverInfo` answering through the gateway with the
site's address.

Not checked against a site, because a person has to make one (a free Atlassian
Cloud site serves this pack and the Confluence one). The live proof is a later
bead. It should settle:

- the shape of a webhook's comment body, a string or ADF, and whether a comment
  delivery has a `user`;
- that a token with scopes is accepted as Basic at the gateway, as Atlassian's
  support pages say. A community thread says only Bearer works there. If a site
  answers 401, the fix is in `jira/mint` and the header in `jira.yaml`;
- that a `properties` entry in a create request is kept for an issue and a
  comment, and whether a search returns the property as an object or a list (both
  are read);
- how long the search lags a write, which bounds `opened`;
- the transitions a real workflow offers, and which ones want a screen filled in;
- the names Jira's admin screen uses for the webhook's fields.

## Left out

Jira Service Management and its queues, custom-field editing beyond what a
transition needs, polling (the webhook covers the events), per-person identity
(yardr's B11 is not built), and the Confluence pack, which shares the login
story only (yardr-packs-19te).
