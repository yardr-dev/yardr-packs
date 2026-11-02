# Setting up Confluence

The pack wires Confluence Cloud into the yard as the declared source
`confluence`. An agent lists the site's spaces, finds pages by CQL, reads one
page and lists the children of a page, folder, whiteboard, database or embed. It
only reads. What it reads a page as is Confluence's storage format, which is
markup and not text: turning it into text is the reader's.

**The yard reads as one Atlassian account.** Every agent granted a call of this
source reads what that account can read, in every space it can view, and the
yard does not narrow it per agent. The grant is the permission. Make the account
for the yard alone, and give it the spaces the yard should read and no others
(step 1). If the yard also runs the jira pack, this is the same account: one
login, two sources.

You need a Confluence Cloud site and an administrator of it for step 1. The
pack's one program, `confluence/mint`, needs `jq` on the yard's machine. Commands
below call the pack's directory (the `confluence` directory of the yardr-packs
checkout) `<pack dir>`. The steps follow Atlassian's documentation as of 2
November 2026, and none was run against a site of our own when the pack was
written, so a screen may be named otherwise than here.

1. **The account and its token, in Atlassian.** Use the account the jira pack
   uses, if there is one: make it as step 1 of the jira pack's SETUP.md says (a
   service account in Atlassian Administration, under Directory, Service
   accounts, fits best). Otherwise make an Atlassian account that only the yard
   uses.

   Then give it Confluence, and only the spaces the yard should read. The
   account needs access to Confluence on the site. Then, in each such space,
   Space settings, Permissions: give the account (or a group that holds it
   alone) View, and nothing more. Confluence decides what the account sees by its
   space permissions and its groups. A space that lets every user of the site
   view it, or a group the account belongs to, shows the account that space as
   well, so step 5 has you compare what it sees with what you meant.

   Then make its API token. Atlassian recommends a token with scopes, and gives
   a service account no other kind. Its form for one has you choose the app and
   then that app's scopes, so a token the jira pack was given for Jira is not
   made for Confluence, and the same account gets a second token for it:
   - A service account: Atlassian Administration, Directory, Service accounts,
     the account, Create credential, API token.
   - An ordinary account: sign in as it, open
     https://id.atlassian.com/manage-profile/security/api-tokens and choose
     Create API token with scopes.

   Choose Confluence and the four scopes the calls need, which are the ones
   Atlassian's API description lists for the four requests: `read:space:confluence`
   (spaces), `read:page:confluence` (page), `read:hierarchical-content:confluence`
   (children, of any kind) and `search:confluence` (search). Atlassian shows the
   token once. A token lasts 1 to 365 days, a year unless you choose otherwise, so
   note the day it ends. Step 6 says what to do then.

   A token made without scopes (Create API token, an ordinary account only) is
   the account's, serves Jira and Confluence alike, and can do everything the
   account can. If the jira pack already has one, it is the same token, given to
   this source as well. Step 2 says where each kind goes.

2. **The pack and the site's address.** Apply the pack as the operator:
   ```sh
   yardr pack apply <pack dir>
   ```
   The declaration it installs gives the source a placeholder address,
   `https://example.atlassian.net/wiki`. A source's credential goes only to the
   hosts its file names, so the yard's copy of the file must name yours, with
   its `/wiki`. A token with scopes is called through Atlassian's gateway,
   `https://api.atlassian.com/ex/confluence/<cloud id>/wiki`. The site gives
   its cloud id without a login:
   ```sh
   curl -s https://<site>.atlassian.net/_edge/tenant_info
   ```
   A token without scopes is called at the site, `https://<site>.atlassian.net/wiki`.
   Write the address you need into a copy of the declaration, beside the
   original so that the program it names is found, and add the copy to the yard.
   The copy is ignored by git. For a token with scopes:
   ```sh
   sed 's|^base: .*|base: https://api.atlassian.com/ex/confluence/<cloud id>/wiki|' <pack dir>/confluence.yaml > <pack dir>/confluence.local.yaml
   ```
   And for a token without:
   ```sh
   sed 's|^base: .*|base: https://<site>.atlassian.net/wiki|' <pack dir>/confluence.yaml > <pack dir>/confluence.local.yaml
   ```
   Then add the copy:
   ```sh
   yardr source add <pack dir>/confluence.local.yaml
   ```
   ```sh
   yardr source show confluence
   ```
   The first line of `source show` is the address in use. Until it is yours,
   `yardr source check confluence` calls the placeholder and fails. Do step 3
   after this one and not before, so that the credential is never one the yard
   could send to the placeholder.

3. **The account's email and token, in the yard.** The credential is two names:
   `CONFLUENCE_EMAIL`, the account's email, and `CONFLUENCE_API_TOKEN`. The
   pack's `confluence/mint` makes the Basic credential Atlassian takes from
   them. They live in this source's own env file, mode 0600, and never in the
   store. The jira pack's source has a file of its own and is given the same two
   values again, so a token that is replaced is given again to each source.
   `yardr source key` asks for both and shows nothing as they are typed. It
   writes the file the source reads (`~/.yardr/sources/confluence.env`):
   ```sh
   yardr source key confluence
   ```
   A crew member who needs it given asks on a card instead, and the operator
   answers it at a terminal:
   ```sh
   yardr bead ask <bead> "The email and token of the yard's Confluence account" --secret confluence --context "The yard's Atlassian account: its email, and an API token for Confluence with the scopes of SETUP.md step 1."
   ```
   Then check the source:
   ```sh
   yardr source check confluence
   ```
   The check makes the call `spaces` with its defaults and prints the first
   spaces the account sees. A 401 is the credential, the address or the account:
   the email and token, a token that ended, a token with scopes sent to the site
   and not to the gateway (a token without scopes sent to the gateway fails too),
   a cloud id that is another site's, a token made without a scope the call needs
   (Atlassian answers that with a 401 as well, and a scope is fixed when the token
   is made, so a token without one is made again), or an account that has no
   access to Confluence or to the space.

