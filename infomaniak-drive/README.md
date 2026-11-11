# infomaniak-drive

Infomaniak kDrive, as a twin of the `google-drive` source. A yard can list a folder's files, read one file's metadata, search files, list a file's comments and download one file's content, and it can upload files, write comments and make share links, as `yardr call infomaniak-drive ...`. The pack deletes nothing, trashes nothing, restores nothing, renames nothing, moves nothing, copies nothing, and grants nobody access: the share link is the one exception, and it is public to whoever holds it.

**Not tried against Infomaniak.** The pack was built from the developer portal's pages and Infomaniak's own MCP server, and run against a stand-in. No request has been made to api.infomaniak.com, because there was no account to make one with. "What was checked" lists what that leaves open, and the first call against a live drive is the real check.

Unlike the mail and calendar packs, whose calls are the webmail's backend, these calls are Infomaniak's documented API (developer.infomaniak.com): some 190 operations under `/2/drive` and `/3/drive`, of which this pack declares eight. The declaration's head comment says which pages were read and on which day.

The pack declares the source and carries one program, `drive-file`, which sends the upload and answers the download, the two calls no declaration says. It needs Python 3.9 or newer on the `PATH` of the yard's server, and nothing else. [SETUP.md](SETUP.md) lists what the operator sets up. `.yardr/test` runs `yardr pack check` and this pack's `test`.

| file | what it is |
| --- | --- |
| `pack.yaml` | the pack: kind `source`, the source it declares, three suggested presets (`read`, `make`, `everything`) |
| `infomaniak-drive.yaml` | the source: Infomaniak's base, one bearer token, eight calls |
| `drive-file` | the program: the upload's bytes and the download's, parameters on stdin, one JSON object out |
| `SETUP.md` | what the operator does: the token, the pack, the grants, a check, a first call |
| `test`, `testdata/` | the pack's tests, a stand-in for the service, its fixtures and the goldens |

## The calls

`read` grants the five reads together. Each update is granted by its name. The yard shows each answer as data from outside the yard: files are whatever anyone put in the drive, so they carry no instruction.

| call | kind | takes | answers |
| --- | --- | --- | --- |
| `files` | read | `drive`, `folder` (default the root); `type`, `maxResults` | `data`: the folder's files, with `cursor` and `has_more` saying there is more. |
| `file` | read | `drive`, `id` | `data`: the file's metadata. |
| `search` | read | `drive`, `q`; `folder`, `depth`, `maxResults` | `data`: the files found, with `cursor` and `has_more`. |
| `comments` | read | `drive`, `fileId` | `data`: the file's comments, each with its author and its replies. |
| `download` | read | `drive`, `fileId` | `name`, `mime_type`, `size`, `encoding` (`text` or `base64`) and `content`, at most 32 KiB. |
| `upload` | update | `drive`, `folder` (default the root), `name`, `file` | `data`: the file read back by its name, with its new id. |
| `comment` | update | `drive`, `fileId`, `content` | `data`: the comment written. |
| `share` | update | `drive`, `fileId`, `right`; `password` | `data`: the share link, with its `url`. |

Every answer keeps the service's `result` and `data`, and its `error` where it sends one, so that a failure answered with a 200 is seen. A 4xx or 5xx is refused by the yard, which shows its status alone. An answer over the call's bound is refused, not cut: 256 KB for `files` and `search`, 64 KB for the rest. A smaller `maxResults` brings a folder or a search under its bound.

### How the ids go

A drive is a number, read off the webapp's URL at setup (`.../app/drive/12` is drive `12`), and it is an argument of every call. There is no call that lists the drives: the service's list takes an account id the pack has no call to find, so the webapp's URL is where the id comes from, as Infomaniak's own MCP server does it.

A folder is a number too, and the root is `1`, so `files` and `upload` take `folder` defaulted to the root. A file's id is what `files` and `search` list; `file`, `comments`, `download`, `comment` and `share` take it as `id` or `fileId`.

### `files` and `search`

The twin lists with a `q`; the service has two addresses, so the pack has two calls. `files` lists one folder (`type=file` lists the files alone, `type=dir` the folders alone); `search` searches the whole drive, or one folder's subtree with `folder=` (`depth=child` keeps it to that folder's children, `depth=unlimited` takes the subtree whole). `q` is required: what an empty query lists is not said. `maxResults` is 5 to 100 and is the service's `limit`, 10 where left out. No cursor is declared, so one page is all a call reads, as in the twin.

