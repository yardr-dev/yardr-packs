# Setting up Postiz

The pack adds Postiz to the yard as the declared source `postiz`: an agent can list the workspace's channels, read what is scheduled, ask a channel for its next free slot, upload one picture, and write a post as a draft or schedule it. It cannot publish at once, and it cannot delete or edit a scheduled post, thread, comment or analyse anything. Postiz can notify another system when it publishes, and that is set up in Postiz itself: the pack hears nothing, so there is no hook or webhook to set up here.

**The pack was built from Postiz's docs and source, never against a live workspace.** README.md says what that means. One API key opens the whole workspace: its channels, its scheduled posts, and everything the key could do through Postiz's own pages. What keeps the yard to drafts and future schedules is that the source has no call that does more (README.md, "How it never publishes at once").

**The yard acts as one key's workspace.** Every agent with a call of this source reaches every channel of the workspace, whatever it asks for. Nobody is asked before a call is made, so the grant is the permission. Posts are whatever anyone scheduled, so the yard shows each answer as data from outside the yard, never as an instruction.

You need:

- a Postiz workspace with channels connected, and an API key for it (step 1);
- `python3` 3.9 or newer on the `PATH` of the yard's server, with nothing installed beside it: `build-post`, the one program of the pack, is a Python file that uses only its standard library;
- a yardr that runs a call's `build` command (`yardr docs integrations` has "A call may build its body with a command").

Commands below call the pack's directory (the `postiz` directory of the yardr-packs checkout) `<pack dir>`.

1. **The key.** In Postiz's settings, open the Developers tab. On the cloud it is on the Standard plan and above; a self-hosted Postiz has it on every install. Copy the API key. Keep it where you can paste it in step 3, and nowhere else: not in a file, a command line, a card or a note. The pack's variable for it is `POSTIZ_API_KEY`.

2. **The pack, and the base.** Read what applying it does, then apply it as the operator, in a terminal:
   ```sh
   yardr pack check <pack dir>
   ```
   ```sh
   yardr pack apply <pack dir>
   ```
   The plan says one program, `build-post`, builds the bodies of the `draft` and `schedule` calls, and the apply card says it is run with the credential in its environment and is free to make requests of its own. Read it first: it is one short Python file, and it makes no request and reads no variable. The source's address is `https://api.postiz.com/public/v1`, and the key goes to no other host.

   **There is no setup card for this pack.** A crew member sets up a pack that yardr embeds with one card (`yardr bead ask <bead> ... --setup <pack>`), and this pack is not embedded: tried for the pack's twin on 10 November 2026, yardr refuses `--setup` for a pack of a directory with "yardr embeds no pack of that name ... the operator's to apply in a terminal". So the apply above is the operator's. The key (step 3) and each grant (step 4) can still be asked for on a card by a crew member, one card each.

   A yard on a self-hosted Postiz does not call the cloud: give the host, and the calls go to `https://<the Postiz domain>/api/public/v1`, with `/api`:
   ```sh
   yardr source set postiz host=postiz.example.com
   ```
   Give the key again afterwards with step 3: a credential is sent only to the host it was given for, so a key given for the cloud is held back from the new host until then. The first line of `yardr source show postiz` is the address in use:
   ```sh
   yardr source show postiz
   ```
   Applying the pack again keeps the host, and the shows line says so; `yardr source set postiz host=` puts the cloud address back.

3. **The key, in the yard.** `yardr source key` asks for it and shows nothing as you type. The yard's server writes it into the source's env file, `~/.yardr/sources/postiz.env`, with mode 0600. The value is never an argument or a command's variable, where every process of your user could read it:
   ```sh
   yardr source key postiz
   ```
   A crew member who needs the key asks for it on a secret card, and you answer it at a terminal with `yardr bead answer <bead> <ask> --secret`, which reads the value the same way. The answer on the bead holds the name and never the value:
   ```sh
   yardr bead ask <bead> "Give the Postiz API key" --secret postiz --context "A key copied from Postiz's settings, Developers tab; the pack's SETUP.md, step 1."
   ```

