# Microsoft

SharePoint and OneDrive documents through Microsoft Graph, read as one
Entra app. As the declared source `microsoft`, an agent lists a tenant's
sites, a site's document libraries, and the folders and files of a
library, reads one item's metadata and its link, and searches documents
by words. Calls are read-only. Search hits can include short excerpts
from matching documents in Graph's `summary` field; no call downloads
full file bytes. Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /Users/mckean/projects/repos/yardr-packs/microsoft
```

from main of this repository. SETUP.md is the operator's steps, written
for whoever runs Microsoft 365 for the team.

## One identity for the yard

The yard reads as an Entra app with no person signed in. Whatever the
app may read, every agent granted a call of this source reads, and the
yard does not narrow it per person. SETUP.md says this before its first
step and again at the grant, and sets the narrow permission
(Sites.Selected, granted site by site) beside the broad ones.

## The calls

All of kind read, and one preset, `read`, grants them. The permissions
are the application permissions Microsoft's pages list for each request,
read on 2 November 2026.

| call | Graph request | parameters | permission |
|---|---|---|---|
| `sites` | `GET /sites?search={query}` | `query` | Sites.Read.All. Microsoft: "doesn't support the Sites.Selected application permission" |
| `drives` | `GET /sites/{site}/drives` | `site` | Files.Read.All or Sites.Read.All, or Sites.Selected on a granted site |
| `root` | `GET /drives/{drive}/root/children` | `drive`, `top` (50) | as `drives` |
| `children` | `GET /drives/{drive}/items/{item}/children` | `drive`, `item`, `top` (50) | as `drives` |
| `item` | `GET /drives/{drive}/items/{item}` | `drive`, `item` | as `drives` |
| `search` | `POST /search/query`, entityTypes `driveItem` | `query`, `region`, `size` (10), `from` (0) | Files.Read.All or Sites.Read.All. Sites.Selected is not listed |

What is behind the table:

- `search` is a POST and a read. yardr refuses only PUT, PATCH and
  DELETE on a read call.
- `root` is a call of its own because Microsoft documents no
  `items/root` alias. A library's top level is the drive's `root`
  relationship, and without the call an agent could list libraries and
  not open one.
- Microsoft requires `region` of a search made with application
  permissions: the tenant's data location code, such as `NAM`. Graph
  gives it as `dataLocationCode` for a Multi-Geo tenant and for no
  other, so the call takes it as a parameter and SETUP.md says where to
  find it. App-only search covers shared content only. The request names
  no `sharePointOneDriveOptions`, because private content needs an
  index Microsoft builds over days.
- Every driveItem request sends `$select` with its own fields.
  A driveItem has `@microsoft.graph.downloadUrl`, a link Microsoft calls
  preauthenticated, which needs no sign-in and lives an hour, so it would
  give an agent a file's bytes outside any grant. Microsoft's page on
  downloading a file has an app get the link by selecting it by name, and
  these requests never name it. A call's `select` keeps top-level keys
  only, so for `root` and `children` the `$select` is all that keeps the
  link out, and `item` drops it a second time. The pages read do not say
  what a request with no `$select` returns.
- The `Sites.Selected` column rests on Microsoft's overview of the
  Selected permissions, which says the granted resource decides access
  whichever Graph path reaches it. The pages for these requests do not
  name it. Nothing here has run against a tenant.
- There is no paging. A page that has more keeps `@odata.nextLink` and
  follows none; `search` pages with `from` and `size`. A list's answer
  may be 256 KiB, `answer.max` raised from the 64 KB default, since an
  item with these fields is about 650 bytes and Graph's own page of 200
  is about 130 KB.
- The file names no check call, because which call works depends on the
  permission. yardr makes a mint only for a check call, so `yardr source
  check microsoft` reports where the three values are set and sends
  nothing. The first call is the test (SETUP.md, step 9).
- yardr hands an agent the status of a failed call and not Graph's error
  body.

## The mint

`microsoft-mint` turns the tenant, the app's id and the app's secret
into a token by the OAuth client credentials grant, as Microsoft's page
on the flow writes it: a POST of `client_id`, `scope`
(`https://graph.microsoft.com/.default`), `client_secret` and
`grant_type` to `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token`.
It answers `{token, expires_at}`, and the yard keeps the token in
memory alone.