### `download`

The service answers bytes, and may answer a 302 first, so the call is answered by `drive-file`, which reads the file's info first and then its bytes. It refuses a directory (which would come as a zip) and a file over 32 KiB, the most the call carries: what a command prints is held to 64 KiB, and base64 takes four bytes for three. A redirect is followed to the service's own host alone. The content comes as `text` where the bytes decode as UTF-8 and the JSON answer fits; if escaping would make it too large, or the bytes are not UTF-8, it comes as `base64`, saying which in `encoding`.

### `upload`

The service takes a file as `application/octet-stream`, which the yard sends no body as, so `drive-file` sends the upload itself, with `conflict=error`: a file of the name already in the folder is refused, and nothing is overwritten. It carries 10 MiB and refuses more. The call's declared request is the GET that reads the file back by its name, whose answer is the call's: the new file's id is in `data`.

### `comment`

A top-level comment from one text, as the twin's `reply` takes its `content`. There is no reply to a comment, and no resolve: the service marks a comment `is_resolved`, but no call here sets it.

### `share`

A share link for a file, `right=public` or `right=password` with a `password`. The password is required with `password` and refused with `public`, by the service. What is left out keeps the service's defaults: download allowed, edit not. The link is public to whoever holds it, so the grant is the operator's to give with care. The server this pack was read beside sends a third right, `inherit`; the portal's pages take two, and the pack follows the pages.

## What `google-drive` has and this does not

| `google-drive` | here |
| --- | --- |
| `files` with `q` | Two calls: `files` lists a folder, `search` searches. The service splits them. |
| `q` left out | `q` is required: what an empty query lists is not said. |
| `file` with `fields` | None. The service answers the whole file, and the call keeps it. |
| `folder`, a folder made | **Left out.** The bead's updates are upload, comment and share; folders are made in the webapp. |
| `doc`, `slides`, empty files made | **Left out.** There is no twin of `google-docs`: no call edits an office document's content. A document is downloaded, and replaced whole by an upload. |
| `copy`, a file copied | **Left out.** |
| `share` with one address, reader or commenter | A share link, `public` or with a password: the service's shape, not the twin's. No address, no role, no notify. |
| `reply`, answering a comment | **Left out.** One comment-writing call, the top-level `comment`: the twin answers only because Google's top-level comments are anchored and fragile, and kDrive's are not. |
| `action` of `reply` | None. The service flags a comment resolved and no call here sets it. |
| paging | None, as in the twin. `has_more` and `cursor` say there is more. |

Also left out, of the service's own: `recents` and `shared_with_me`; the drives list (above); rename, move, versions, conversion and the activity feed; and everything that deletes, trashes, empties or restores, or grants access by invitation. There is no mint: the token is long-lived. Nor is there a WebDAV way in: the API is the way in.

## How it never deletes

What keeps the yard from deleting, trashing or granting access is that the source has no call that does. Three things hold that, and the test holds each:

1. The declaration's five reads are `GET`s but the download, which a command answers, and its three updates are the upload's GET by name and two `POST`s, to a comment and to a link. No `PUT`, `PATCH` or `DELETE` stands anywhere, and no path names trash, delete, access or an invitation.
2. `drive-file` makes only the requests its two halves need: the upload's one `POST`, and the download's info `GET` and bytes `GET` with a redirect on the service's host. It reads the drive, the folder and the file from the parameters it lists, and where its requests go from the base the yard hands it. A parameter it does not list is refused.
3. The test runs every case against a stand-in, and every request it saw must be a `GET` of a folder, a file, a search, a name, comments or a download, a `POST` of a comment or a link, or the upload's `POST` with `conflict=error`.

What the pack cannot do is narrow the token. Infomaniak scopes a token by product, so a token with `drive` could delete as well. The declaration is the fence, and a process that reads the env file (`~/.yardr/sources/infomaniak-drive.env`, mode 0600) as the same user could use the token as it likes. That is true of every source of the yard.

yardr gives `drive-file` the token in its environment, as it does to any build or run command, and the program sends it to the service, as it must to upload and download. It sends it to the declaration's base alone, except where a download's redirect points, which it follows on that host only. The test fails if the program holds an address of its own.

