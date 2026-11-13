# postiz

Postiz, the social scheduler, as a source. A yard can list the workspace's channels, read what is scheduled, ask a channel for its next free slot, upload one picture, and write a post as a draft or schedule it, as `yardr call postiz ...`. The pack publishes nothing at once. It deletes, edits, threads, comments and analyses nothing.

**Not tried against Postiz.** The pack was built from Postiz's public docs and the service's own source and run against a stand-in. No request has been made to api.postiz.com, because there is no Postiz account in the yard yet. "What was checked" lists what that leaves open, and the first call against a live workspace is the real check.

The pack declares the source and carries one program, `build-post`, which builds the body of a draft and of a schedule. It needs Python 3.9 or newer on the `PATH` of the yard's server, and nothing else. [SETUP.md](SETUP.md) lists what the operator sets up. `.yardr/test` runs `yardr pack check` and this pack's `test`.

| file | what it is |
| --- | --- |
| `pack.yaml` | the pack: kind `source`, the source it declares, three suggested presets (`read`, `drafts`, `schedule`) |
| `postiz.yaml` | the source: Postiz's cloud base, one API key, six calls |
| `build-post` | the program: the body of a `draft` and of a `schedule`, parameters on stdin, one JSON request out |
| `SETUP.md` | what the operator does: the key, the pack, the base, the grants, a check, a first call |
| `test`, `testdata/` | the pack's tests, a stand-in for the service, its fixtures and the goldens |

## The calls

`read` grants the three reads together. `draft`, `schedule` and `upload` are updates and are granted each by its name. The yard shows each answer as data from outside the yard: posts are whatever anyone scheduled, so they carry no instruction.

| call | kind | takes | answers |
| --- | --- | --- | --- |
| `channels` | read | nothing | each channel with its `id`, `name`, `identifier` (the network), `picture`, `disabled`, `profile` and `customer`. The source's check call. |
| `posts` | read | `start`, `end` | `posts`: each post with its `id`, `content`, `publishDate`, `state` (`QUEUE`, `DRAFT`, `PUBLISHED`, `ERROR`), `releaseURL`, `error`, `settings` and `integration`. |
| `slot` | read | `channel` | `date`: the channel's next free posting slot, UTC, as `YYYY-MM-DDTHH:mm:ss`. |
| `draft` | update | `channels`, `text`; `image_id`, `image_path`, `replies` | one entry per channel written, with its `postId` and `integration`. |
| `schedule` | update | `channels`, `text`, `date`; `image_id`, `image_path`, `replies` | one entry per channel written, with its `postId` and `integration`. |
| `upload` | update | `file` | the media's `id` and `path` (with `name`, `status` and the rest), which go into a draft or a schedule as `image_id` and `image_path`. |

Every answer is kept as the service gives it, within the call's bound: 256 KB for `posts`, 64 KB for the rest. An answer over the bound is refused, not cut: narrow the window. A larger window is more calls, not one bigger one: no call pages on its own.

### How the channels go

Postiz names a channel by its `id`, and the network it is on by its `identifier`: `x`, `linkedin`, `linkedin-page` and the rest. `channels` gives both. `slot` takes one id. `draft` and `schedule` take one or more channels as `network:id` pairs, comma-separated, in one parameter:

```text
channels=x:cm4ean69r0003w8w1cdomox9n,linkedin-page:cm4ean70s0004w8w1efghij2kl
```

The program builds one entry per pair, with the settings its network takes. The service fills each entry's network from the channel itself and validates against the true network, so a pair that names the wrong network fails there with the service's readable error. Naming one channel twice is refused here: one entry per channel.

### `posts`

The window is required: the service wants one. Both ends are UTC, `YYYY-MM-DDTHH:mm:ss`, with optional millis and an optional `Z`. A repeated post (one the dashboard set to repeat, which no call here writes) comes back once per occurrence in the window.

### `slot`

The date comes from the channel's time slots, or the service's defaults where it keeps none. It has no zone letter and is UTC; `schedule` takes it as it stands.

### `draft`

A draft is saved and never published: the service starts no workflow for one. Its date is the service's required field and is stored unused; when the draft is scheduled from Postiz's own pages, a new time is chosen there. So the call takes no date, and the program sends the current time.

