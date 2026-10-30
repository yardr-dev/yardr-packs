# Setting up Cloudflare Email

The pack wires mail into the yard as the declared source
`cloudflare-email`: mail
sent to yardmaster@yardr.dev reaches the yard as a hook event and the
yardmaster's inbox, through Cloudflare Email Routing and a Worker. What
the operator writes to the address reaches the yardmaster's inbox, after
the mapping card below says who wrote it.

Inbound only: the yard never answers from the address, and no reply,
notify or attachment fetch is set up here.

The Worker ships ready: `worker/dist/worker.js`, built from
`worker.js` and postal-mime and committed with the pack. The Cloudflare
steps go on cards: a crew member proposes each write and the operator
approves it — no npm, no wrangler, no dashboard. The operator who would
rather type those steps finds that path at step 8, the terminal
alternative.

1. **Apply the pack.** From main of the yardr-packs repository, as an
   operator. The source is named `cloudflare-email`: a pack is named
   after the service it talks to.
   ```sh
   yardr pack apply /Users/mckean/projects/repos/yardr-packs/cloudflare-email
   ```
2. **The secret and the hook.** The Worker signs each message with this
   secret, and the hook verifies it. The secret lives in a file, mode
   0600, which the hook names. A new file takes its mode from the
   shell's umask, so narrow it first: with the usual 022 the secret is
   readable by others until the chmod. Each command below is one thing
   to type, in a block of its own.
   ```sh
   umask 077
   ```
   ```sh
   openssl rand -hex 32 | tr -d '\n' > ~/.yardr/cloudflare-email.secret
   ```
   ```sh
   chmod 600 ~/.yardr/cloudflare-email.secret
   ```
   ```sh
   yardr hook add cloudflare-email --source cloudflare-email --secret-file ~/.yardr/cloudflare-email.secret --unknown unknown
   ```
   The file holds 64 hex characters, no trailing newline; the same
   value goes to the Worker in step 6, byte for byte — or step 8 on
   the terminal path. `--unknown
   unknown` is the decided word: a sender no user maps is dropped and
   offers the operator a mapping card, until they are mapped or
   ignored. `yardr hook list` shows the hook with STATE `ok`.
3. **Who hears.** The yardmaster hears every mail to the address:
   ```sh
   yardr subscribe yardmaster cloudflare-email --scope all --where type=message
   ```
   `all` is needed, not `mentions`: every mail to the address is
   addressed to the yard, and mail mentions nobody, so `mentions`
   would hear nothing. A subscription may narrow further with `--where
   sender=<address>` or `--where speaker=<user>`; `speaker` is the
   yard user the sender is mapped to.
4. **Set up the cloudflare source.** The yard's Cloudflare steps run
   as calls of the declared source `cloudflare`. Its pack's setup
   notes (`yardr pack show cloudflare`) are the full telling; the
   short of it: make the API token there, then have a crew member ask
   for the setup card and approve it:
   ```sh
   yardr bead ask <bead> "Set up Cloudflare for the yardmaster?" --setup cloudflare --crew yardmaster --recommend 1 --why "the writes go on their own cards" --context "The yardmaster reads the account; this pack's Worker upload, secrets and Email Routing rule are each proposed and approved on their own cards."
   ```
   The card shows the declaration whole, the token to type unseen, and
   one option per preset. Pick `read`: the writes below go on their
   own cards, proposed by a crew member who may not make them. Then
   check the source, and pick the account and the zone from the reads:
   ```sh
   yardr source check cloudflare
   ```
   ```sh
   yardr call cloudflare accounts
   ```
   ```sh
   yardr call cloudflare zones
   ```
   The account and the zone are the 32 hex characters the lists show;
   the steps below name them `<account id>` and `<zone id>`.
5. **Upload the Worker, on a card.** Have a crew member propose the
   upload from the pack's dist file, in the checkout the pack was
   applied from:
   ```sh
   yardr bead ask <bead> "Upload the yardr-email Worker?" --run "call cloudflare worker_upload account=<account id> name=yardr-email script=/Users/mckean/projects/repos/yardr-packs/cloudflare-email/worker/dist/worker.js"
   ```
   The card shows the request it makes and, for the file, its path,
   SHA-256 digest and size: those bytes are what is sent, and a
   changed file is a new card. It is a strong card — the file is a
   program Cloudflare will run — so approve it at a terminal, or in
   the hosted web after a fresh sign-in, never through a device.
