# Confluence

Confluence Cloud pages through its REST API, read as one Atlassian account. As
the declared source `confluence`, an agent lists a site's spaces, finds pages by
CQL, reads one page and lists the children of a page, folder, whiteboard,
database or embed. Calls are read-only. A page comes back in Confluence's storage
format, and the pack turns nothing into text.
Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/confluence
```

SETUP.md is the operator's steps. The `jira` pack, beside this one, is the
pattern for the login and for the site's address, and this file says where
Confluence differs.

## One identity for the yard

The yard reads as an Atlassian account with no person signed in. Whatever that
account can read, every agent granted a call of this source reads, and the yard
does not narrow it per agent. SETUP.md says this before its first step, and has
the operator give the account the spaces the yard should read and no others.

## The calls

All of kind read, and one preset, `read`, that suggests them. The scopes are the
ones Atlassian's API descriptions list for each request, read on 2 November 2026.

| call | request | parameters | scope |
|---|---|---|---|
| `spaces` | `GET /wiki/api/v2/spaces` | `keys`, `limit` (25), `cursor` | `read:space:confluence` |
| `page` | `GET /wiki/api/v2/pages/{id}?body-format=storage` | `id` | `read:page:confluence` |
| `children` | `GET /wiki/api/v2/{kind}/{id}/direct-children` | `id`, `kind` (`pages`), `limit` (25), `cursor` | `read:hierarchical-content:confluence` |
| `search` | `GET /wiki/rest/api/content/search` | `cql`, `limit` (25), `cursor` | `search:confluence` |

What is behind the table:

- `children` is on `direct-children`. Atlassian marks `GET /pages/{id}/children`
  deprecated, the one deprecated operation in v2, and `direct-children` is what
  stands beside it. It answers a page's pages and also its folders, whiteboards,
  databases and embeds, each with a `type`. The same operation is also at
  `/folders/{id}/direct-children`, `/whiteboards/{id}/direct-children`,
  `/databases/{id}/direct-children` and `/embeds/{id}/direct-children`, with the
  same scope, parameters and answer, so one call walks all five. Its `kind` is
  a child's `type` and an `s` (`pages`, `folders`, `whiteboards`, `databases`,
  `embeds`), so a child of type `folder` takes `kind=folders`. Left out, `kind` is
  `pages`, so a call that names no kind asks the page endpoint. It is an enum
  because it becomes a segment of the path. A word outside the five sends no
  request, a child's own `type` in the singular (`folder`) among them. One call is
  one grant, and `read` covers all five.
- `search` is the v1 endpoint, because CQL search is v1 only: Atlassian has no v2
  equivalent, and has said it would deprecate this one only when there is. A hit
  is `id`, `type`, `status`, `title` and `_links`, and `_links.webui` names its
  space (`/spaces/ENG/pages/98404/Runbooks`), so nothing is expanded. The rest of
  a hit is empty objects and the paths of what `expand` would add, and a call's
  `select` keeps top-level keys only, so they come along. The answer's `start` is
  echoed and ignored by Confluence, so it is left out.
- The body is the one field a reader must not take for text. `page` fixes
  `body-format=storage`, so the body is at `body.storage.value`, XHTML with
  Confluence's own tags and macros, and a call that names another format is
  refused. The call's `about` says it is markup. The answer is bounded at 256 KiB
  as `google-docs` bounds a document, and one over it is refused and not cut.
- Paging is by cursor. v2 gives the next page's address in a `Link` header, which
  a declared call cannot read, and also as `_links.next` in the body, which stays
  in the answer. Its `cursor=` value is `cursor` of the same call again. v1
  search writes the value percent-encoded and the call encodes what it is given,
  so for `search` it is given decoded. Both were tried on a public site: a v2
  cursor goes on from where it was with any `limit`, and v1 search takes its
  cursor with the same `cql` and no `start`.
- The file names the check call `spaces`, which needs no parameter, so `yardr
  source check confluence` reaches the site with the minted credential.
- yardr hands an agent the status of a failed call and not Atlassian's error body.
  A 404 on `page` is a page that is not there or one the account may not view,
  which Confluence does not tell apart, and a 400 on `search` is a CQL it cannot
  parse.

## The credential and the address

**The login.** Atlassian takes an API token as HTTP Basic, the base64 of
`email:token`. A call's header takes one `{credential}`, so the email and the
token are two mint inputs and `confluence/mint` makes the one value
(`CONFLUENCE_AUTH`). It is `jira/mint` with this pack's names. The email is no
secret and is asked in the clear. The two live in this source's own env file; the
`jira` source has another and is given the same two values again, so the yard has
two sources and one login. A token that is replaced is given to each.

**Which token.** A service account has scoped tokens only, and the form for one
has you choose the app and then its scopes. So where the account's token for
`jira` was made for Jira, Confluence needs a second token for the same account,
with the four scopes above. A token without scopes, which an ordinary account
can make, serves both apps and can do everything the account can. The pack's
mint takes either, and SETUP.md says which goes where.

**The address.** Confluence is per site, so the declaration ships the placeholder
`https://example.atlassian.net/wiki` and SETUP.md has the operator write their
own into a copy of the file (`confluence.local.yaml`, ignored by git) and add
it. A token with scopes is called at
`https://api.atlassian.com/ex/confluence/<cloud id>/wiki` and one without at
`https://<site>.atlassian.net/wiki`. Both take Basic, so only the base differs,
and every path in the file starts at `/api` or `/rest`. A pack applied again
replaces the yard's copy and puts the placeholder back; the test pins that, and
SETUP.md step 6 says what to do. Until the copy is added again the source calls
the placeholder with the account's credential. Unlike `jira`, this pack has no
command to refuse to send there, since all its calls are declared. If a real user
trips on this, a core `base_url` setting is its own bead.

