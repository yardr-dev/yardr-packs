# Setting up Infomaniak kChat

The pack wires Infomaniak's kChat into the yard as the declared source
`infomaniak-chat`: a channel is heard through kChat's outgoing webhook,
and a crew member answers in the thread with `yardr reply`. It is the
twin of the `slack` pack in the yardr repository. A post that starts
with one of the webhook's trigger words, in a public channel the
webhook stands in, lands in the inbox of whoever subscribes; the
answer is posted back into that post's thread by a bot account.

Two costs before the steps. The yard needs a public hook address:
kChat must be able to POST to the yard's hook URL, which is networking
in front of the yard (a tunnel or reverse proxy that passes `/hooks/`
to `hook_addr`), as for every hook source. And the webhook spends
one of the plan's outgoing webhooks (Infomaniak's FAQ 2001, read
12 November 2026: kSuite Free allows 1 incoming and 1 outgoing,
Standard 20 each, Business and Enterprise unlimited). The pack uses
no incoming webhook: posting is the API with the bot's token, so the
incoming slot stays free.

Three different values are typed during setup, and none is written
in any file of this pack, in a note or on a command line, where every
process of the user could read it:

| value | made where | what it does |
| --- | --- | --- |
| the bot account's token | kChat, New, Integrations, Bot accounts | speaks as the bot: every `yardr call` and every `yardr reply` (`INFOMANIAK_CHAT_TOKEN`) |
| the outgoing webhook's token | kChat, when the webhook of step 6 is saved | only verifies: the yard compares it with each delivery's `token` field before anything is read from the body; it is handed to no program and calls nothing |
| the team name | the kChat address, `https://<team>.kchat.infomaniak.com` | no secret: it names the host every call goes to, in the yard's copy of the declaration (step 2) |

A token made in Infomaniak's manager (the API token list, with
the scope `kchat`) is a fourth thing and no step asks for it: it acts as the
user it was made for, which is the user-token alternative Infomaniak's
MCP server documents. This pack speaks as the bot account instead, so
the yard's words in the channel are the bot's, not a person's.

The pack's two programs need `bash`, `curl` and `jq` on the yard's
machine. Commands below call the pack's directory (the
`infomaniak-chat` directory of the yardr-packs checkout) `<pack dir>`,
and the steps use `mckean` as the operator's user name and
`yardmaster` as the crew member who hears the channel; replace them
with this yard's names if they differ. Nothing in these steps was run
against a live kChat when the pack was written: there is no account
to run them on, and README.md says what that leaves for the first
live run to confirm, the outgoing webhook's creation screen first.

1. **The bot account and its token, in kChat, in a browser.** Open
   the kChat web app (`https://<team>.kchat.infomaniak.com`), click
   New beside the organization's name, then Integrations, Bot
   accounts, Add bot account (the walk Infomaniak's MCP server names
   for a bot token). Name it for the yard (`yardr`), give it no wider
   place than the team, and keep the token it shows where you can
   paste it in step 3, and nowhere else. Add the bot to the channel
   the yard will hear (in the channel, Add Members): it can only
   answer where it stands. Making the account is the operator's in
   kChat's pages; no card can do it, since the yard holds no kChat
   credential yet by which it could act.

2. **The pack and the team's address, in a terminal.** The source is
   per team, so the declaration ships a placeholder address,
   `https://example.kchat.infomaniak.com`, and the yard's copy must
   name your team before any credential is given: a source's
   credential goes only to the hosts its file names. Read what
   applying does, then apply it as the operator:
   ```sh
   yardr pack check <pack dir>
   ```
   ```sh
   yardr pack apply <pack dir>
   ```
   **There is no setup card for this pack.** A crew member sets up a
   pack that yardr embeds with one card (`yardr bead ask <bead> ...
   --setup <pack>`), and this pack is not embedded: yardr refuses
   `--setup infomaniak-chat` for a pack applied from a directory, so
   the apply above is the operator's. The token (step 3), the hook
   (step 6) and each grant (step 8) can still be asked for on a card
   by a crew member, one card each. Write the team's address into a
   copy of the declaration, beside the original so that the programs
   it names are found, and add the copy. The copy is the operator's;
   keep it out of any commit, since it names the team:
   ```sh
   sed 's|^base: .*|base: https://<team>.kchat.infomaniak.com|' <pack dir>/infomaniak-chat.yaml > <pack dir>/infomaniak-chat.local.yaml
   ```
   ```sh
   yardr source add <pack dir>/infomaniak-chat.local.yaml
   ```
   ```sh
   yardr source show infomaniak-chat
   ```
   The first line of `source show` is the address in use. Until it
   is the team's, `yardr source check infomaniak-chat` calls the
   placeholder and fails, and the token of step 3 would be paired
   with it: do step 3 after this one, not before. Applying the pack
   again later puts the placeholder back; add the copy again after.