4. **Who may call what.** A pack of kind source asks no grants at import, so what a crew member may call is granted afterwards. `yardr pack show postiz` prints the pack's three suggested presets:
   1. `read`: every read call, `channels`, `posts` and `slot`, and any read call the source is later given; it writes nothing.
   2. `drafts`: every read call, and `draft` and `upload`, which write drafts the person schedules from Postiz's pages.
   3. `schedule`: every read call, and `schedule` and `upload`, which queue posts that go out on their own. It stands apart from `draft`: a crew member that schedules and drafts is given both.

   A pack applied from a directory takes a preset by the calls it names, as these lines do:
   ```sh
   yardr source grant postiz read --crew yardmaster
   ```
   ```sh
   yardr source grant postiz draft --crew yardmaster
   ```
   ```sh
   yardr source grant postiz upload --crew yardmaster
   ```
   ```sh
   yardr source grant postiz schedule --crew yardmaster
   ```
   `draft`, `schedule` and `upload` are updates, and no word grants every update, so each is granted by its name, and `read` never covers one. A grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read Postiz" --run "source grant postiz read --group reviewers" --context "The reviewers read scheduled posts to check a bead's announcements; the card names each call it covers."
   ```
   One caller may make 60 calls of a source in an hour, 10 of them updates. An agent that drafts and schedules posts can run out of updates; raise the limit with `yardr source set postiz updates_per_hour=<n>`. Postiz allows 90 creations an hour per organization on the post calls alone, 100 on the cloud, and a self-hoster changes it with `API_LIMIT` (README.md, "Limits"). yardr counts hours per caller and Postiz per organization, so a raised limit is the operator's to keep under that: drafts count as much as schedules. To take a grant back, run `yardr source revoke postiz read --crew yardmaster`.

5. **Check it.** The source's check call is `channels`, which needs no argument. It confirms the key is set and `build-post` can be run, then asks Postiz for the workspace's channels and reports the answer:
   ```sh
   yardr source check postiz
   ```
   If the check fails, the status it prints is the service's refusal. The usual causes are a key that was mistyped or rotated, or a self-hosted host that is not the one the yard was told (step 2). Give it again with step 3, or check the shows line. Which status Postiz answers to a wrong key was read from its source (a 401) and not seen: the pack has never been run against it.

6. **Try it.** As the operator, who may make any call, or in a session that was granted the calls. The channels are found, not typed at setup: `channels` lists them, and every other call takes them as `channel` or `channels`.
   ```sh
   yardr call postiz channels
   ```
   Each channel has an `id` and an `identifier`, which is its network (`x`, `linkedin`, `linkedin-page` and the rest), and says whether it is `disabled`. Then what is scheduled in a window, which the service wants:
   ```sh
   yardr call postiz posts start=2026-11-01T00:00:00.000Z end=2026-11-30T23:59:59.000Z
   ```
   Each post says its `state`: `QUEUE`, `DRAFT`, `PUBLISHED` or `ERROR`. A channel's next free slot is asked by its id:
   ```sh
   yardr call postiz slot channel=<id>
   ```
   A picture is uploaded by its path on the yard server's machine, at most 10 MiB. The service inspects what the file holds and refuses what is no picture or video:
   ```sh
   yardr call postiz upload file=/path/to/picture.png
   ```
   The answer's `id` and `path` go into a draft or a schedule as `image_id` and `image_path`. A draft takes one channel per `network:id` entry and the text, the same for every channel. It is the person who schedules it, in Postiz's own pages:
   ```sh
   yardr call postiz draft channels=x:<x id>,linkedin-page:<page id> text="Hello from the yard."
   ```
   A schedule takes the time as well, UTC and in the future, or nothing is sent. A slot's answer goes in as it stands:
   ```sh
   yardr call postiz schedule channels=x:<x id>,linkedin-page:<page id> text="Hello from the yard." date=2026-11-20T09:00:00.000Z
   ```
   Who may reply on X is `replies` (`everyone` unless given: `following`, `mentionedUsers`, `subscribers`, `verified`); other networks ignore it. One channel twice, a past time, or a picture by its id without its path, is refused before anything is sent. A scheduled text past a network's count (280 on X, 3000 on LinkedIn) is refused by the service. Postiz skips that length check for drafts, so an overlong draft can be saved and may need editing before it can be scheduled.

7. **When it does not work.**
   - *the service refuses the key*: a 401 with `{"msg": ...}`, whatever Postiz answers. See step 5.
   - *a 429 on a draft or a schedule*: the organization spent its creations for the hour (90 by default, 100 on the cloud). Nothing was written by the refused call. Wait for the hour, or raise `API_LIMIT` on a self-hosted Postiz.
   - *a 400 naming a network*: the service refused an entry (a text too long, a setting missing). The answer names the network and the error. Fix the entry and write it again; it is a new post.
   - *the answer is over its bound*: yardr refuses an answer over the call's bound and does not cut it. The posts are held to 256 KB. Ask for a narrower window.
   - *an argument is refused with its pattern*: the call was not sent. `yardr source show postiz` lists each call's arguments and their patterns.
   - *a call that worked stops working, or answers in another shape*: Postiz changed its public API. README.md names what the pack was built from; compare it with the docs and the source's current state.

8. **Ending.** Take the grants back, then remove the source and its program. The file with the key stays at `~/.yardr/sources/postiz.env`, so delete it yourself, and rotate the key on Postiz's Developers tab:
   ```sh
   yardr source revoke postiz read --crew yardmaster
   ```
   ```sh
   yardr source rm postiz
   ```