An Instagram draft may go without a picture. The service takes it, going by its source; no live Postiz has been asked. Add the picture in Postiz before scheduling the draft there.

### `schedule`

The date is UTC, as `posts` takes it, and must be in the future: the service publishes a schedule whose time has passed at once, so the program refuses one and sends nothing. A minute-ahead schedule waits the minute; the service does not treat it as now, so it is sent. Give it minutes, not seconds: the yard's clock and the service's are two clocks, and a time the service already passed goes out at once.

A schedule tried again after a lost answer is queued twice. Postiz takes no idempotency key.

A schedule that names an Instagram channel needs a picture too. The service refuses a scheduled Instagram post without one, so the program refuses it first, in a line that says Instagram needs a picture, and sends nothing.

## What X, LinkedIn and Instagram get, and what the rest gets

X, the LinkedIn profile and page, and Instagram are carried: the text, one picture, and the settings each takes. X takes who may reply (`replies`, `everyone` unless given). Instagram, on either `instagram` or `instagram-standalone`, is carried as a feed post. The service requires a post type, and the program sends `post`. Any other network gets the text, with generic settings and the picture where one is given; what it needs beyond that (YouTube's title, TikTok's fields) fails at the service with its readable error, and the README says so here rather than the pack saying it per network.

| network | carried | not carried |
| --- | --- | --- |
| X | text (280 characters, 4000 on a verified account), one picture, who may reply | communities, AI and paid-partnership marks, articles, threads |
| LinkedIn and LinkedIn page | text (3000 characters), one picture | carousels (they take two or more pictures), page mentions, documents |
| Instagram and Instagram standalone | the text as the caption (2200 characters), one picture, as a feed post | stories, reels, carousels (two or more pictures), collaborators, audio, trial reels |
| any other | the text, and the picture where one is given | whatever the network requires past that; the service's error says what |

The character counts are the service's own (its providers, read 12 November 2026; Instagram's, 13 November 2026). The pack does not enforce them. Postiz checks the count when it creates a schedule, but skips that check for drafts: an overlong draft can be saved here and may need editing before it can be scheduled.

Also left out of every post: threads and comments (one text per channel, no second part), tags (sent empty), short links (sent off), repeats (no interval), and alt text (X and LinkedIn do not send it, and the pack gives Instagram none).

## How it never publishes at once

What tells a draft or a schedule from a post gone out is the request's `type`, `"draft"`, `"schedule"` or `"now"`. Whether a schedule can go out at once is its date: past, and the service publishes without waiting. Four things keep the pack to drafts and future schedules, and the test holds each:

1. The declaration has no call that publishes at once, deletes or edits. Its three reads are `GET`s, and its three updates are the two `POST`s to `/posts` and the multipart `POST` to `/upload`.
2. `build-post` writes the request. It sets `type` from its argument alone, draft or schedule, and reads it from nothing; it refuses a schedule whose date is missing, is no date, or is not in the future; and it builds only from the parameters it lists. A parameter it does not list is refused.
3. yardr refuses an argument the call does not declare before the program runs, so `yardr call postiz draft ... type=now` sends nothing.
4. The test runs every case against a stand-in, and every request it saw must be a `GET` of the channels, the posts or a slot, the one multipart upload, or a `POST` that writes a draft or a schedule with a future date. A schedule with a past time shows as no request at all.

What the pack cannot do is narrow the key. One API key opens the whole workspace, its channels and its scheduled posts, and could publish, delete and edit through Postiz's own pages. The declaration is the fence, and a process that reads the env file (`~/.yardr/sources/postiz.env`, mode 0600) as the same user could use the key as it likes. That is true of every source of the yard.

yardr gives `build-post` the key in its environment, as it does to any build command. The program does not read it and makes no request, and the test fails if it imports anything that reaches a network or the environment.

## What was checked