3. **The bot token, in the yard.** `yardr source key` asks for it and
   shows nothing as you type. The yard's server writes it into the
   source's env file, `~/.yardr/sources/infomaniak-chat.env`, with
   mode 0600, as `INFOMANIAK_CHAT_TOKEN`:
   ```sh
   yardr source key infomaniak-chat
   ```
   It asks for the variable by name; paste the bot token of step 1.
   A crew member who needs it given asks for it on a secret card, and
   you answer it at a terminal with `yardr bead answer <bead> <ask>
   --secret`, which reads the value the same way. The answer on the
   bead holds the name and never the value:
   ```sh
   yardr bead ask <bead> "Give the kChat bot token" --secret infomaniak-chat --context "The token of the bot account of SETUP.md step 1, in kChat under New, Integrations, Bot accounts."
   ```

4. **Whose token it is.**
   ```sh
   yardr source check infomaniak-chat
   ```
   It makes the check call, `whoami` (GET /api/v4/users/me), and
   prints the bot's `id` and `username`, one per line under the status
   line:
   ```text
   infomaniak-chat: check call whoami (GET /api/v4/users/me): 200 in …ms, … bytes
   infomaniak-chat: id: …
   infomaniak-chat: username: …
   ```
   The `id` and `username` are step 7's. A token kChat refuses fails
   the check here rather than at the first answer. A check that
   prints no `id` line has not shown whose token it holds: setup
   stops there rather than guessing an id from elsewhere.

