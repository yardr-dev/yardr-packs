# Setting up Confluence

The pack wires Confluence Cloud into the yard as the declared source
`confluence`. An agent lists the site's spaces, finds pages by CQL, reads one
page, lists the children of a page, folder, whiteboard, database or embed, lists
a page's comments, the replies to a comment, its labels and its attached files,
and names an author from an account id. It reads, and it writes in two ways and
no other: it creates a page under a parent page, and it updates one page's title
and body at the next version. It deletes and moves nothing, and writes no comment,
label or attachment. A page and a comment come as Confluence's storage format,
which is markup and not text: turning it into text, and text into it, is the
agent's. An attached file comes as its metadata, and its contents are not read.

**The yard acts as one Atlassian account.** Every agent granted a read call of
this source reads what that account can read, in every space it can view, and an
agent granted `create` or `update` writes wherever that account may write. The
yard does not narrow either per agent. The grant is the permission: the reads
are granted together, as `read`, and each write by its own name (step 4). Make
the account for the yard alone, give it the spaces the yard should read and no
others, and let it write in the one space the yard writes in (step 1). If the
yard also runs the jira pack, this is the same account: one login, two sources.

You need a Confluence Cloud site and an administrator of it for step 1. The
pack's one program, `confluence/mint`, needs `jq` on the yard's machine. Commands
below call the pack's directory (the `confluence` directory of the yardr-packs
checkout) `<pack dir>`. The steps follow Atlassian's documentation as of 2
November 2026 (for the two writes, 22 November), and none was run against a site
of our own when the pack was written, so a screen may be named otherwise than
here.

1. **The account and its token, in Atlassian.** Use the account the jira pack
   uses, if there is one: make it as step 1 of the jira pack's SETUP.md says (a
   service account in Atlassian Administration, under Directory, Service
   accounts, fits best). Otherwise make an Atlassian account that only the yard
   uses.

   Then give it Confluence, and only the spaces the yard should read. The
   account needs access to Confluence on the site. Then, in each such space,
   Space settings, Permissions: give the account (or a group that holds it
   alone) View, and nothing more. In the one space where the yard is to write,
   give it what creates and edits pages as well. In Atlassian's role-based spaces
   that is the Collaborator role ("adds and edits content in the space"), or the
   permissions Create content and Edit content given alone; in a space still on
   the older permissions it is Add pages. Give it no Delete and no Administer:
   whatever the account may do in a space, `create` and `update` may do there.
   Confluence decides what the account sees, and writes, by its space permissions
   and its groups. A space that lets every user of the site view it, or a group
   the account belongs to, shows the account that space as well, so step 5 has
   you compare what it sees with what you meant.

   Then make its API token. Atlassian recommends a token with scopes, and gives
   a service account no other kind. Its form for one has you choose the app and
   then that app's scopes, so a token the jira pack was given for Jira is not
   made for Confluence, and the same account gets a second token for it:
   - A service account: Atlassian Administration, Directory, Service accounts,
     the account, Create credential, API token.
   - An ordinary account: sign in as it, open
     https://id.atlassian.com/manage-profile/security/api-tokens and choose
     Create API token with scopes.

   Choose Confluence and the eight scopes the calls need, which are the ones
   Atlassian's API description lists for their requests: `read:space:confluence`
   (spaces), `read:page:confluence` (page and labels),
   `read:hierarchical-content:confluence` (children, of any kind),
   `search:confluence` (search), `read:comment:confluence` (comments and
   replies), `read:attachment:confluence` (attachments), `read:confluence-user`
   (user) and `write:page:confluence` (create and update: the description lists
   this one scope for both). Leave the last out if the yard is only to read: the
   token then reads as it did, and the writes answer 401 (step 3). Atlassian
   shows the token once. A token lasts 1 to 365 days, a year unless you choose
   otherwise, so note the day it ends. Step 6 says what to do then.

   A token made without scopes (Create API token, an ordinary account only) is
   the account's, serves Jira and Confluence alike, and can do everything the
   account can, writing included: with one, `create` and `update` write wherever
   the account may, and its space permissions are the only limit on them. If the
   jira pack already has one, it is the same token, given to this source as well.
   Step 2 says where each kind goes.