The secret goes from stdin through jq to curl's stdin. It is in no
argument, no file and no message. A failure says the HTTP status,
Entra's error if it is one short lower-case word, and the number in
`error_codes`, so a wrong secret reads `answered 401 (invalid_client,
AADSTS7000215)` and never repeats Entra's description. The tenant is
held to letters, digits, dots and dashes, since it is a path segment of
the token address.

The yard passes these proxy and CA variables to a command:
`HTTPS_PROXY`, `https_proxy`, `HTTP_PROXY`, `http_proxy`, `NO_PROXY`,
`no_proxy`, `SSL_CERT_FILE` and `SSL_CERT_DIR`. For this HTTPS endpoint,
curl uses `HTTPS_PROXY` or `https_proxy`, and `NO_PROXY` or `no_proxy`
can bypass it; `SSL_CERT_FILE` and `SSL_CERT_DIR` provide CA roots.
curl ignores uppercase `HTTP_PROXY`, and `http_proxy` applies to HTTP
URLs. The script gives curl no option that overrides these variables.
`NODE_EXTRA_CA_CERTS` is a Node variable, and tried the same way it did
nothing to curl. Reading it as `--cacert` would replace the system's
roots where Node adds to them, so a company CA belongs in
`SSL_CERT_FILE`.

## Files

- `pack.yaml`, `microsoft.yaml`: the pack, its one preset and its
  declaration. The declaration's header says what was checked against
  Microsoft's pages and what was not.
- `microsoft-mint`: the mint, POSIX sh with curl and jq.
- `SETUP.md`: the Entra app registration, the permission choice, the
  grants and the first call.
- `test`, `testdata/`: the tests. `calls/` holds a fixture for each
  call (parameters, the request it must make, a recorded Graph answer,
  what the call keeps, and parameters it must refuse); `render.jq`
  builds the request from the declaration; `mint/` holds the mint's
  cases and its golden stdin, curl arguments and form; `bin/` holds the
  stand-in curl and the jq that logs its arguments.

## Runtimes

- The mint wants POSIX sh, curl 7.34 or later and jq 1.6 or later on
  the PATH the yard's server has. Its 39 cases pass with the mint run
  by macOS's `/bin/sh`, dash, ksh and bash.
- The test wants jq 1.6 or later, and ruby, python3 with PyYAML, or yq
  to read `microsoft.yaml` as data. With none of them it fails and says
  so, since a skip would leave the requests unpinned. It wants no
  network and no secret, and runs in a few seconds.

## Testing

```sh
./test
```

in this directory. For each call, `render.jq` builds from the
declaration the request yardr sends for the fixture's parameters, the
way yardr's `internal/source/call.go` builds it, and what the call keeps
of the recorded answer, and the test compares both with the fixture,
which was written from Microsoft's examples and not from the
declaration. It then compares the call names, kinds, base and mint
command with what `yardr pack check` reads of the same file.

For the mint, each of 39 cases runs the script itself under a bare
environment, with a stand-in curl that records its arguments, stdin and
environment and answers from the case. The test compares the token,
the message and the exit status; the curl arguments and the form
against `testdata/mint/request.*`; and the proxy and CA variables
against those set. For every case it looks for the secret in the
output and in every argument of curl and jq, as it is, percent-encoded,
as stdin carries it, and by its longest run of letters and digits, and
it checks that no file was written. The golden secret has an ampersand,
angle brackets, quotes, a backslash, a plus, a slash, a percent sign, a
space and non-ASCII characters in it.

`render.jq` follows `call.go` as read, not a capture from a running
yard, so its fidelity is the reading's. The first live run is the check
on it.

## Left out

Downloading full file contents (the next bead; search hits may still
include Graph's short text excerpts); any write; Outlook and Teams;
reading as each person (yardr's B11 is not built); delta sync; paging;
private OneDrive content in search; the national clouds, whose login
and Graph hosts differ; a certificate or federated credential in place
of the client secret.
Each is a later bead, on mckean's word.