5. **The public hook address, on a card if it is not already set.**
   ```sh
   yardr bead ask <bead> "Where the yard is reached for webhooks" --run "settings set hook_public_url https://<his host>/hooks" --context "kChat posts the channel's triggered posts to the hook's URL under it."
   ```
   The URL of the kChat hook is then
   `https://<his host>/hooks/infomaniak-chat`. The address reaching
   the yard (a tunnel or proxy in front of `hook_addr`, TLS included:
   the hook listener itself speaks plain HTTP, and a delivery's body
   carries the webhook's token) is networking outside yardr, the
   operator's, and is the one piece of plumbing no card carries.

6. **The outgoing webhook and its token: the webhook in kChat's
   pages, then two cards.** In the kChat web app, New, Integrations,
   Outgoing Webhooks, Add (FAQ 2001 reaches the Integrations pages;
   it walks only an incoming webhook, so the outgoing screen's own
   words may differ from these). Give it:
   - the channel the yard hears;
   - trigger words the crew will address the yard with (a post that
     starts with one of them is sent; Mattermost fires an outgoing
     webhook in public channels only, so a private channel and a
     direct message are never heard);
   - as its Callback URL, the hook's URL from step 5,
     `https://<his host>/hooks/infomaniak-chat`;
   - Content-Type `application/json`. This is pinned: the yard hears
     a JSON body alone, because the webhook's token stands in its
     `token` field and the core reads JSON. Mattermost offers JSON
     or form-encoded per webhook; if kChat's screen offers no such
     choice and sends form, deliveries are refused as no JSON, and
     hearing waits for form support in the core. Say so on the bead
     rather than working around it.

   Saving shows the webhook's token. Give it to the yard on a secret
   card first (the value is typed unseen and written by the server
   to the hook's own file, mode 0600):
   ```sh
   yardr bead ask <bead> "kChat's outgoing webhook token" --secret-hook infomaniak-chat --source infomaniak-chat --context "Shown when the outgoing webhook of SETUP.md step 6 is saved in kChat."
   ```
   then the hook itself:
   ```sh
   yardr bead ask <bead> "Set up the kChat webhook?" --run "hook add infomaniak-chat --source infomaniak-chat --unknown unknown" --context "The yard takes the channel's triggered posts at POST /hooks/infomaniak-chat, each verified by its token before anything is read from it."
   ```
   Approving the hook stands the endpoint up; unlike telegram there
   is no registration call for the yard to make, since kChat takes
   its Callback URL only in its own pages. `--unknown unknown` is
   the word for the whole channel: a sender no user maps (step 7)
   is held on a mapping card for the operator, one per source and
   sender, until they are mapped or ignored; under `allow` they
   would be heard as an outsider, and under `ignore` dropped with
   no card. Every post the webhook sends, the core checks first: a
   delivery whose `token` field is not this webhook's is refused
   with 401 before the field is read anywhere else, and the field
   reaches no program, no stored body and no event.

7. **Who is who in kChat.** The bot first, with the `id` and
   `username` step 4 printed, so `@<username>` is a mention of the
   yardmaster and the echo of the bot's own post is dropped before
   hearing:
   ```sh
   yardr bead ask <bead> "Whose mention the bot's is" --run "crew identity yardmaster --source infomaniak-chat --id <id from step 4> --key <username from step 4>" --context "The id and username yardr source check infomaniak-chat printed in step 4."
   ```
   Then each person whose channel posts the yard should hear as
   theirs. Their kChat `user_id` is in a thread or history answer
   (step 9), or on the mapping card step 6's word offers for their
   first post, which writes the same mapping when a user is picked:
   ```sh
   yardr user identity <user> --source infomaniak-chat --id <their user_id> --key <their username>
   ```
   The key is the username because a kChat text mentions `@username`;
   the id is what a delivery's sender carries, and hearing matches
   on it.

8. **The grants, the yardmaster's answering token, and a check of
   each.** `yardr reply` speaks with the answering crew member's own
   copy of the bot token, not the source's file, so give it on its
   own card and restart the crew member, whose running session does
   not see the new value until it next starts:
   ```sh
   yardr bead ask <bead> "The token it answers with" --secret infomaniak-chat --for-crew yardmaster --context "The token of the bot account of SETUP.md step 1, in kChat under New, Integrations, Bot accounts."
   ```
   ```sh
   yardr crew restart yardmaster
   ```
   What a crew member may ask through `yardr call` is granted
   beside that. `yardr pack show infomaniak-chat` prints the pack's
   two suggested presets:
   1. `read`: every read call, `whoami`, `history` and `thread`, and
      any read call the source is later given; it writes nothing.
   2. `post`: every read call, and `post`, which posts one message
      to a channel.

   A pack applied from a directory takes a preset by the calls it
   names (`--preset` names the presets of the packs inside yardr's
   binary), as these lines do:
   ```sh
   yardr source grant infomaniak-chat read --crew yardmaster
   ```
   ```sh
   yardr source grant infomaniak-chat post --crew yardmaster
   ```
   `post` is an update, and no word grants every update, so it is
   granted by its name, and `read` never covers it. Answering with
   `yardr reply` needs no grant at all. A grantee who comes later
   gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read kChat history" --run "source grant infomaniak-chat read --group reviewers" --context "The reviewers read a heard channel's posts and threads to check a bead's work; the card names each call it covers."
   ```
   One caller may make 60 calls of a source in an hour, 10 of them
   updates; raise it with `yardr source set infomaniak-chat
   calls_per_hour=<n>` where the work needs it. To take a grant
   back, run `yardr source revoke infomaniak-chat read --crew
   yardmaster` (and the same with `post`).

9. **The subscription, and a first post.** The yardmaster subscribes
   itself from its pane, an agent step and not an operator terminal,
   to every triggered post the webhook sends:
   ```sh
   yardr subscribe yardmaster infomaniak-chat --scope all --where type=message
   ```
   `--where channel=<a channel's id>` narrows it to one channel,
   and `--scope mentions` hears only posts that mention the crew
   member's key. Then, in kChat, post in the channel starting with
   a trigger word (`<trigger> can this land on Monday?`). It lands
   in the yardmaster's inbox as a `hook` event of the source
   `infomaniak-chat`, and:
   ```sh
   yardr reply <seq> -
   ```
   with the words on stdin answers in that post's thread, while
   `yardr thread show <seq>` reads the thread back and
   `yardr hook show <seq>` holds the delivery itself (its stored
   body has no `token` field: the core removed it). As the operator,
   or in a session granted the calls, the same reads are calls:
   ```sh
   yardr call infomaniak-chat history channel=<a channel's id>
   ```
   ```sh
   yardr call infomaniak-chat thread id=<a root post's id>
   ```
   ```sh
   yardr call infomaniak-chat post channel=<a channel's id> text="On it."
   ```
   A first post that lands nowhere is one of: the webhook (not
   saved, in another channel, no trigger word at its start, or a
   private channel), the address (kChat cannot reach the hook URL),
   the token (the hook refuses it: `yardr hook list` shows the
   refusals as `unauthorized`), the Content-Type (form, step 6), or
   the speaker (held on a mapping card, step 6's word).

Who is heard is what step 9's subscription carries, and who each
speaker is. A delivery whose sender is a user's `infomaniak-chat`
identity arrives named as them, and a subscription may filter with
`--where speaker=<user>`; the bot's own posts name it as actor where
kChat sends them back, and never reach its inbox, by its id or its
key, under any unknown word. Three limits, where you meet them: a
reply run again after its answer was lost posts twice, since the
service takes no idempotency key; `yardr thread show` on a thread of
a channel the bot has left fails with kChat's reason rather than
showing an empty thread; and a reply posted inside a thread is heard
as a new post of its own, because the outgoing payload carries no
root (the declaration's head says so): its thread is read back whole
with the `thread` call from the root.

**Ending.** Take the grants back, remove the hook and the source,
delete the webhook in kChat and revoke the bot account (or its
token) there. The files with the values stay where the yard put
them, so delete them yourself:
```sh
yardr source revoke infomaniak-chat read --crew yardmaster
```
```sh
yardr source revoke infomaniak-chat post --crew yardmaster
```
```sh
yardr hook rm infomaniak-chat
```
```sh
yardr source rm infomaniak-chat
```
`~/.yardr/sources/infomaniak-chat.env`, the answering crew member's
env file and `<home>/hooks/infomaniak-chat.secret` hold the values.
