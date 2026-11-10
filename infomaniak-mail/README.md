# infomaniak-mail

Infomaniak mail, as a twin of the `google-mail` source. A yard can list a mailbox's folders, search and read mail, list drafts and write drafts, as `yardr call infomaniak-mail ...`. The pack sends no mail. It moves, marks, flags and deletes none.

**Not tried against Infomaniak.** The pack was built from the source of Infomaniak's own MCP server and run against a stand-in. No request has been made to mail.infomaniak.com, because there was no account to make one with. "What was checked" lists what that leaves open, and the first call against a live mailbox is the real check.

The calls are the webmail's backend, not Infomaniak's documented API (developer.infomaniak.com does not list them). Infomaniak's MCP server uses them, and Infomaniak may change them without notice.

The pack declares the source and carries one program, `build-draft`, which builds the body of a draft. It needs Python 3.9 or newer on the `PATH` of the yard's server, and nothing else. [SETUP.md](SETUP.md) lists what the operator sets up. `.yardr/test` runs `yardr pack check` and this pack's `test`.

| file | what it is |
| --- | --- |
| `pack.yaml` | the pack: kind `source`, the source it declares, two suggested presets (`read`, `drafts`) |
| `infomaniak-mail.yaml` | the source: Infomaniak's base, one bearer token, six calls |
| `build-draft` | the program: the body of a `draft`, parameters on stdin, one JSON message out |
| `SETUP.md` | what the operator does: the token, the pack, the grants, a check, a first call |
| `test`, `testdata/` | the pack's tests, a stand-in for the service, its fixtures and the goldens |

## The calls

`read` grants the five reads together. `draft` is the one update and is granted by its name. The yard shows each answer as data from outside the yard: mail is whatever anyone sent the account, so it carries no instruction.

| call | kind | takes | answers |
| --- | --- | --- | --- |
| `mailboxes` | read | nothing | `data`: each mailbox with its `uuid`, `email`, `mailbox`, `is_primary` and `aliases`. The source's check call. |
| `folders` | read | `mailbox` | `data`: the folder tree, each folder with its `id`, `name`, `role`, counts and `children`. |
| `search` | read | `mailbox`, `folder`, `maxResults`; `q`, `from`, `to`, `subject`, `since`, `before`, `everywhere`, `offset` | `data.threads`: one entry for each message found. |
| `message` | read | `mailbox`, `folder`, `id` | `data`: the message, with its headers, its text and its HTML. |
| `drafts` | read | `mailbox`, `folder`, `maxResults`; `offset` | `data.threads`: the mail of the folder named. |
| `draft` | update | `mailbox`, `from`, `to`, `subject`, `body`; `cc`, `in_reply_to`, `references`, `in_reply_to_uid` | `data`: the draft's `uuid` and `uid`. |

Every answer is `{result, data}`, as the service gives it, and each call keeps both. An answer over the call's bound is refused, not cut: 1 MiB for `message`, 256 KB for `search` and `drafts`, 64 KB for the rest. A smaller `maxResults` brings a search under its bound.

### How the ids go

Infomaniak names a message by three things, where Gmail names it by one. `mailboxes` gives the mailbox's `uuid`, which is in every other address. `folders` gives each folder's `id`, which is in the address of every search and read. `search` gives each message's `uid`, which reads `<number>@<folder id>`: `message` takes the folder id and the number. The mailbox is found by that call and not typed at setup, so the declaration is the same for everyone and an account with several mailboxes works.

A folder id looks like base64 of the folder's path, compressed: the server's tests show `eJwLTs0rAQADzwGb` for `Sent`, which decodes and inflates to `Sent`. So it can hold `/`, `+` and `=`, and the patterns allow them. Give it as it stands: yardr sends a `/` in it as `%2F`.

### `search`

`q` is the service's `scontains`: free text in the body and the headers, with none of Gmail's syntax. `from`, `to` and `subject` filter on the headers. `since` and `before` take a date and a time as the service does, `2026-06-01 00:00:00`. `maxResults` is 1 to 50 and always given, as in `google-mail`. `offset` is how many results to skip, so the next page is `offset=<maxResults>`: `google-mail` leaves paging out, and the service makes it one number.