2. **The pack and the site's address.** Apply the pack as the operator:
   ```sh
   yardr pack apply <pack dir>
   ```
   The declaration it installs gives the source a placeholder address,
   `https://example.atlassian.net/wiki`. A source's credential goes only to the
   host its address names, so the yard must be given yours, with its `/wiki`.
   Which way depends on the token of step 1.

   A token without scopes is called at the site,
   `https://<site>.atlassian.net/wiki`. The declaration has a template for that
   address, so the yard is given the site's host and no copy of the file:
   ```sh
   yardr source set confluence host=<site>.atlassian.net
   ```
   A crew member who sets the yard up asks for it on a card instead, and the
   operator approves the card, which shows the address now and the one it sets:
   ```sh
   yardr bead ask <bead> - <<'ASK'
   Q: Point the yard's Confluence source at our site?
   C: The source calls a placeholder address until it is given the site's host, so every call fails.
   C: This sets it to <site>.atlassian.net, for a token made without scopes. The email and token are given afterwards, on their own card (step 3).
   R: source set confluence host=<site>.atlassian.net
   ASK
   ```
   A token with scopes is called through Atlassian's gateway,
   `https://api.atlassian.com/ex/confluence/<cloud id>/wiki`. A template cannot
   make that address: what varies is a path segment, the cloud id, and not the
   host. So this path keeps a copy of the declaration, and `yardr source add`
   stays in a terminal. The site gives its cloud id without a login:
   ```sh
   curl -s https://<site>.atlassian.net/_edge/tenant_info
   ```
   Write the gateway's address into a copy of the declaration, beside the
   original so that the program it names is found. The copy is ignored by git:
   ```sh
   sed 's|^base: .*|base: https://api.atlassian.com/ex/confluence/<cloud id>/wiki|' <pack dir>/confluence.yaml > <pack dir>/confluence.local.yaml
   ```
   Then add the copy:
   ```sh
   yardr source add <pack dir>/confluence.local.yaml
   ```
   A host that was given stands over the address of a copy, so if you gave one
   first, clear it:
   ```sh
   yardr source set confluence host=
   ```
   Either way, look at the address the source calls now:
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
   access to Confluence or to the space. The check is a read, so it does not try
   a write: a token made without `write:page:confluence` passes it, and `create`
   and `update` then answer 401 with the message `Unauthorized; scope does not
   match`. Step 5 tries a write.

