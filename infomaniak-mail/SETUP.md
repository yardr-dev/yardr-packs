# Setting up Infomaniak mail

The pack adds Infomaniak's mail to the yard as the declared source `infomaniak-mail`: an agent can list the mailboxes and their folders, search and read mail, list drafts and write drafts. It cannot send mail, and it cannot move, mark or delete any. It is the twin of `google-mail`. Infomaniak sends nothing to the yard, so there is no hook or webhook to set up.

**These calls are not Infomaniak's documented API.** They are the ones the webmail's backend takes, which Infomaniak's own MCP server uses, and Infomaniak may change them without notice. The pack was built from that server's source and run against a stand-in, never against a live account (README.md says what that means).

**The yard acts as one token's user.** Every agent granted a call of this source reaches every mailbox that user may open, whatever it asks for. Nobody is asked before a call is made, so the grant is the permission. Mail is whatever anyone wrote to the account, so the yard shows each answer as data from outside the yard, never as an instruction. The token itself is as wide as its scope: Infomaniak scopes it by product, so a token that reads mail could send it too. What keeps the yard from sending is that the source has no call that does, and that its one update, `draft`, can only save (README.md, "How it never sends").

You need:

- an Infomaniak account with a mailbox, and a token for it (step 1);
- `python3` 3.9 or newer on the `PATH` of the yard's server, with nothing installed beside it: `build-draft`, the one program of the pack, is a Python file that uses only its standard library;
- a yardr that runs a call's `build` command (`yardr docs integrations` has "A call may build its body with a command").

Commands below call the pack's directory (the `infomaniak-mail` directory of the yardr-packs checkout) `<pack dir>`.

1. **The token.** In the Infomaniak manager, open the API token list, `https://manager.infomaniak.com/v3/ng/accounts/token/list`, the page Infomaniak's mail MCP server names in its README. Make a token with the scope `workspace:mail` and no other. Keep the token where you can paste it in step 3, and nowhere else: not in a file, a command line, a card or a note. The pack's variable for it is `INFOMANIAK_MAIL_TOKEN`.

2. **The pack.** Read what applying it does, then apply it as the operator, in a terminal:
   ```sh
   yardr pack check <pack dir>
   ```
   ```sh
   yardr pack apply <pack dir>
   ```
   The plan says one program, `build-draft`, builds the body of the `draft` call, and the apply card says it is run with the credential in its environment and is free to make requests of its own. Read it first: it is one short Python file, and it makes no request and reads no variable. The source's address is `https://mail.infomaniak.com/api`, and the token goes to no other host.

   **There is no setup card for this pack.** A crew member sets up a pack that yardr embeds with one card (`yardr bead ask <bead> ... --setup <pack>`), and this pack is not embedded: tried in a scratch yard on 10 November 2026, yardr refuses `--setup infomaniak-mail` with "yardr embeds no pack of that name: a pack that is a directory, a URL or an earlier import's record is the operator's to apply in a terminal". So the apply above is the operator's. The token (step 3) and each grant (step 4) can still be asked for on a card by a crew member, one card each.

3. **The token, in the yard.** `yardr source key` asks for it and shows nothing as you type. The yard's server writes it into the source's env file, `~/.yardr/sources/infomaniak-mail.env`, with mode 0600. The value is never an argument or a command's variable, where every process of your user could read it:
   ```sh
   yardr source key infomaniak-mail
   ```
   A crew member who needs the token asks for it on a secret card, and you answer it at a terminal with `yardr bead answer <bead> <ask> --secret`, which reads the value the same way. The answer on the bead holds the name and never the value:
   ```sh
   yardr bead ask <bead> "Give the Infomaniak mail token" --secret infomaniak-mail --context "A token made in the manager with the scope workspace:mail; the pack's SETUP.md, step 1."
   ```