`everywhere` is 1 unless given. The service puts the folder in the address and, with `severywhere=1`, searches every folder from it. The server gives its INBOX's id, so give that one. `everywhere=0` keeps the search to the folder given, and with no term at all it lists that folder's newest mail. A message found in another folder says so in its `folder_id`: read it from there.

The server refuses a search with none of `q`, `from`, `to`, `subject`, `since` and `before`. The pack does not: a declaration cannot say "one of". What the service answers to an unfiltered search across every folder is not known.

### `drafts`

The service lists a folder's mail by one request, so `drafts` is that request with `thread=on` for the folder named, which is meant to be the one whose role is `DRAFT`. It takes any folder's id. A grant of `drafts` is a grant to list any folder's threads with their previews, so grant it with `read` in mind.

### `draft`

A draft is `to`, `subject` and `body`, one address in `to` and at most one in `cc`, as `google-mail`'s. The program makes the HTML the service wants from the text: it escapes `& < > " '` and turns a newline into `<br>`, as the server does. `from` is the mailbox's own address as `mailboxes` shows it. The service sends from the account's default identity whichever address is given, and the display name is the account's. The pack sets no sending identity, because those come from another host (api.infomaniak.com) and the pack declares one.

To answer a message, give the three headers `message` shows: `in_reply_to` is its `msg_id`, `references` is its `headers.references` with its `msg_id` added at the end, and `in_reply_to_uid` is its `uid`, `<number>@<folder id>`. The server derives the first two from the third when they are missing, with a read of its own. A declared call cannot read first, so the caller does.

Infomaniak takes no idempotency key. A draft tried again after a lost answer is written twice.

## What `google-mail` has and this does not

| `google-mail` | here |
| --- | --- |
| `thread`, a thread read whole | **Left out.** The server has no call that reads one thread: it lists a folder's threads (`drafts` does that for any folder) and reads one message (`message`). `message` asks the service for its `thread_context` and keeps whatever it answers, which is untried. Building a thread from several requests in a program is not a call of this pack. |
| `draft_edit`, a draft replaced by its id | **Left out.** The service has no partial update: a `PUT` to `/draft/{uuid}` replaces the whole message, and the server keeps each draft's state in its own memory to do it. Here an edit would take a read first. A draft that changed is written again, and the old one stays in Drafts, which no call here deletes. |
| `format` of `message` | None. The service answers the whole message, HTML and text. |
| `q` of `drafts` | None. The server never sends search terms with `thread=on`, the way it lists drafts. |
| `thread` of `draft` | The three reply headers above. |
| `raw` | None. The service takes a JSON message, not RFC 2822. |

Also left out: `bcc`, more than one address in `to` or `cc`, attachments (an upload with an endpoint of its own), the sending identity, contacts, creating, renaming and deleting folders, and everything that sends, moves, marks, flags, archives or deletes mail. There is no mint: the token is long-lived. Nor is there an IMAP fallback (the mailbox over IMAP on `mail.infomaniak.com`, through a program like `proton`'s): it would read mail and write no draft, and it is worth a pack of its own only if these calls prove unstable.

## How it never sends

What tells a draft from a mail sent is the `action` in the message's body, `"save"` or `"send"`. The server sends a draft by the same message with `"send"`, in a `PUT` to `/draft/{uuid}`. Whether a `POST` with `"send"` would send too was not tried, so the pack treats the field as the one thing between a draft and a sent mail. Four things keep it to saving, and the test holds each:

1. The declaration has no call that sends, moves, marks, flags, archives or deletes. Its five reads are `GET`s, and its one update is the `POST` to the draft's address.
2. `build-draft` writes the message. It sets `action` to `"save"` and reads it from nothing, and it builds only from the parameters it lists. A parameter it does not list is refused.
3. yardr refuses an argument the call does not declare before the program runs, so `yardr call infomaniak-mail draft ... action=send` sends nothing.
4. The test runs every case against a stand-in, and every request it saw must be a `GET` of the mailboxes, the folders or a message, or a `POST` to a draft whose body says `save`.

What the pack cannot do is narrow the token. Infomaniak scopes a token by product, so a token with `workspace:mail` could send as well. The declaration is the fence, and a process that reads the env file (`~/.yardr/sources/infomaniak-mail.env`, mode 0600) as the same user could use the token as it likes. That is true of every source of the yard.

yardr gives `build-draft` the token in its environment, as it does to any build command. The program does not read it and makes no request, and the test fails if it imports anything that reaches a network or the environment.

## What was checked

- Infomaniak's MCP server, github.com/Infomaniak/mcp-server-mail, at `main` 392ee8a (6 November 2026, package 2.1.0), read on 10 November 2026: `README.md`, `src/index.ts`, `src/mail-client.ts` and `tests/mail-client.test.js`. From them come every address, query, body field and answer shape here, and the fixtures in `testdata/answers/`, which follow the mocked answers of the server's tests. The message `build-draft` makes is `createDraft`'s, field for field and in its order.
- `google-mail` in the yardr repository (`packs/google-mail`), for the names and arguments.
- The declaration and the program, through the real yardr in a scratch yard against a stand-in (`testdata/standin.py`): the pack applies, `source check` makes the check call with the token, each call is made with `yardr call`, and what each sends is in a golden.
- The cards SETUP.md names, in a scratch yard on 10 November 2026, asked as a user of the yard: `--secret infomaniak-mail` and `--run "source grant ..."` are accepted, and `--setup infomaniak-mail` is refused, because yardr sets up only a pack it embeds ("yardr embeds no pack of that name ... the operator's to apply in a terminal"). So a crew member cannot set this pack up with one card, as for `google-mail`: the operator applies it, and the token and each grant go on cards of their own.

**Not checked: a live Infomaniak.** The stand-in follows the server's mocks, not the service's answers. The first call against a live mailbox is the real check. Look at:

- whether the token is accepted and what status a wrong one gets. The fixtures' error bodies are `{"result": "error"}` and are not the service's.
- the `with` of `mailboxes` and `folders`, which yardr sends as `aliases%2Cpermissions%2CaccountId%2Ccount_users` where the server writes the commas bare.
- a folder id with a `/` or a `+`, which yardr sends as `%2F` and as it stands. The server writes an id raw into every address but its attachment download's, where it encodes it.
- a search across every folder, anchored on the INBOX's id, with and without a term, and with a time that is not midnight.
- the size of real answers. The service probably sends more fields than the mocks, so a `message` or a `search` can come near the bounds above.
- a draft: that the service accepts a `from` and a null `identity_id`, that the draft lands in Drafts and opens in the webmail, and that the reply headers thread it.

## Limits

Infomaniak allows 60 requests a minute, the figure this pack was asked to respect; it is not in the MCP server's source, and nothing here checked it. yardr's limits are per hour: one caller makes 60 calls of a source an hour, 10 of them updates. Raising `calls_per_hour` is the operator's to keep under the service's minute.

## The tests

Run `./test` in this directory, or `sh .yardr/test` from the repository, which also runs `yardr pack check`. The test needs `jq`, `python3` and `yardr`, and fails if any is missing instead of skipping. It needs no network and no secret, never touches Infomaniak, and takes a few seconds. It has two parts, cheapest first:

1. `build-draft` as a process, run as the yard runs it, over `testdata/build/*.in`. Each message it makes is held to the server's fields in the server's order and to `action: "save"`, and the text of the server's own escaping test must come out as that test expects. Its refusals are one line each.
2. The real yardr in a scratch yard. It applies the pack from this directory, reads the declaration back (`testdata/declaration.golden`), runs the grants SETUP.md teaches exactly as written, and makes every case of `testdata/calls/*.case` through `yardr call` against the stand-in, which answers the fixtures. A call the declaration should turn away shows in its golden as no request at all. The token is a made-up string, and the test holds it to the one file that keeps it.

`UPDATE_GOLDEN=1 ./test` writes the goldens again from what the programs print. Read the diff before you keep it.