4. **The grant.** A pack of kind source asks none at import, so what a crew
   member may call is granted afterwards. `yardr pack show confluence` prints
   the pack's three suggestions, the presets `read`, `create` and `update`.
   yardr's `--preset` names the presets of the packs inside its binary and not
   those of a pack applied from a directory, so the grant is by name: `read` is
   every read call of the source, one a later file adds included, and neither
   write. The source reads as one account, so a grant of `read` lets that crew
   member read everything the account may. Grant it to those who need it:
   ```sh
   yardr source grant confluence read --crew yardmaster
   ```
   A group of agents takes `--group <group>` in place of `--crew <name>`. A
   grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read Confluence" --run "source grant confluence read --group reviewers" --context "The reviewers read the team's pages to check a bead's work; the card names each call it covers."
   ```
   The two writes change the wiki at once, so each is granted by its own name,
   and `read` covers neither. Grant each to the one crew member that keeps the
   page, and to no group:
   ```sh
   yardr source grant confluence create --crew yardmaster
   ```
   ```sh
   yardr source grant confluence update --crew yardmaster
   ```
   A crew member who needs a write asks on a card instead, one card for each call.
   The card names the call with its method and path, and says that it changes
   something outside the yard:
   ```sh
   yardr bead ask <bead> - <<'ASK'
   Q: Let the yardmaster keep the program's status page in Confluence?
   C: update replaces one page's title and body in Confluence at once, as the yard's Atlassian account, wherever that account may write.
   C: It is sent at the version after the one the caller read, so a page that a person saved meanwhile is refused with a 409, and nothing is retried or merged.
   R: source grant confluence update --crew yardmaster
   ASK
   ```
   The grant says who may call. Where a write lands is the account's space
   permissions and the token's scopes (step 1), which the grant does not widen.

   One caller may make 60 calls of a source in an hour, and an agent that walks
   a page tree, reads the replies of each comment on a page, or names each
   author of a thread with `user` (one call for an account), uses them quickly.
   The operator raises the limit where the work needs it:
   ```sh
   yardr source set confluence calls_per_hour=300
   ```
   A write counts as an update too, and a caller may make 10 updates in an hour. A
   yard that keeps a status page current more often than that raises this limit
   as well. A crew member may ask for it on a card, whose `R:` line is the same
   command:
   ```sh
   yardr source set confluence updates_per_hour=30
   ```
   To take a grant back, run `yardr source revoke confluence update --crew
   yardmaster`, and the same for `create` and `read`.

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

   A page has footer comments, under the page, and inline comments, on a passage
   of its text. `kind` says which, and has no default, so read both:
   ```sh
   yardr call confluence comments id=98404 kind=footer
   ```
   ```sh
   yardr call confluence comments id=98404 kind=inline
   ```
   `comments` lists the first comment of each thread and no reply. The replies to
   a comment are found by its `id`, with the same `kind`, and a reply may have
   replies of its own:
   ```sh
   yardr call confluence replies id=131201 kind=footer
   ```
   A `kind` that is not the comment's is no error: `replies` answers an empty list,
   so check the kind before reading it as "no replies". An inline comment gives
   `properties.inlineOriginalSelection`, the passage it is on, and a comment of
   either kind may give `resolutionStatus`. Its author is `version.authorId`, an
   Atlassian account id, which `user` turns into a name (below). Then the labels
   of a page, and the files attached to it:
   ```sh
   yardr call confluence labels id=98404
   ```
   ```sh
   yardr call confluence attachments id=98404
   ```
   `attachments` gives each file's `title` (its name), `mediaType`, `fileSize` in
   bytes and `downloadLink`, and never the file. The link is a path on the site:
   `_links.base` and the path together are what a person opens. No call here
   fetches it.

   A comment, a reply and an attachment each name their author by
   `version.authorId`, and `user` turns that id into a name:
   ```sh
   yardr call confluence user accountId=5b10ac8d82e05b22cc7d4ef5
   ```
   It answers `accountId`, `displayName` and `accountType`, which is `atlassian`
   for an Atlassian account and `app` for the bot user of an app, and nothing
   else of the account: its email, picture and time zone are not passed on. It
   names one account, so an agent with several authors calls it for each, and
   each call counts toward the hourly limit of step 4. A 404 is an id that is not
   there. A 403 is an account that may not view users; Atlassian's description
   asks for the 'Can use' permission on the site. Atlassian may limit what it
   tells of a user by their profile visibility, so a name can be the public name
   only.

   `spaces`, `children`, `search`, `comments`, `replies`, `labels` and
   `attachments` answer one page of 25, and `limit` asks for another size (250 at
   most for all but `search`). An answer that has another page keeps it as
   `_links.next`, whose `cursor=` value is `cursor` in the same call again (for
   `children`, `comments` and `replies`, with the same `id` and `kind`). Search
   writes it percent-encoded (`%2B`, `%3D`), and the call encodes what it is
   given, so give it decoded:
   ```sh
   yardr call confluence children id=98400 cursor=eyJpZCI6Ijk4NDExIiwiY29udGVudE9yZGVyIjoiY2hpbGQtcG9zaXRpb24iLCJjb250ZW50T3JkZXJWYWx1ZSI6MjAwMH0=
   ```

   `page` answers the body as `body.storage.value`, in storage format: XHTML with
   Confluence's own tags (`ac:structured-macro`, `ac:link`, `ri:page`). It is
   markup and not text, and the answer is at most 256 KiB, refused and not cut
   when a page is longer. A comment is the same markup in the same place, and
   `comments`, `replies` and `attachments` answer at most 256 KiB too. A failed
   read tells the agent the status alone: a 404 is a page that is not there, or
   one the account may not view (Confluence answers both so), and a 400 from
   `search` is a CQL it cannot parse. A 400 from `comments` or `replies` can also
   be an id that is not there: Atlassian's pages say 404, and the public site
   that was tried answered 400.

   A write changes the wiki, so try it where nobody reads: under a page of the
   yard's own, in the one space it writes in. `create` takes the space's `id`
   (`spaces` answers it, and it is not the key an address shows), the parent
   page's id, a title and the body in storage format:
   ```sh
   yardr call confluence create spaceId=98304 parentId=98400 title='Program status' body='<p>Nothing to report yet.</p>'
   ```
   It answers the new page's `id`, its `status` (`current`: it is published), its
   `version` and `_links`, and never the body; `_links.base` and the `webui` path
   together are the link a person opens. The page lands under its parent and
   never at the root of a space, and a call with no parent is refused. A title is
   one line of at most 255 characters, and a body at most 60000. Plain
   paragraphs, headings and tables serve a status page. Confluence judges the
   markup: what it cannot take is a 400, whose reason comes back with the
   refusal, as `errors`. The call builds no macro and checks none, and sends the
   body as it was given.

   To replace a page's body, read the page, for its version and its title, and
   give the next number:
   ```sh
   yardr call confluence page id=98512
   ```
   ```sh
   yardr call confluence update id=98512 version=2 title='Program status' body='<p>One bead in review.</p>'
   ```
   `version` is the number the page becomes: the `version.number` that `page`
   answered, plus one. `title` is required by Confluence: the page's own title
   keeps it, and another renames the page. The body is the whole new body, so
   what it leaves out is gone from that version, and the earlier version stays in
   the page's history. The answer has the new `version`, so the next update asks
   for its `number` plus one.

   A person who saves the page between the read and the write makes the number
   stale, and Confluence refuses with a 409. The call fails, and what Confluence
   said comes with it, as `errors`. Its title reads like this:
   ```text
   Version must be incremented when updating a page. Current Version: [3]. Provided version: [3]
   ```
   Read the page again, make the change on what is there now, and call again with
   that number plus one. Nothing here retries or merges, so that a person's edit
   is not written over by an agent that has not read it. Atlassian lists one more
   409 for `update`: a site with content approvals on, whose space requires
   approval before a page is published. The change then has to be saved as a draft
   and approved, which this call does not do, since it publishes.

   Two things the number does not guard. A person's unsaved draft of the page is
   not under it, and Atlassian says an update of the current version may override
   that draft entirely. And a call tried again after a lost answer is sent with
   the same number, which the first made if it landed, so the second is refused:
   read the page to see. A `create` tried again may make a second page, or be
   refused for a title already in the space, since Confluence takes no key to run
   a request once.

   A 401 on a write while the reads work is a token made without
   `write:page:confluence` (step 1). A 404 is a space, a parent or a page that is
   not there, or one the account may not view or may not write in: Atlassian's
   description lists all of these as one 404.

6. **Updating the pack, and when the token ends.** A pack applied again replaces
   the source's declaration whole. Your env file and the grants stay, and so does
   a host given with `yardr source set confluence host=` (step 2): it is a
   setting of the source and not part of the declaration, so the placeholder
   address does not come back for it and nothing is done after the apply. A copy
   added with `yardr source add` is the declaration, and the placeholder comes
   back with it. After pulling the checkout, read what would change:
   ```sh
   yardr pack check <pack dir>
   ```
   If you use a copy and apply the pack, the plan lists the address as `base:
   <your address> -> https://example.atlassian.net/wiki`. That line is how you
   notice, and it is the edit being undone. Until you add your copy again, the
   credential is held back from the placeholder, a host that is not your site: a
   call is refused and nothing is sent, and `yardr source check confluence`
   fails. The shorter way skips the apply. Make the copy again from the new
   `confluence.yaml` with step 2's `sed`, and add it with `yardr source add`. The
   source then never points at the placeholder.

   An update from a version that had only `spaces`, `page`, `children` and
   `search` adds `comments`, `replies`, `labels`, `attachments` and `user`, and
   one from a version without `user` adds that one. The plan lists them and names
   each crew member who gets them through a grant of `read` already held. Nobody
   is asked, and `yardr source revoke confluence read --crew <name>` takes the
   grant back. A token with scopes made before a call was added lacks its scope:
   `read:comment:confluence` and `read:attachment:confluence` for `comments`,
   `replies` and `attachments`, and `read:confluence-user` for `user`. Atlassian
   answers those calls with a 401 until a token with every scope of step 1 is made
   and given again with `yardr source key confluence`. A token made without scopes
   needs nothing.

   An update from a version that had no writes adds `create` and `update`. A grant
   of `read` covers neither, so nobody can call them until each is granted by its
   name (step 4). They need `write:page:confluence` as well: a token made with the
   seven read scopes only reads, and its writes answer 401 until a token with all
   eight is made (step 1) and given again with `yardr source key confluence`. A
   token made without scopes needs nothing, and the account's space permissions
   say where it may write.

   When the token ends, make a new one as in step 1 and give it again with
   `yardr source key confluence`. A token that expired or was revoked shows as a
   401 from `yardr source check confluence`.

7. **Ending.** Remove the source, which takes its grants with it:
   ```sh
   yardr source rm confluence
   ```
   Revoke the token at id.atlassian.com, or delete the service account's
   credential in Atlassian Administration, and take the account out of the spaces.
   The pages the yard made stay in Confluence: nothing here deletes a page, so a
   person removes them.

What is not there, on purpose: an attachment's contents; blogposts, and the
comments, labels and attachments of anything but a page; several account ids
named in one call, and an account's email, picture or time zone (`user` names
one account); reading a folder, whiteboard, database or embed itself (`children`
lists them, with their titles, and `page` takes a page's id only); any write but
`create` and `update`, so no delete, no move of a page to another parent or space,
no change of its owner, no draft, and no comment, label or attachment written; a
page at the root of a space; building markup or macros for a body, which is sent
as it is given and judged by Confluence; retrying or merging a stale version,
which the agent does by reading the page again; turning storage format into text;
and Confluence Data Center and Server, whose API and login are others.
The yard's source format cannot express what is not listed, and the pack does not
change yardr.
