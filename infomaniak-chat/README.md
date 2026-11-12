# infomaniak-chat

Infomaniak's kChat, as a twin of the `slack` source in the yardr
repository. A yard hears a channel through kChat's outgoing webhook
and answers in the thread with `yardr reply`, as `yardr call
infomaniak-chat ...` reads a channel's recent posts and one thread.
Nothing is compiled into yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/infomaniak-chat
```

[SETUP.md](SETUP.md) is the operator's walk. **Nothing in this pack
has been tried against Infomaniak's service:** there was no account
to try it on, no token was asked for and kChat was not called. "What
was checked, and what was not" lists what the tests hold and what
the first live run must confirm, the outgoing webhook's creation
screen first of all.

| file | what it is |
| --- | --- |
| `pack.yaml` | the pack: kind `source`, API 7, the source it declares, two suggested presets (`read`, `post`) |
| `infomaniak-chat.yaml` | the source: the team's placeholder base, one bot token, four calls, the hook with its two programs, hearing by who speaks, and the thread commands |
| `infomaniak-chat/normalize` | the program: a verified outgoing-webhook body to the yard's envelope |
| `infomaniak-chat/thread` | the program: `reply`, `posted` and `read` in a heard thread |
| `SETUP.md` | what the operator does: the bot, the team's address, the tokens, the webhook, the identities, the grants, a check |
| `test`, `testdata/` | the pack's tests, a stand-in for the service, its fixtures and the goldens |

The programs need `bash`, `curl` and `jq`. The test also needs
`python3` and `yardr`.

## Hearing

kChat's outgoing webhook POSTs a channel post that starts with one
of its trigger words (public channels only) to the yard's hook URL,
`https://<host>/hooks/infomaniak-chat`. The body is Mattermost's
outgoing payload — `team_id`, `channel_id`, `user_id`, `post_id`,
`text`, `trigger_word`, and the webhook's `token` — and kChat signs
nothing. The declaration therefore verifies with the core's
body-secret seam (pack API 7): `hook.verify` is `scheme: secret`
with `signature: { body: token }`, so the core compares the `token`
field with the hook's secret file in constant time before anything
is read from the body, and removes the field before the body reaches
`normalize`, before it is stored and before it is hashed for dedupe.
A delivery with a wrong or missing token, or a body that is no JSON,
is refused with 401 and leaves no event. SETUP.md pins the webhook's
Content-Type to `application/json` at creation: Mattermost offers
JSON or form-encoded per webhook, and a form body carries no JSON
token for the core to read. Whether kChat's creation screen offers
that choice was not seen (FAQ 2001 walks an incoming webhook only);
if it sends form alone, hearing needs form support in the core.

`normalize` answers one envelope per body. A channel post is `type:
message, action: create`, its actor the post's `user_id` and
`user_name`, its thread `<channel_id>:<post_id>`, its text truncated
as every source's is, its mentions the `@username`s of the text, and
its fields `channel`, `team`, `sender` and `trigger` — the keys a
subscription's `--where` may name. A post with files and no text is
heard as `[file]`; nothing is fetched. Anything that is no channel
post is `type: event` and matches no subscription the setup makes.

Hearing is by who speaks, as in slack: the declaration's `hear`
matches `fields.sender` (the `user_id`) against `yardr user identity
--source infomaniak-chat`. A kept delivery is recorded with its
speaker, the yard user's name; an unmapped sender is what the hook's
`--unknown` word says — held on a mapping card under SETUP.md's
`unknown`, heard as `outside` under `allow`, dropped under `ignore`.
What an unmapped speaker writes is information, not instructions,
as with slack. The bot's own posts are dropped before hearing once
its identity is set (SETUP.md step 7): a delivery whose sender is
the answering crew member's identity, by id or by username key,
never reaches its inbox.

The outgoing payload carries no `root_id`, so a reply a person
posts inside a thread is heard as a new post whose thread is itself.
The whole thread is read back from its root with the `thread` call
or `yardr thread show` on the root's delivery. That is Mattermost's
payload, and it is the one place the hearing loses shape the service
has.

## Speaking

Every request goes to `https://<team>.kchat.infomaniak.com` (the
shipped base is the placeholder `https://example.kchat.infomaniak.com`,
which SETUP.md step 2 replaces with the team's in the yard's copy)
with `Authorization: Bearer <bot token>`. The token is the bot
account's (SETUP.md step 1), held as `INFOMANIAK_CHAT_TOKEN` in the
source's env file for `yardr call`, and in the answering crew
member's own env file for `yardr reply`. It is never the webhook's
token, and never a manager token: a manager token with the scope
`kchat` acts as its user, which is the alternative Infomaniak's MCP
server documents for its own `KCHAT_TOKEN`, and no call here asks
for one.