4. **The grant.** A pack of kind source asks none at import, so what a crew
   member may call is granted afterwards. `yardr pack show confluence` prints
   the pack's suggestion, one preset, `read`. yardr's `--preset` names the presets
   of the packs inside its binary and not those of a pack applied from a
   directory, so the grant is by name: `read` is every read call of the source,
   one a later file adds included. The source reads as one account, so a grant of
   `read` lets that crew member read everything the account may. Grant it to those
   who need it:
   ```sh
   yardr source grant confluence read --crew yardmaster
   ```
   A group of agents takes `--group <group>` in place of `--crew <name>`. A
   grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read Confluence" --run "source grant confluence read --group reviewers" --context "The reviewers read the team's pages to check a bead's work; the card names each call it covers."
   ```
   One caller may make 60 calls of a source in an hour, and an agent that walks
   a page tree uses them quickly. The operator raises the limit where the work
   needs it:
   ```sh
   yardr source set confluence calls_per_hour=300
   ```

5. **Try it, and look at what the account sees.** As the operator, who may make
   any call:
   ```sh
   yardr call confluence spaces
   ```
   Compare the list with the spaces you meant the account to read. A space in it
   that you did not mean is a space whose permissions let this account in: remove
   the account (or the group that lets it in) there, and look again. The same
   call with `keys` finds a space by the key its address shows (`/spaces/ENG/...`):
   ```sh
   yardr call confluence spaces keys=ENG
   ```
   The answer gives each space's `id`, `key`, `name`, `type` and `homepageId`, the
   page to start walking from. A page's id is also in its address
   (`/spaces/ENG/pages/98404/Runbooks` is page 98404). A page, then, and its
   children:
   ```sh
   yardr call confluence page id=98404
   ```
   ```sh
   yardr call confluence children id=98404
   ```
   `children` answers each child's `id`, `title`, `status` and `type`, which is
   `page`, `folder`, `whiteboard`, `database` or `embed`. To go down a level, give
   the child's `id` and its `type` with an `s` as `kind`. For a folder:
   ```sh
   yardr call confluence children id=98411 kind=folders
   ```
   The other kinds are `whiteboards`, `databases` and `embeds`. A call with no
   `kind` asks for the children of a page, and `page` takes the id of a page only.
   Content is found by CQL, Confluence's query language:
   ```sh
   yardr call confluence search cql='type = page AND space = "ENG" AND title ~ "runbook"'
   ```
   A hit gives `id`, `type`, `status`, `title` and `_links.webui`, whose path
   names the space; `_links.base` and the `webui` path together are the link a
   person opens.

   `spaces`, `children` and `search` answer one page of 25, and `limit` asks for
   another size (250 at most for the first two). An answer that has another page
   keeps it as `_links.next`, whose `cursor=` value is `cursor` in the same call
   again (for `children`, with the same `id` and `kind`). Search writes it
   percent-encoded (`%2B`, `%3D`), and the call encodes what it is given, so give
   it decoded:
   ```sh
   yardr call confluence children id=98400 cursor=eyJpZCI6Ijk4NDExIiwiY29udGVudE9yZGVyIjoiY2hpbGQtcG9zaXRpb24iLCJjb250ZW50T3JkZXJWYWx1ZSI6MjAwMH0=
   ```

   `page` answers the body as `body.storage.value`, in storage format: XHTML with
   Confluence's own tags (`ac:structured-macro`, `ac:link`, `ri:page`). It is
   markup and not text, and the answer is at most 256 KiB, refused and not cut
   when a page is longer. A failed call tells the agent the status alone: a 404
   is a page that is not there, or one the account may not view (Confluence
   answers both so), and a 400 from `search` is a CQL it cannot parse.

6. **Updating the pack, and when the token ends.** A pack applied again replaces
   the source's declaration whole, and the placeholder address comes back with
   it. Your env file and the grants stay. After pulling the checkout, read what
   would change:
   ```sh
   yardr pack check <pack dir>
   ```
   If you apply the pack, the plan lists the address as `base: <your address> ->
   https://example.atlassian.net/wiki`. That line is how you notice, and it is the
   edit being undone. Until you add your copy again, the source calls the
   placeholder, a host that is not your site, with the account's credential, and
   `yardr source check confluence` fails. The shorter way skips the apply. Make
   the copy again from the new `confluence.yaml` with step 2's `sed`, and add it
   with `yardr source add`. The source then never points at the placeholder.

   When the token ends, make a new one as in step 1 and give it again with
   `yardr source key confluence`. A token that expired or was revoked shows as a
   401 from `yardr source check confluence`.

7. **Ending.** Remove the source, which takes its grants with it:
   ```sh
   yardr source rm confluence
   ```
   Revoke the token at id.atlassian.com, or delete the service account's
   credential in Atlassian Administration, and take the account out of the spaces.

What is not there, on purpose: comments, labels and the list of a page's
attachments (the next bead); an attachment's contents; blogposts; reading a
folder, whiteboard, database or embed itself (`children` lists them, with their
titles, and `page` takes a page's id only); any write; turning storage format
into text; and Confluence Data Center and Server, whose API and login are others.
The yard's source format cannot express what is not listed, and the pack does not
change yardr.