- Postiz's public docs at docs.postiz.com, read on 12 November 2026: the API overview (authentication, base URL, rate limits, errors), the integrations, posts, find-slot and upload pages, the X and LinkedIn provider pages, and the uploads troubleshooting page.
- The service's own source, github.com/gitroomhq/postiz-app at `main` b31d29f (11 November 2026), read on 12 November 2026: the public API controller (every address, field and answer shape here), the auth middleware (the bare key, the 401s), the post DTOs (what a post requires), the posts service and repository (drafts, schedules, slots, the posts list), the throttle guard (what the rate limit covers), and the publish workflow (what a schedule waits for). The declaration's head comment says where the service differs from the remembered list.
- The service's source again for Instagram, at `main` 23f29c4 of the same repository, read on 13 November 2026. The settings DTO and the two providers are the same at b31d29f. The DTO requires one setting, `post_type` (`post` or `story`), and the rest is optional. The service fills each entry's network from its channel and validates the settings against that network's DTO, for a draft as for a schedule. Instagram's providers want at least one media, and the public controller enforces that for a schedule and not for a draft. The head of `postiz.yaml` names the files.
- The declaration and the program, through the real yardr in a scratch yard against a stand-in (`testdata/standin.py`): the pack applies, `source check` makes the check call with the key, each call is made with `yardr call`, and what each sends is in a golden. The stand-in turns away a post on an Instagram channel that carries no `post_type`, as the service does, and the test hands it a draft and a schedule, each with the setting and without.
- The cards SETUP.md names follow the infomaniak-mail pack's, whose cards were tried in a scratch yard on 10 November 2026: `--secret postiz` and `--run "source grant ..."` are accepted, and `--setup postiz` is refused, because yardr sets up only a pack it embeds. So a crew member cannot set this pack up with one card: the operator applies it, and the key and each grant go on cards of their own.

**Not checked: a live Postiz.** The stand-in follows the docs and the source, not the service's answers. The first call against a live workspace is the real check. Look at:

- whether the key is accepted and what status a wrong one gets. The fixtures' 401 body is the source's (`{"msg": ...}`).
- the multipart upload as yardr sends it: one file part named `file`, the filename, the sniffed content type, no other field.
- a schedule: that the canonical date is taken, that a future schedule queues, and what the answer carries per entry.
- a draft: that it lands in Postiz as a draft with its entries, and that scheduling it from Postiz's pages asks for a new time.
- Instagram: whether a live Postiz takes a draft and a schedule with `post_type: post` and one picture. A self-hosted one answered both with 400 on 13 November 2026, before the setting was sent, and the source says a missing `post_type` earns that. Also whether it saves a draft with no picture, and what its 400 body says. The stand-in's body is shaped after the source.
- a slot for a channel with no time slots of its own, and what its answer looks like.
- the size of real answers. The posts carry content, settings and integration each, so a wide window can come near the 256 KB bound.
- the throttle: 90 creations an hour by default, 100 on the cloud, reads and uploads unthrottled. From the source and the docs; nothing here spent one.

## Limits

Postiz allows 90 creations an hour per organization by default, on `POST /posts` alone: drafts count as much as schedules. The cloud allows 100. A self-hoster changes it with the `API_LIMIT` variable. Reads and uploads are not limited. yardr's own limits are per caller and tighter for updates: one caller makes 60 calls of a source an hour, 10 of them updates. A crew member that drafts and schedules in bulk runs out of yardr's updates first; raising `updates_per_hour` past Postiz's 90 spends the organization's whole hour faster, so it is the operator's to keep under that.

## The tests

Run `./test` in this directory, or `sh .yardr/test` from the repository, which also runs `yardr pack check`. The test needs `jq`, `python3` and `yardr`, and fails if any is missing instead of skipping. It needs no network and no secret, never touches Postiz, and takes a few seconds. It has two parts, cheapest first:

1. `build-post` as a process, run as the yard runs it, over `testdata/build/*.in`. Each request it makes is held to its call's type (never now), one entry per channel, and a future canonical date where it schedules; a schedule with a past time is refused, and every refusal is one line. A draft's date is the current time, held to NOW in its golden and to fresh by a check of its own.
2. The real yardr in a scratch yard. It applies the pack from this directory, reads the declaration back (`testdata/declaration.golden`), runs the grants SETUP.md teaches exactly as written, and makes every case of `testdata/calls/*.case` through `yardr call` against the stand-in, which answers the fixtures. It also answers 400, as the service does, to a post on an Instagram channel that carries no `post_type`, and one step hands it a draft and a schedule with the setting and without. A call the declaration or the program should turn away shows in its golden as no request at all. The key is a made-up string, and the test holds it to the one file that keeps it.

`UPDATE_GOLDEN=1 ./test` writes the goldens again from what the programs print. Read the diff before you keep it.