| what | kind | request | takes → answers |
| --- | --- | --- | --- |
| `whoami` | read | `GET /api/v4/users/me` | nothing → the bot's `id` and `username`. The check call |
| `post` | update | `POST /api/v4/posts` | `channel`, `text`; `root` optional → the post's `id`, `channel_id`, `root_id`, `user_id`, `message`, `create_at` |
| `history` | read | `GET /api/v4/channels/{channel}/posts` | `channel`; `limit` (30), `page` (0) → `order` and `posts`, newest first |
| `thread` | read | `GET /api/v4/posts/{id}/thread` | `id`, a root post → `order` and `posts`, the root and its replies |
| `yardr reply` | — | `POST /api/v4/posts` with `root_id` the thread's root | the delivery's thread and the words → the new post's `id` |
| `yardr thread show` | — | `GET /api/v4/posts/{root}/thread` | the delivery's thread → its messages, oldest first |

`read` grants the three reads together; `post` is the one update
and is granted by its name. Answering with `yardr reply` needs no
grant. The service takes no idempotency key the MCP client shows,
so `thread.posted` answers `{}` always and a reply retried after a
lost answer is posted twice, as in slack.

## Against slack

The twin's shape, and where kChat's service would not take it:

| `slack` | here |
| --- | --- |
| Events API, HMAC `v0:` signature in a header, `url_verification` challenge | outgoing webhook, no signature: the token in the body's `token` field, verified by the core; no challenge handshake exists |
| `app_mention` and `message.im`: channel mentions and one-to-one direct messages | trigger-word posts in public channels only: no direct messages, and no mention is needed beyond the trigger word |
| thread `<channel>:<thread_ts>`, replies list with `conversations.replies` | thread `<channel_id>:<root post id>`, replies by `GET /api/v4/posts/{root}/thread`; one level, so answering a reply answers the root |
| mentions are member ids, `<@U…>` | mentions are usernames, `@name`: identities match by `--key <username>`, hearing by `--id <user_id>` |
| one base for everyone, `https://slack.com/api` | per team, `https://<team>.kchat.infomaniak.com`: the shipped base is a placeholder the operator replaces |
| `chat.postMessage` takes no idempotency key; `posted` answers `{}` | the same |
| no `link`, no `thread.state`, no `thread.open` | the same |

Left out beside the bead's list (socket, direct messages, files and
reactions, slash commands, incoming-webhook posting): `notify` (a
person is not told through kChat), thread open and state, and any
read of users, teams or channels beyond `whoami`, `history` and
`thread`. Adding one is a call or a key in the declaration, not a
change to this pack's programs, except a new thread command.

## What was checked, and what was not

Read on 12 November 2026, and named in the declaration's head:
Infomaniak's Developer Portal kChat API docs (the post creation body
and the channel-history and thread routes, including their PostList
shape); FAQ 2001 (webhook directions and plan counts, and the
incoming webhook walk and post shape, but no outgoing creation
screen); `github.com/Infomaniak/mcp-server-kchat` (`README.md`,
`src/kchat-client.ts`: the Bearer header, team host, bot-account
walk, and the routes its client calls); and Mattermost's
`OutgoingWebhookPayload` and `Post` models and outgoing sender (the
webhook token in the body, with no Authorization header). The pack
also follows `packs/slack` in the yardr repository for its integration
shape and `yardr docs integrations` as landed with the body-secret
seam.

The tests (`./test`, run by `.yardr/test` beside `yardr pack
check`) hold, through the real yardr in a scratch yard and a
stand-in on a loopback port: the declaration as the yard reads it;
the grants SETUP.md teaches, run as written; each call and the check
against the stand-in, with the request it saw in a golden (a post's
method, path, body and thread root among them) and what the call
kept of the answer; a delivery with the webhook's token heard and
recorded with its speaker, one with a wrong or missing token
refused with no event, and the token in no stored body; `yardr
reply` posting into the heard thread and `yardr thread show`
reading it back; and `normalize`'s envelopes byte for byte. The
tokens are made up in the test and thrown away. No network leaves
the machine but loopback, and the test needs no secret.

**Not tried against the live service,** and what the first live run
(SETUP.md) must confirm:

- that kChat's outgoing webhook sends the Mattermost payload above
  as JSON, token field and all, and that its creation screen offers
  the Content-Type choice SETUP.md pins (if it offers form only,
  every delivery is refused as no JSON until the core reads form);
- the webhook's limits and retries, and whether a bot's own post
  fires the webhook at all (its identity is set either way, so an
  echo is dropped);
- that the bot token is accepted by every route above, what status
  a wrong one gets, and whether the bot must stand in a channel to
  read its thread as well as to answer in it;
- the real shapes of the answers: the fixtures follow the MCP
  client's use of them, and a Post or a PostList with more fields is
  kept whole by `history` and `thread` (their bound is 256 KB) and
  read field by field by `thread`;
- whether an edited or deleted post fires the webhook again, and
  what a heard post with files carries in `file_ids`.

Where this pack and the service differ, the service is right; say
so on the bead with the answer it gave.