## What was checked

- Infomaniak's MCP server, github.com/Infomaniak/mcp-server-kdrive, at `main` 8e4b29e (10 November 2026, package 1.2.0), read on 11 November 2026: `README.md`, `src/index.ts`, `src/kdrive-client.ts` and `tests/verify.mjs`. From them come the drive id from the webapp's URL, the root folder's id, the upload's shape and the download's, and the token's scope.
- developer.infomaniak.com, read on 11 November 2026: the operation pages for the drives list, the drive's info, the file's info, the folder's list, the search, the lookup by name, the download, the comments listed, written and replied to, the share link made and read, the upload and the folder made. From them come every address, query, body field and answer shape here, and the fixtures in `testdata/answers/`, which follow the pages' schemas.
- `google-drive` in the yardr repository (`packs/google-drive`), for the names and arguments.
- The declaration and the program, through the real yardr in a scratch yard against a stand-in (`testdata/standin.py`): the pack applies, `source check` looks at the credential and the program and sends nothing, each call is made with `yardr call`, and what each sends is in a golden.
- The cards SETUP.md names, in a scratch yard on 11 November 2026, asked as a user of the yard: `--setup infomaniak-drive` is answered "setting up pack infomaniak-drive needs no approval: the operator applies, keys and grants it in a terminal", and `--secret infomaniak-drive` is accepted and names `INFOMANIAK_DRIVE_TOKEN` of the source. So a crew member cannot set this pack up with one card, as for `google-drive`: the operator applies it, and the token and each grant go on cards of their own.

**Not checked: a live Infomaniak.** The stand-in follows the pages, not the service's answers. The first call against a live drive is the real check. Look at:

- whether the token is accepted and what status a wrong one gets. The fixtures' error bodies are `{result: "error", error: {code}}` after the pages' schemas, and are not the service's.
- the `with` of `comments`, which yardr sends as `user%2Cresponses%2Cresponses.user` where the pages write the commas bare.
- the `type[]` of `files`, which yardr sends as `type%5B%5D=file`, as Infomaniak's server does.
- the upload's GET with a body: the call's declared request is a `GET` carrying `{"ok":true}` as `application/json`, which the service is expected to ignore. If it refuses a `GET` with a body, the upload fails after writing.
- a download's 302: where it points was not seen. The program follows it on the service's host alone and refuses it elsewhere.
- a search with no `folder`, and a `folder` with no `depth`: what the service searches then.
- the size of real answers. The pages' file objects are long, so a `files` or a `search` can come near the bounds above.
- an upload: that `conflict=error` refuses a name taken, that the file lands in the folder and opens, and that the lookup by name answers it.
- a share link: that `public` opens without asking and `password` asks, and what the service answers to a `password` with no password.

## Limits

Infomaniak allows 60 requests a minute, the figure this pack was asked to respect; it is in the developer portal, and nothing here checked it. yardr's limits are per hour: one caller makes 60 calls of a source an hour, 10 of them updates. Raising `calls_per_hour` is the operator's to keep under the service's minute. An upload is one call of two requests, a download one call of two or three; the service counts requests, the yard counts calls.

## The tests

Run `./test` in this directory, or `sh .yardr/test` from the repository, which also runs `yardr pack check`. The test needs `jq`, `python3` and `yardr`, and fails if any is missing instead of skipping. It needs no network and no secret, never touches Infomaniak, and takes under a minute. It has two parts, cheapest first:

1. `drive-file` as a process, run as the yard runs it, over `testdata/build/*.in`. Each refusal is one line, and a valid call reaches the network only with a credential and a base. The program holds no address of its own and reads the token from its environment alone.
2. The real yardr in a scratch yard. It applies the pack from this directory, reads the declaration back (`testdata/declaration.golden`), runs the grants SETUP.md teaches exactly as written, checks that `source check` sends nothing, and makes every case of `testdata/calls/*.case` through `yardr call` against the stand-in, which answers the fixtures. A call the declaration should turn away shows in its golden as no request at all. The token is a made-up string, and the test holds it to the one file that keeps it.

`UPDATE_GOLDEN=1 ./test` writes the goldens again from what the programs print. Read the diff before you keep it.