6. **The Worker's secrets, each on a card.** Two secrets, two cards of
   the same call. The first is step 2's hook secret, read from that
   file:
   ```sh
   yardr bead ask <bead> "Put the Worker's hook secret?" --run "call cloudflare worker_secret account=<account id> name=yardr-email secret=EMAIL_HOOK_SECRET value=~/.yardr/cloudflare-email.secret"
   ```
   The second is the hook's public address: the URL the edge serves
   this yard's hooks at, with `/cloudflare-email` for the hook's name.
   Write it to its own file first, mode 0600 with no trailing newline.
   Each command below is one thing to type, in a block of its own.
   ```sh
   umask 077
   ```
   ```sh
   printf %s https://my.yardr.dev/hooks/mckean/mac/cloudflare-email > ~/.yardr/cloudflare-email-url.secret
   ```
   ```sh
   chmod 600 ~/.yardr/cloudflare-email-url.secret
   ```
   ```sh
   yardr bead ask <bead> "Put the Worker's hook address?" --run "call cloudflare worker_secret account=<account id> name=yardr-email secret=YARD_HOOK_URL value=~/.yardr/cloudflare-email-url.secret"
   ```
   On this yard that address is `https://my.yardr.dev/hooks/mckean/mac/cloudflare-email`.
   Each card shows the secret's name and the file's name alone; the
   value stands in no card, note or record.
7. **The Email Routing rule, on a card.** List the zone's rules first;
   where one for the address stands, edit it rather than making a
   second:
   ```sh
   yardr call cloudflare email_rules zone=<zone id>
   ```
   ```sh
   yardr bead ask <bead> "Send yardmaster@yardr.dev to the Worker?" --run "call cloudflare email_rule zone=<zone id> address=yardmaster@yardr.dev worker=yardr-email"
   ```
   Where a rule for the address stands, its id is the list's above:
   ```sh
   yardr bead ask <bead> "Point yardmaster@yardr.dev at the Worker?" --run "call cloudflare email_rule_edit zone=<zone id> rule=<rule id> address=yardmaster@yardr.dev worker=yardr-email"
   ```
   The card shows the address and the Worker it sends to. Everything
   else of the zone is untouched: no other address, rule or record
   changes.
8. **The terminal path, the operator's alternative.** Steps 4–7 need
   no npm, no wrangler and no dashboard. The operator who would rather
   type the Cloudflare steps does their work this way instead, and
   skips the cards. In `worker/` of this pack:
   ```sh
   npm install
   ```
   Then its two secrets, each asked unseen. The first is the same 64
   hex characters as step 2's file:
   ```sh
   wrangler secret put EMAIL_HOOK_SECRET
   ```
   The second is the hook's public address: the URL the edge serves
   this yard's hooks at, with `/cloudflare-email` for the hook's name.
   ```sh
   wrangler secret put YARD_HOOK_URL
   ```
   On this yard that address is `https://my.yardr.dev/hooks/mckean/mac/cloudflare-email`.
   Then deploy:
   ```sh
   wrangler deploy
   ```
   Then the rule, in the Cloudflare dashboard, under Email Routing for
   the yardr.dev zone: route yardmaster@yardr.dev to the `yardr-email`
   Worker. Everything else of the zone is untouched: no other address,
   rule or record changes.
9. **The first mail.** From the operator's own address, write to
   yardmaster@yardr.dev:
   ```text
   Can the shed land on Monday?
   ```
   The sender is mapped to nobody yet, so the delivery is dropped --
   and the operator is offered a mapping card, one per source and
   sender: who the sender is, and at most the first 80 characters
   beside it. Its picks are the yard's users, each naming the identity
   it writes, someone new, and nobody, who is ignored. Pick the
   operator's own user: the pick writes their `cloudflare-email`
   identity in the
   answering write. By hand it is the operator's instead:
   ```sh
   yardr user identity <user> --source cloudflare-email --id <the sender's address, lowercased>
   ```
   The next mail from that address is their word in the yardmaster's
   inbox:
   ```text
   4211 10-25 11:40  hook (all) cloudflare-email message received by mckean (mckean@example.com) on "Can the shed land on Monday?": Can the shed land on Monday?
   ```
   The ignored senders of the source are listed by `yardr source show
   cloudflare-email` and `yardr source ignore cloudflare-email`, and
   removed by `yardr source ignore cloudflare-email --rm <id>`, which
   hears them again with a fresh card.
10. **Ending hearing.** Delete the Email Routing rule of step 7 — in
    the dashboard, on either path, since no call deletes a rule — and
    remove the hook:
    ```sh
    yardr hook rm cloudflare-email
    ```
    Events the hook accepted are kept.
