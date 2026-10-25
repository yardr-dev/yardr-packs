# Setting up Email

The pack wires mail into the yard as the declared source `email`: mail
sent to yardmaster@yardr.dev reaches the yard as a hook event and the
yardmaster's inbox, through Cloudflare Email Routing and a Worker. What
the operator writes to the address reaches the yardmaster's inbox, after
the mapping card below says who wrote it.

Inbound only: the yard never answers from the address, and no reply,
notify or attachment fetch is set up here. The Worker is the operator's
to deploy, and the yard cannot reach Cloudflare: every step below at
Cloudflare's side is typed by a person, not by a crew member.

1. **Apply the pack.** From main of the yardr-packs repository, as an
   operator. The source is named `email`: yardr knows mail as this pack
   alone.
   ```sh
   yardr pack apply /Users/mckean/projects/repos/yardr-packs/email
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
   openssl rand -hex 32 | tr -d '\n' > ~/.yardr/email.secret
   ```
   ```sh
   chmod 600 ~/.yardr/email.secret
   ```
   ```sh
   yardr hook add email --source email --secret-file ~/.yardr/email.secret --unknown unknown
   ```
   The file holds 64 hex characters, no trailing newline; the same
   value goes to the Worker in step 5, byte for byte. `--unknown
   unknown` is the decided word: a sender no user maps is dropped and
   offers the operator a mapping card, until they are mapped or
   ignored. `yardr hook list` shows the hook with STATE `ok`.
3. **Who hears.** The yardmaster hears every mail to the address:
   ```sh
   yardr subscribe yardmaster email --scope all --where type=message
   ```
   `all` is needed, not `mentions`: every mail to the address is
   addressed to the yard, and mail mentions nobody, so `mentions`
   would hear nothing. A subscription may narrow further with `--where
   sender=<address>` or `--where speaker=<user>`; `speaker` is the
   yard user the sender is mapped to.
4. **The Worker: install and deploy.** In `worker/` of this pack:
   ```sh
   npm install
   ```
   Then its two secrets, each asked unseen. The first is the same 64
   hex characters as step 2's file:
   ```sh
   wrangler secret put EMAIL_HOOK_SECRET
   ```
   The second is the hook's public address: the URL the edge serves
   this yard's hooks at, with `/email` for the hook's name.
   ```sh
   wrangler secret put YARD_HOOK_URL
   ```
   On this yard that address is `https://my.yardr.dev/hooks/mckean/mac/email`.
   Then deploy:
   ```sh
   wrangler deploy
   ```
5. **The Email Routing rule.** In the Cloudflare dashboard, under Email
   Routing for the yardr.dev zone, route yardmaster@yardr.dev to the
   `yardr-email` Worker. Everything else of the zone is untouched: no
   other address, rule or record changes.
6. **The first mail.** From the operator's own address, write to
   yardmaster@yardr.dev:
   ```text
   Can the shed land on Monday?
   ```
   The sender is mapped to nobody yet, so the delivery is dropped --
   and the operator is offered a mapping card, one per source and
   sender: who the sender is, and at most the first 80 characters
   beside it. Its picks are the yard's users, each naming the identity
   it writes, someone new, and nobody, who is ignored. Pick the
   operator's own user: the pick writes their `email` identity in the
   answering write. By hand it is the operator's instead:
   ```sh
   yardr user identity <user> --source email --id <the sender's address, lowercased>
   ```
   The next mail from that address is their word in the yardmaster's
   inbox:
   ```text
   4211 10-25 11:40  hook (all) email message received by mckean (mckean@example.com) on "Can the shed land on Monday?": Can the shed land on Monday?
   ```
   The ignored senders of the source are listed by `yardr source show
   email` and `yardr source ignore email`, and removed by `yardr
   source ignore email --rm <id>`, which hears them again with a fresh
   card.
7. **Ending hearing.** Delete the Email Routing rule of step 5, and
   remove the hook:
   ```sh
   yardr hook rm email
   ```
   Events the hook accepted are kept.