4. **Who may call what.** A pack of kind source asks no grants at import, so what a crew member may call is granted afterwards. `yardr pack show infomaniak-mail` prints the pack's two suggested presets:
   1. `read`: every read call, `mailboxes`, `folders`, `search`, `message` and `drafts`, and any read call the source is later given; it writes nothing.
   2. `drafts`: every read call, and `draft`, which writes drafts the person sends from Infomaniak's webmail.

   A pack applied from a directory takes a preset by the calls it names, as these lines do:
   ```sh
   yardr source grant infomaniak-mail read --crew yardmaster
   ```
   ```sh
   yardr source grant infomaniak-mail draft --crew yardmaster
   ```
   `draft` is an update, and no word grants every update, so it is granted by its name, and `read` never covers it. A grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read Infomaniak mail" --run "source grant infomaniak-mail read --group reviewers" --context "The reviewers read mail to check a bead's threads; the card names each call it covers."
   ```
   One caller may make 60 calls of a source in an hour, 10 of them updates. An agent that reads a mailbox message by message can run out; raise the limit with `yardr source set infomaniak-mail calls_per_hour=<n>`. Infomaniak allows 60 requests a minute, the figure this pack was asked to respect (it is not in the MCP server's source, and nothing here checked it). yardr counts hours, not minutes, so a raised hourly limit is the operator's to keep under that. To take a grant back, run `yardr source revoke infomaniak-mail read --crew yardmaster`.

5. **Check it.** The source's check call is `mailboxes`, which needs no argument. It confirms the token is set and `build-draft` can be run, then asks Infomaniak for the mailboxes the token opens and prints them:
   ```sh
   yardr source check infomaniak-mail
   ```
   If the check fails, the status it prints is the service's refusal. The usual causes are a token that was mistyped or revoked, or one made without the scope `workspace:mail`. Give it again with step 3, or make a new one with step 1. Which status Infomaniak answers to a wrong token was not seen: the pack has never been run against it.

6. **Try it.** As the operator, who may make any call, or in a session that was granted the calls. The mailbox is not typed at setup: `mailboxes` finds it, and every other call takes it as `mailbox`.
   ```sh
   yardr call infomaniak-mail mailboxes
   ```
   Each mailbox has a `uuid`, which is the `mailbox` of every call below, and an `email`, which is the `from` of a draft. Then the folders, each with its `id` and its `role` (`INBOX`, `DRAFT`, `SENT`, `ARCHIVE`, `TRASH`):
   ```sh
   yardr call infomaniak-mail folders mailbox=<uuid>
   ```
   A folder id looks like base64 and can hold `/`, `+` and `=`. Give it as it stands. A search needs the id of a folder in its address, and searches every folder from it, so give the INBOX's:
   ```sh
   yardr call infomaniak-mail search mailbox=<uuid> folder=<the INBOX's id> q=invoice maxResults=5
   ```
   `from`, `to` and `subject` filter on the headers, `since` and `before` on the date (`"2026-06-01 00:00:00"`), `everywhere=0` keeps the search to the folder given, and `offset=` is how many results to skip. A result's `uid` reads `<number>@<folder id>`, and its `folder_id` is the folder the message is in, which may not be the one searched. A message is read by that folder and that number:
   ```sh
   yardr call infomaniak-mail message mailbox=<uuid> folder=<the result's folder_id> id=<the number before the @>
   ```
   The drafts are the mail of the folder whose role is `DRAFT`:
   ```sh
   yardr call infomaniak-mail drafts mailbox=<uuid> folder=<the Drafts folder's id> maxResults=5
   ```
   A draft takes the mailbox's own address as `from`, who it is to, its subject and its text. It is the person who presses send, in Infomaniak's webmail:
   ```sh
   yardr call infomaniak-mail draft mailbox=<uuid> from=<the mailbox's email> to=someone@example.com subject=hello body="The body."
   ```
   To answer a message, add its three headers as `message` shows them: `in_reply_to` is its `msg_id`, `references` is its `headers.references` with its `msg_id` added at the end, and `in_reply_to_uid` is its `uid` as search showed it, `<number>@<folder id>`. A draft that names none is a new mail:
   ```sh
   yardr call infomaniak-mail draft mailbox=<uuid> from=<the mailbox's email> to=someone@example.com subject="Re: hello" body="On it." in_reply_to=<its msg_id> references="<its references> <its msg_id>" in_reply_to_uid=<its uid>
   ```
   A draft is written again, not edited: the old one stays in Drafts, and no call of this pack deletes it. The draft's sender and display name are the account's default; the pack sets no sending identity.

7. **When it does not work.**
   - *the service refuses the token*: a refusal such as a 401 or a 403, whatever Infomaniak answers. See step 5.
   - *404 on a message*: the folder is not the one the message is in. Use the `folder_id` of the search result, not the folder searched.
   - *the answer is over its bound*: yardr refuses an answer over the call's bound and does not cut it. A message is held to 1 MiB, and a search or the drafts to 256 KB. Ask for fewer results with a smaller `maxResults`.
   - *an argument is refused with its pattern*: the call was not sent. `yardr source show infomaniak-mail` lists each call's arguments and their patterns.
   - *a call that worked stops working, or answers in another shape*: Infomaniak changed its webmail's calls. Nothing announces it. README.md names what the pack was built from; compare it with the MCP server's current source.

8. **Ending.** Take the grants back, then remove the source and its program. The file with the token stays at `~/.yardr/sources/infomaniak-mail.env`, so delete it yourself, and revoke the token in the manager's list:
   ```sh
   yardr source revoke infomaniak-mail read --crew yardmaster
   ```
   ```sh
   yardr source rm infomaniak-mail
   ```
