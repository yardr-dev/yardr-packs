# Email

Mail as a pack of kind source: mail sent to yardmaster@yardr.dev reaches
the yard as a hook event and the yardmaster's inbox, through Cloudflare
Email Routing and a Worker, as the declared source `email`. Inbound
only: the yard never answers from the address. Nothing here is compiled
into yardr; apply it with:

```sh
yardr pack apply /Users/mckean/projects/repos/yardr-packs/email
```

from main of this repository. SETUP.md is the operator's steps.

## How it hangs together

A message to the address is routed to the Worker (`worker/`), which
parses the MIME with postal-mime and POSTs one JSON object per message
to the yard's hook:

```json
{"message_id": "<…>", "from": {"address": "ada@example.com", "name": "Ada"}, "to": ["yardmaster@yardr.dev"], "subject": "…", "date": "…", "in_reply_to": "", "references": [], "text": "…", "attachments": [{"name": "shed.txt", "size": 5, "type": "text/plain"}]}
```

`text` is the text/plain part, else the html part stripped to text, cut
at 64 KB; attachments are listed, never carried. The Worker signs the
exact bytes it sends with HMAC-SHA256 under the hook's secret, hex with
no prefix in `X-Email-Signature`, and puts the mail's Message-ID in
`X-Email-Delivery`, by which a retry is told. A non-2xx answer throws,
so the sending MTA retries later; a message over 1 MiB raw is rejected
(`message.setReject`), never posted.

The hook (`email.yaml`) verifies that signature, dedupes bodies
(`bodies: unique`), and `email/normalize` turns each verified body into
the envelope: `type: message`, `action: received`, the sender's
lowercased address as actor id and `fields.sender`, the References root
(else In-Reply-To, else the Message-ID) as the thread, the subject as
its title, the first 500 characters as the text. Who may be heard is
decided by identity (`hear: {field: sender, by: identity}`), as Slack's
is: an unmapped sender gets the operator a mapping card under the
hook's `--unknown` word.

## Authentication results: what was found

The Worker does not reject on SPF/DKIM/DMARC results, and the bead says
not to where none is reliable. What Cloudflare's docs say (checked
25 Oct 2026):

- The `email()` runtime API's message object carries `from`, `to`,
  `headers`, `raw`, `rawSize` and `canBeForwarded`, and no
  SPF/DKIM/DMARC verdict property
  ([Workers API](https://developers.cloudflare.com/email-service/api/route-emails/email-handler/),
  last updated 15 Oct 2026). The only DMARC verdict in that page is one
  Cloudflare keeps to itself: `message.reply()` throws unless the
  incoming mail has a valid DMARC result.
- Email Routing does validate SPF, DKIM and DMARC at receipt, and when
  it forwards a message it seals the verdict in an
  `ARC-Authentication-Results` header from `mx.cloudflare.net`
  ([Email Routing subdomain support](https://blog.cloudflare.com/email-routing-subdomains/)).
  But that header is documented on the forwarding path, not on the
  Worker path, and trusting one found there would want an ARC chain
  check the Worker does not do. A plain `Authentication-Results` header
  any sender can forge is no signal at all.

So a forged sender is heard as what identity says of the address: map
only addresses whose owners you know, as the mapping card asks.

## Files

- `pack.yaml`, `email.yaml`: the pack and its hook-only declaration.
- `email/normalize`: POSIX sh + jq, the verified body to the envelope.
- `worker/`: the Cloudflare Worker (`worker.js`, `wrangler.toml`,
  `package.json` with postal-mime as the one dependency), its tests
  (`worker.test.js`, `node --test`) and their fixtures
  (`testdata/*.eml`).
- `testdata/`: three Worker bodies and their envelopes, goldens beside
  them. `test` feeds each body to normalize and compares byte for byte,
  then runs the Worker's tests where node and postal-mime are present.

## Runtimes

- normalize wants POSIX sh and jq, as `packs/webhook`'s does. The gate
  knows no language; this is the pack's word for what its program needs.
- The Worker runs on Cloudflare (`wrangler deploy`); its tests want
  node 18 or later (Response, fetch and WebCrypto globals) and
  postal-mime installed (`npm install` in `worker/`).

## Testing

```sh
./test
```

in this directory: the normalize goldens, then `node --test` in
`worker/` where node and postal-mime are present, else a line saying
which is missing, and a pass. The depot's gate runs `yardr pack check`
on this directory first.

## Left out

Replies from the address (a Worker sends only to the zone's verified
addresses; sending wants a sender such as Resend); `notify` by email;
attachments fetched into the blob store (telegram's `thread.file` is
the pattern); a DKIM check in the Worker beyond what Cloudflare
reports. Each is a later bead, on mckean's word.