## Files

- `pack.yaml`, `confluence.yaml`: the pack, with the `read` preset, and the
  declaration.
- `confluence/mint`: sh and jq, the Basic credential from the email and the
  token. It prints a fixed line on failure, since jq's own errors quote the value.
- `SETUP.md`: the account, its token, the address, the grant, the first calls.
- `.gitignore`: the operator's copy of the declaration.
- `test`, `testdata/`: the tests. `calls/` holds a `.case` for each scenario
  (the call, the stand-in's answer and status) and the `.golden` of what
  happened; `standin.py` is the stand-in for Confluence; `declaration.golden`
  and the two `*.requests.golden` pin the rest.

## Runtimes

`confluence/mint` needs `sh` and `jq` 1.6 or later. The test needs those, and
`python3` and `yardr`, and fails without them, since a skipped test would leave
the requests unpinned. The pack is written for pack API 3 (`api: 3` in
`pack.yaml`), because `children`'s `kind` has a default and is in a path,
which API 3 added. A yardr that reads less refuses the pack with `upgrade yardr`,
not with a complaint about the path.

## Testing

```sh
./test
```

in this directory, about three seconds, no network and no secret. The gate
(`.yardr/test`) runs `yardr pack check` first.

- `mint`: the value, the expiry, what it says when an input is missing or empty,
  and that the token is in no argument of anything it runs.
- the declaration as the yard reads it against `testdata/declaration.golden`, and
  that every call is a read by GET.
- the real yardr in a scratch yard with its own home, the pack applied, and a copy
  of the declaration aimed at the stand-in on a loopback port, which the credential
  reaches as the right Basic value: the check call; a `.case` for each call, with
  its first page and its next, its default and its given parameters (`children`
  once for each of the five kinds, each on a node and a path segment of its own),
  a page over the bound, the statuses 400, 401 and 404, and the parameters the
  call must refuse (a page id with a slash, a missing id, a body format, a CQL of
  2001 characters, a limit that is no number, a `kind` in the singular), each of
  which sends no request. A changed path, query, select, bound, pattern or enum
  value is a changed golden.
- the calls again through the gateway's address, whose base carries a path.
- a pack applied again over an edited address: the plan names the address it
  takes away, the shipped address returns, and the env file and a grant stand.
- the token and the credential made of it are in no file of the run but the env
  file: not an output, not the yard's store, events or log.

`UPDATE_GOLDEN=1 ./test` writes the goldens again. Read the diff before you
commit it.

## What was checked, and what was not

Checked on 2 November 2026 against Atlassian's pages: the four requests, their
parameters and scopes in the OpenAPI descriptions of v2 and v1; that pages,
folders, whiteboards, databases and embeds each have a `direct-children`, none of
them deprecated, with the one scope, the same parameters (`id`, `cursor`, `limit`
from 1 to 250 and 25 by default, `sort`) and the same answer type; the
deprecation of `GET /pages/{id}/children`; the gateway's address for a
token with scopes and that Atlassian's own examples send it as Basic; that a 401
is the answer to a missing scope and to an account without access. Seen on a
public Confluence Cloud site without a login (openmrs.atlassian.net): the shapes
of the answers of all four requests (`children` on a page's id), the cursors,
that v1 search takes its cursor alone, and `tenant_info`.

Not checked with a credential against a site of our own, because a person has to
make one (a free Atlassian Cloud site serves this pack and the Jira one). The
live proof is a later bead. It should settle:

- that a token with scopes is accepted as Basic at the gateway, as Atlassian's
  support pages say. A community thread says only Bearer works there. If a site
  answers 401, the fix is in `confluence/mint` and the header in
  `confluence.yaml`;
- that the four scopes are enough. `search:confluence` is the one the v1 page
  lists as current, beside `read:content-details:confluence` as beta; if search
  answers 401 under the first alone, the second is added to the token;
- whether a service account can make one token with the scopes of both apps, which
  would make the Jira token serve here;
- what the account sees in a space that lets every user of the site view it;
- what `children` answers for a folder, whiteboard, database or embed. Those four
  endpoints are read in Atlassian's description and not called, with a login or
  without, and the cases' answers are made like the page's. The live proof needs a
  node of each kind that has children;
- a very long page, and a space with thousands of children.

## Left out

Comments, labels and a page's list of attachments (yardr-packs-5ev5, behind this
one); an attachment's contents (a file's bytes are yardr-racg's to settle);
blogposts; reading a folder, whiteboard, database or embed itself (a walk lists
one with its title, and `page` takes a page's id only); page history and
versions; any write; turning storage format into text; and Confluence Data Center
and Server, whose API and login are others. Each is a later bead.
