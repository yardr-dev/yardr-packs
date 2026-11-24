# Confluence

Confluence Cloud pages through its REST API, as one Atlassian account. As the
declared source `confluence`, an agent lists a site's spaces, finds pages by
CQL, reads one page, lists the children of a page, folder, whiteboard, database
or embed, lists a page's comments, the replies to a comment, its labels and its
attached files, and names an author from an account id. It writes in two ways
and no other: `create` makes a page under a parent page, and `update` replaces
one page's title and body at the version after the one the caller read. Nothing
is deleted or moved. A page and a comment come back in Confluence's storage
format, and the pack turns nothing into text and nothing into storage format. An
attached file comes back as its metadata with a download link, and the pack
fetches no file.
Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/confluence
```

SETUP.md is the operator's steps. The `jira` pack, beside this one, is the
pattern for the login and for the site's address, and this file says where
Confluence differs.

## One identity for the yard

The yard acts as an Atlassian account with no person signed in. Whatever that
account can read, every agent granted a read call of this source reads, and
wherever it may write, an agent granted `create` or `update` writes. The yard
does not narrow either per agent. SETUP.md says this before its first step, and
has the operator give the account the spaces the yard should read and no others,
and the permission to create and edit pages in the one space it writes in.

## The calls

Nine of kind read and two of kind update, and three presets that suggest them:
`read`, `create` and `update`. `read` covers every read call and neither update,
and each update is granted by its name alone, as flagsmith's two are. The scopes
are the ones Atlassian's API descriptions list for each request, read on 2
November 2026 (`spaces`, `page`, `children`, `search`), 4 November (the other
five) and 22 November (`create` and `update`).

| call | request | parameters | scope |
|---|---|---|---|
| `spaces` | `GET /wiki/api/v2/spaces` | `keys`, `limit` (25), `cursor` | `read:space:confluence` |
| `page` | `GET /wiki/api/v2/pages/{id}?body-format=storage` | `id` | `read:page:confluence` |
| `children` | `GET /wiki/api/v2/{kind}/{id}/direct-children` | `id`, `kind` (`pages`), `limit` (25), `cursor` | `read:hierarchical-content:confluence` |
| `search` | `GET /wiki/rest/api/content/search` | `cql`, `limit` (25), `cursor` | `search:confluence` |
| `comments` | `GET /wiki/api/v2/pages/{id}/{kind}-comments?body-format=storage` | `id`, `kind` (`footer` or `inline`), `limit` (25), `cursor` | `read:comment:confluence` |
| `replies` | `GET /wiki/api/v2/{kind}-comments/{id}/children?body-format=storage` | `id` (a comment's), `kind`, `limit` (25), `cursor` | `read:comment:confluence` |
| `labels` | `GET /wiki/api/v2/pages/{id}/labels` | `id`, `limit` (25), `cursor` | `read:page:confluence` |
| `attachments` | `GET /wiki/api/v2/pages/{id}/attachments` | `id`, `limit` (25), `cursor` | `read:attachment:confluence` |
| `user` | `GET /wiki/rest/api/user?accountId={accountId}` | `accountId` | `read:confluence-user` |
| `create` (update) | `POST /wiki/api/v2/pages` | `spaceId`, `parentId`, `title`, `body` | `write:page:confluence` |
| `update` (update) | `PUT /wiki/api/v2/pages/{id}` | `id`, `version`, `title`, `body` | `write:page:confluence` |

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
- `comments` lists the root comments of a page and no reply. Atlassian's
  description says root, and on a page whose comment has a reply the list gave
  the comment alone. A reply is at `replies`, by the id of the comment it
  answers, and may have replies of its own, so a thread is walked down by id
  with the kind it started from. The kind of a comment is a segment of the path
  (`footer-comments`, `inline-comments`), so `kind` is an enum, the only check
  on that segment, and it has no default: with one, a call that left it out
  would list the footer comments and look complete. A footer comment belongs to
  the page. An inline comment is on a passage of its text, and
  `properties.inlineOriginalSelection` is the passage. Either may have a
  `resolutionStatus` (`open`, `reopened`, `resolved` or `dangling`). A comment
  has no body unless a format is named, so both calls fix `body-format=storage`
  as `page` does. The body is at `body.storage.value`, markup and not text, and
  an answer is bounded at 256 KiB, refused and not cut. A comment names its
  author by `version.authorId`, an Atlassian account id, which `user` turns into
  a name. A `kind` that is not the comment's is no error on `replies`:
  a footer comment's id asked as inline answered 200 and an empty list, so an
  agent that mixes the two sees no replies where there are some.
- `labels` takes `read:page:confluence`, the scope `page` has already. A label is
  `id`, `name` and `prefix`.
- `attachments` lists the files of a page as metadata and never the file: `id`,
  `title` (the file's name), `mediaType`, `fileSize` in bytes, `status`,
  `createdAt`, `version`, `comment`, `downloadLink` and `webuiLink`. Both links
  are paths on the site, so a person opens `_links.base` followed by the path.
  Nothing here follows one. What a file holds is yardr-racg's to settle. An
  entry is about a kilobyte, so a page of 250 may pass the 256 KiB bound, and a
  smaller `limit` then fits.
- `user` names one account from its id, which is `version.authorId` in a comment,
  a reply and an attachment. It is the v1 endpoint, `GET /wiki/rest/api/user`,
  because v2 has no GET for a user (its four `likes/users` reads answer ids
  alone) and its one lookup by id is `POST /users-bulk`, a list of ids in a
  body. Two forms of id are seen, 24 hex digits (`5b10ac8d82e05b22cc7d4ef5`) and
  a number, a colon and a UUID (`712020:<uuid>`). The pattern of `accountId`,
  letters, digits and `:` `.` `_` `-`, takes both and blocks `/`, `?`, `&` and a
  space. The value is in the query, which the call encodes (the colon goes out
  as `%3A`), so the pattern is a second guard and not the only one. The answer
  keeps `accountId`, `displayName` and `accountType` (`atlassian` for an
  Atlassian account, `app` for the bot user of an app, an empty string where
  Confluence has none) and nothing else, about 150 bytes, under the default
  bound. A user has more keys, `email`, `profilePicture`, `publicName` and
  `timeZone` among them. Every agent granted `read` would see them and naming an
  author needs none, so the `select` drops them, and the test checks the three
  keys beside its golden. A 404 is an id that is not there and a 403 is an
  account that may not view users. Atlassian says what comes back may be
  restricted by the user's profile visibility, and a `displayName` may be the
  same as the `publicName`. One call names one account and counts toward the
  hourly limit of 60 (SETUP.md step 4), so an agent that has several authors
  calls it for each and keeps the names.
- Paging is by cursor. v2 gives the next page's address in a `Link` header, which
  a declared call cannot read, and also as `_links.next` in the body, which stays
  in the answer. Its `cursor=` value is `cursor` of the same call again. v1
  search writes the value percent-encoded and the call encodes what it is given,
  so for `search` it is given decoded. Both were tried on a public site: a v2
  cursor goes on from where it was with any `limit`, and v1 search takes its
  cursor with the same `cql` and no `start`. Paging on the four calls of 4 November
  was seen on a page's footer comments and on its attachments: `_links.next`
  holds the cursor unencoded, as v2's others do, and the comments came oldest
  first (the cursor names CREATED_DATE, ascending).
- The file names the check call `spaces`, which needs no parameter, so `yardr
  source check confluence` reaches the site with the minted credential.
- yardr hands an agent the status of a failed read and not Atlassian's error body.
  A 404 on `page` is a page that is not there or one the account may not view,
  which Confluence does not tell apart, and a 400 on `search` is a CQL it cannot
  parse. On the public site a page id that does not exist answered 404 on `labels`
  and `attachments` but 400 on `comments`, and a comment id that does not exist
  answered 400 on `replies`, though Atlassian's descriptions say 404 for all of
  them. A 400 from `comments` or `replies` can be an id that is not there, as well
  as a `limit` over 250. The two writes are the exception: see below.
- `create` and `update` are declared update calls on the same login, with no
  `update_env`, as `google-docs` shares one token between its reads and its
  writes. Their bounds are google-docs' and flagsmith's. An id is digits
  (`^[0-9]+$`, at most 20 characters), and is kept in the record of the call with
  `version`, because an audit asks by them. A `title` and a `body` are free text
  and are kept nowhere: yardr's own note on `log` says never for free text, and a
  value logged cannot be taken back. A title is one line, not empty, of at most
  255 characters, which is this file's bound: a community answer gives that
  length for a title and Atlassian's description gives none. A body is at most
  60000 characters, which the test pins with a body of 60001. The body of the request is a mapping in the declaration with
  placeholders, as flagsmith's are, and no program builds it.
- What a write sends is what Atlassian's description requires, and no more.
  `create` sends `spaceId`, `parentId`, `status: current`, `title` and `body:
  {representation: storage, value}`, and none of the three query parameters
  (`embedded`, `private`, `root-level`): the page is published, and made under
  the parent the caller names, never at the root of a space. The description
  makes `parentId` optional and puts the page under the space's home page when it
  is left out; here it is required. `update` sends `id`, `status: current`,
  `title`, `body` and `version: {number}`, and no `parentId`, `spaceId` or
  `ownerId`: the description lets an update move a page under another parent in
  its space and hand it to another account, and this call does neither. The test
  holds each body's keys beside its golden, so a golden written again does not
  pass a parent or a draft status, and holds `version.number` to a number.
- `update` takes a `title`, because Atlassian's PageUpdateRequest requires `id`,
  `status`, `title`, `body` and `version`, and a call without a title is a 400
  every time. The page's own title, from `page`, keeps it, and another renames the
  page, which is the one thing beyond the body that the call can change. A page
  that others link to by its title (`ri:content-title`, as `page`'s fixture shows)
  is a reason to keep it; whether Confluence rewrites those links on a rename made
  through the API was not tried.
- The version is the guard. `version.number` is "the current version number plus
  one", the description says, and Confluence refuses any other number with a 409.
  So `version` is that number: the caller reads `page` and sends its
  `version.number` plus one, and a person's edit between the read and the write
  makes the number stale. A declared call substitutes and cannot add, and the
  number is the API's own either way, so no program does the adding. The 409
  comes back through `errors` and nothing retries or merges: the agent reads the
  page again and calls again with the new number plus one. Developers report that
  the version a read shows can lag a write by a moment (a developer-community
  thread of April 2023), so a read straight after a write may still show the old
  number and the next call may be refused.
- A 409 has two meanings. The one the description lists for `update` is a site
  with content approvals on, whose space requires approval before a page is
  published. The one for a stale version is not in the description. Its body is in
  Atlassian's ticket CONFCLOUD-76640 and in a developer-community thread of
  January 2026: `{"errors": [{"status": 409, "code": "CONFLICT", "title": "Version
  must be incremented when updating a page. Current Version: [5]. Provided
  version: [5]", "detail": null}]}`. So a refusal of a write keeps `errors`, and
  `message` for the gateway's own body (`{"code": 401, "message": "Unauthorized;
  scope does not match"}`), and the agent tells the two 409s by what they say. The
  stale one's title carries the current version, and no body of the approvals one
  was seen. v2's error body is not documented, so the shape is what those two
  sources show. The kept answer is bounded at 16 KiB, where a
  success is about 430 bytes, so a refusal that repeated a long body in its words
  is refused as too large and not shown. The same holds for a 400: Atlassian's ticket
  CONFCLOUD-83933 shows `BAD_REQUEST` and "Content contains unsupported
  extensions and cannot be edited in Fabric editor" for a body with an `ac:link`
  that held an `ri:page`, a refusal of March 2026 that Atlassian fixed in June.
  The call builds no macro and forbids none. Richer content is a later change.
- A missing scope is a 401, as for the reads: Atlassian's support article on a
  scoped token's 401s names it, and the gateway's body is `Unauthorized; scope does
  not match`. An account that may not create or update a page in the space is a
  404, which the description lists as one 404 with a space or page that is not
  there, and it lists no 403 for either request. The test pins the 401 and the
  404, and a 403 row beside them in case Confluence answers one.
- Both writes answer with the page, body included, as Confluence does. The
  `select` keeps `id`, `status`, `version` and `_links`, so the body is never
  given back, and the test's answers carry it so that the select has a body to
  drop. `_links.base` and `_links.webui` together are the link a person opens.
- What the version does not guard. A person's unsaved draft of the page is not
  under it: the description says an update of the current version "will be
  attempted to be merged into the draft version through a content reconciliation
  algorithm", and that "the latest provided content may entirely override what was
  previously in the draft". A call tried again after a lost answer is sent with
  the same number, which the first made if it landed, so the second is refused.
  A `create` tried again sends the same request. Confluence takes no key to run a
  request once, so the declaration names no idempotency header, and what a second
  create does was not tried: Atlassian's v1 description refuses a page whose
  title is already in the space for a blueprint page and for a move, and v2's
  lists no such 400 for `createPage`. And `update` with `status: current` restores
  a trashed page, which the description says it does, with no change to its
  contents. That is no delete, and the only way these calls reach a page's
  status.
- A write counts as an update, and one caller may make 10 an hour unless the
  operator raises it (SETUP.md step 4). The test raises both limits in its
  scratch yard, since its write cases make about twenty.

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
with the scopes above: the seven read scopes, and `write:page:confluence` if the
yard writes. A token without scopes, which an ordinary account can make, serves
both apps and can do everything the account can, writing included, so with one
the account's space permissions are the only limit on `create` and `update`. The
pack's mint takes either, and SETUP.md says which goes where. A scope is fixed
when a token is made and Atlassian answers a missing one with a 401, so a token
made before a call was added is made again with that call's scope before the call
works: `read:comment:confluence` and `read:attachment:confluence` for
`comments`, `replies` and `attachments`, `read:confluence-user` for `user`, and
`write:page:confluence` for `create` and `update` (SETUP.md step 6). `yardr
source check` is a read, so it does not show whether the token may write; the
first `create` does.

**The address.** Confluence is per site, so the declaration ships a placeholder
as its `base`, with a template beside it for each of the two addresses Atlassian
calls. SETUP.md has the operator give one on a card or in a terminal and copy
nothing, and what is given is a setting of the source, so it survives a pack
applied again. The three, each replacing the other two:

- `base`, the default: `https://example.atlassian.net/wiki`, a placeholder. The
  credential is held back from it, so a call is refused and nothing is sent.
- `host=`, from `base_template: https://{host}/wiki`: a token without scopes is
  called at `https://<site>.atlassian.net/wiki`, so
  `yardr source set confluence host=<site>.atlassian.net`.
- `site=`, from `path_template:
  https://api.atlassian.com/ex/confluence/{site}/wiki`: a token with scopes is
  called through Atlassian's gateway, `https://api.atlassian.com/ex/confluence/<cloud id>/wiki`,
  so `yardr source set confluence site=<cloud id>`. The gateway is one host for
  every site and the cloud id is a path segment, which a `base_template` cannot
  make. The product segment, `confluence`, is the file's, so the operator says the
  cloud id and nothing of the path.

Both take Basic, so only the base differs, and every path in the file starts at
`/api` or `/rest`. The yard keys a credential to the host, and to the cloud id
after it for a site, so a key given for another site (or for a host) is held back
until it is given again: SETUP.md puts the address before the key. That holding
back is yardr's, and its own tests prove it; the test here pins the addresses and
the flow. A copy of the declaration added with `yardr source add`, which an earlier
SETUP.md had a token with scopes make, is replaced by a pack applied again and the
placeholder comes back; the test pins that, and SETUP.md step 6 says how to move
over. Unlike `jira`, this pack needs no command of its own to refuse to send
there, since all its calls are declared and the yard holds them.

## Files

- `pack.yaml`, `confluence.yaml`: the pack, with the `read`, `create` and
  `update` presets, and the declaration.
- `confluence/mint`: sh and jq, the Basic credential from the email and the
  token. It prints a fixed line on failure, since jq's own errors quote the value.
- `SETUP.md`: the account, its token, the address, the grant, the first calls.
- `.gitignore`: the operator's copy of the declaration.
- `test`, `testdata/`: the tests. `calls/` holds a `.case` for each scenario
  (the call, the stand-in's answer and status, and a `note` where the answer's
  source matters) and the `.golden` of what happened; `standin.py` is the
  stand-in for Confluence, which also logs the body of a write;
  `declaration.golden` and the two `*.requests.golden` pin the rest.

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

in this directory, about five seconds, no network and no secret. The gate
(`.yardr/test`) runs `yardr pack check` first.

- `mint`: the value, the expiry, what it says when an input is missing or empty,
  and that the token is in no argument of anything it runs.
- the declaration as the yard reads it against `testdata/declaration.golden`, and
  that it has its `base_template` and its `path_template`, that the nine reads are
  each a GET, that the only updates are `create` (POST) and `update` (PUT), that no
  title or body is logged, and that the ids and `version` are.
- the real yardr in a scratch yard with its own home, the pack applied, and a copy
  of the declaration aimed at the stand-in on a loopback port, which the credential
  reaches as the right Basic value: the check call; a `.case` for each call, with
  its first page and its next, its default and its given parameters (`children`
  once for each of the five kinds, each on a node and a path segment of its own,
  `comments` and `replies` once for each of their two), an answer over the bound
  (`page`, `comments`, `replies` and `attachments`), the statuses 400, 401, 403
  and 404, and the parameters the call must refuse (an id with a slash on each
  call that takes one in its path, an account id that brings a query of its own,
  a missing id, a body format, a CQL of 2001 characters, a limit that is no
  number, a `kind` in the singular or one from another call, no `kind` on
  `comments`), each of which sends no request. A changed path, query, select,
  bound, pattern or enum value is a changed golden. The case of `user` answers
  with an email, an avatar and a time zone, and the test checks beside its
  golden that the call keeps three keys and none of those.
- the writes, in the same scratch yard. `create` and `update` each have a `.case`
  whose answer carries the page's body back, as the schema allows; the stale
  version's 409 with the title Atlassian's ticket shows, a 401 for a token without
  the write scope, a 403 and a 404 (`update` has all three, `create` the 401 and
  the 404), and a 400 for markup Confluence refuses. Each parameter the calls must
  refuse has a case that sends no request: no parent, a space's key for its id, a
  page's title for its id, an empty title, a title of 256 characters, a body of
  60001, no version, a version that is no number, an id with a slash, and no
  title on an update. The stand-in logs the body of a request as JSON with its
  keys sorted, so a golden shows what Confluence would have been sent. Beside the
  goldens, which a rewrite would pass, the test holds each body's keys (the five
  of `create`, the five of `update`, no `parentId`, `spaceId` or `ownerId`, and
  status `current`), that `version.number` goes as a number, that neither write
  sends a query, what the record of each call keeps (the ids and the version, and
  the names of the title and the body), that a page's body and title are in no
  file of the yard's home and its body in no output though Confluence's answer
  carries it, and that a grant of `read` gives a crew member neither write while
  `create` and `update` are granted by their names and stand across a pack applied
  again. Five mutations of the declaration (a title logged, the body selected into
  the answer, a parent sent, a draft status sent, the version taken from the id)
  were each caught when the test was written.
- the calls again through the gateway's address, which `yardr source set
  confluence site=<cloud id>` makes from the path template, with the key given
  after it as SETUP.md has it. The file's template is https at Atlassian's, so the
  copy has its scheme and host replaced by the stand-in's and keeps its path, and
  `testdata/gateway.requests.golden` holds the requests with the cloud id in the
  path. A template that made another path, or none, is a changed golden.
- a pack applied again over an edited address: the plan names the address it
  takes away, the shipped address returns, and the env file and a grant stand.
- a host given with `yardr source set confluence host=` (SETUP.md step 2): it
  makes `https://<host>/wiki`, which `source show` names first; it stands across
  a pack applied again, with the env file; it stands over a copy added after it,
  so that `host=` clears it and the copy's address is the one in use. No call
  goes through it here: the template is https and the stand-in is plain http.
- a site given with `site=` (SETUP.md step 2), the same ways: it makes the
  gateway's address with the cloud id in it, using the cloud id that SETUP.md
  gives as its example, so that the example is held to what the template makes;
  it stands across a pack applied again and over a copy added after it; a host
  given after it takes its place and a site after a host takes it back; and
  `site=` with nothing after it gives the copy's address back. That a key given
  for one site is held back from another is the core's, and is not run here.
- the token and the credential made of it are in no file of the run but the env
  file: not an output, not the yard's store, events or log.

`UPDATE_GOLDEN=1 ./test` writes the goldens again. Read the diff before you
commit it.

## What was checked, and what was not

Checked on 2 November 2026 against Atlassian's pages: the first four requests, their
parameters and scopes in the OpenAPI descriptions of v2 and v1; that pages,
folders, whiteboards, databases and embeds each have a `direct-children`, none of
them deprecated, with the one scope, the same parameters (`id`, `cursor`, `limit`
from 1 to 250 and 25 by default, `sort`) and the same answer type; the
deprecation of `GET /pages/{id}/children`; the gateway's address for a
token with scopes and that Atlassian's own examples send it as Basic; that a 401
is the answer to a missing scope and to an account without access. Seen on a
public Confluence Cloud site without a login (openmrs.atlassian.net): the shapes
of the answers of the first four requests (`children` on a page's id), the cursors,
that v1 search takes its cursor alone, and `tenant_info`.

Checked on 4 November 2026 for `comments`, `replies`, `labels` and
`attachments`: the requests, their parameters and the scope of each
(`read:comment:confluence` for comments and replies, `read:page:confluence` for
labels, `read:attachment:confluence` for attachments) in the OpenAPI description
of v2. Seen on the public site without a login: a page's footer comments, which
are the root comments and no reply; a reply at its comment's `children`; a
comment with no body when no format is named; a page's labels and attachments;
the cursors of a page's footer comments and of its attachments, followed to the
next page; and the answers for a page or a comment that is not there (above).

Checked on 4 November 2026 for `user`: in the OpenAPI description of v1, the
request, its parameter (`accountId`, required, a string), its answers 200, 401,
403 and 404, its scope (`read:confluence-user`, with
`read:content-details:confluence` beside it as beta) and the keys of the answer,
in the description's `User`, which has the three kept (`accountId`,
`accountType`, `displayName`) among its 18 keys; in the description of v2, that
no GET reads a user (the four `likes/users` answer ids alone) and that its one
lookup by id is `POST /users-bulk`. Seen on the public site without a login: the
endpoint answers 403 to an anonymous caller, for the two ids tried, which were no
account, with `User not permitted to view user profiles`. So the 403 is seen, and
the 404 and the shape of an answer are the description's.

Tried on 22 November 2026 for `base_template`, in a scratch yard with yardr build
6906121f7ad1: `yardr source set confluence host=<host>` makes `https://<host>/wiki`;
a pack applied again keeps it; a host with a path or a scheme is refused; a copy
with the gateway's base added over a host that is set still calls the host, until
`host=` clears it; and a crew member's card for the same command is accepted and
shows the address now and the one it sets. Approving a card needs a person at a
terminal, so none was approved, and no call went through a host.

Tried on 24 November 2026 for `path_template`, in scratch yards with yardr build
80fc32ad6228: `yardr source set confluence site=<cloud id>` makes
`https://api.atlassian.com/ex/confluence/<cloud id>/wiki`, which `source show`
names first with `(site <cloud id>)`; a pack applied again keeps it; `host=` and
`site=` replace each other, and `site=` with nothing after it is the placeholder;
a site with a slash, a space, `..`, a scheme, a `?` or a `#` is refused in the
words of the check; on the version of this pack before the template `site=` was
refused, since the declaration named none; a pack applied over a copy made as
SETUP.md step 2 used to say plans `base: <the copy's address> ->
https://example.atlassian.net/wiki` and `path_template: (none) ->
https://api.atlassian.com/ex/confluence/{site}/wiki`; and a user's card for the
same command is accepted and shows the address now, the one it sets with the site
named, and `yardr source set confluence site=` as the way back; with a key
standing, the card that moves the source to another site says the key is held
back from the new one until it is given again, and names the site it was given
for. No card was approved, which is a person's at a terminal, and no call went
through a site: that a key given for the gateway's host alone is held back from a
site on it is the core's own account of it (`yardr docs integrations`), and was
not run here, since a call would have gone to Atlassian.
`curl https://yardr.atlassian.net/_edge/tenant_info`
answered `{"cloudId":"f84cdad3-1764-4e23-a125-a6259e2fcb7a"}` without a login, the
id SETUP.md step 2 uses as its example.

Checked on 22 November 2026 for `create` and `update`, in the OpenAPI description of
v2 (2.0.0): both requests, the one scope each lists (`write:page:confluence`,
"Create and update pages and blog posts and their properties"; the description
names no `write:confluence-content`), the fields each body requires (`spaceId`
for `create`; `id`, `status`, `title`, `body` and `version` for `update`), the
rule for `version.number` ("the current version number plus one"), the answers
each lists (`create`: 200, 400, 401, 404 and 413; `update`: 200, 400, 401, 404
and 409, which is content approvals), the statuses `current` and `draft`, the
restoring of a trashed page by an update, and the merge into a draft. In
Atlassian's own pages: that a scoped token without the scope an endpoint needs is
a 401 (its support article on a service account's 401); the body of a stale
version's 409 and of a 400 for markup (its tickets CONFCLOUD-76640 and
CONFCLOUD-83933, the second also showing the request's shape, and a
developer-community thread of January 2026 that says v2's error body is
undocumented); and the names of Confluence's current space roles and permissions
(Collaborator; Create content and Edit content). Neither write was called, with a
login or without. The scope picker needs a login and was not opened, so the scope
is the description's and not the picker's.

Not checked with a credential against a site of our own, because a person has to
make one (a free Atlassian Cloud site serves this pack and the Jira one). The
live proof is a later bead. It should settle:

- that a token with scopes is accepted as Basic at the gateway, as Atlassian's
  support pages say. A community thread says only Bearer works there. If a site
  answers 401, the fix is in `confluence/mint` and the header in
  `confluence.yaml`;
- that the first four scopes are enough. `search:confluence` is the one the v1 page
  lists as current, beside `read:content-details:confluence` as beta; if search
  answers 401 under the first alone, the second is added to the token;
- whether a service account can make one token with the scopes of both apps, which
  would make the Jira token serve here;
- what the account sees in a space that lets every user of the site view it;
- what `children` answers for a folder, whiteboard, database or embed. Those four
  endpoints are read in Atlassian's description and not called, with a login or
  without, and the cases' answers are made like the page's. The live proof needs a
  node of each kind that has children;
- a very long page, and a space with thousands of children;
- an inline comment. The public site had none, so what the pack says of
  `resolutionStatus` and `properties` on one is the description's, and the
  fixtures of `comments` and `replies` with `kind=inline` are made from it. The
  live proof needs a page with an inline comment and a reply to it;
- that `read:comment:confluence` and `read:attachment:confluence` are enough for
  the four new calls, as the first four scopes are for theirs;
- that `read:confluence-user` is enough for `user`. The description lists
  `read:content-details:confluence` beside it as beta, as it does for `search`;
  if `user` answers 401 under the first alone, the second is added to the token;
- what a real account answers: the 404 for an id that is not there; whether
  `displayName` is ever null (the description marks it nullable, and says
  `publicName` always has a value); and what an account that limits its profile
  visibility, a deactivated one and an app's bot user show. The `app` and the
  empty `accountType` are the description's;
- that `write:page:confluence` alone is enough for both writes, as the description
  says, and that a token with it is taken as Basic at the gateway for a POST and a
  PUT as for a GET;
- what a stale `update` answers from a site of our own: that its 409 and title
  are as the ticket and the thread show, and what the other 409, the approvals
  one, says in its body. Both were seen as text and not from a site;
- what `create` answers: whether the page comes back with its body (the select
  drops it either way), and what a title already in the space and a parent in
  another space answer; and the longest title and body Confluence takes, the
  bounds of 255 and 60000 characters being this file's;
- whether Confluence takes a body with a link by title (an `ac:link` holding an
  `ri:page`) now, which a ticket says it refused in March 2026 and fixed in June,
  and what else the markup of a status page needs;
- what an update does to a person's unsaved draft of the page (SETUP.md step 5),
  whether a page a person restricted answers the account 404, and whether a rename
  through `update` rewrites the links that name the page by its title.

## Left out

An attachment's contents (a file's bytes are yardr-racg's to settle);
blogposts, and the comments, labels and attachments of one; the comments, labels
and attachments of anything but a page (a space, an attachment, custom content);
several accounts named in one call (`user` names one, and an agent calls it for
each. v1's `GET /wiki/rest/api/user/bulk` takes `accountId` as a list that its
description does not say how to write; OpenAPI's default for a query is one key
for each value, and a declared call holds one value to a query key. v2's `POST
/wiki/api/v2/users-bulk` takes up to 250 ids in a body, and no parameter is a
list. yardr-packs-fjmg weighs it); what else of an account `user` could give
(its email, picture, public name and time zone, which the `select` drops on
purpose); the `sort`, `status` and `resolution-status` filters of the comment
lists, the `prefix` filter of labels and the `mediaType` and `filename` filters
of attachments; comment likes, versions and properties;
reading a folder, whiteboard, database or embed itself (a walk lists one with
its title, and `page` takes a page's id only); page history and versions; any
write but `create` and `update`, so no delete, no move to another parent or
space, no change of a page's owner, no draft, no comment, label or attachment
written, and no page at the root of a space; macros built by a call (a body is
sent as it is given, and Confluence judges it); a retry or a merge of a stale
version, which the agent does by reading the page again; a second credential
for the writes (one login serves both, as `google-docs`' does); turning storage
format into text, or text into it; and Confluence Data Center and Server, whose
API and login are others. Each is a later bead.
