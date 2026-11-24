# Setting up Jira

The pack wires Jira Cloud into the yard as the declared source `jira`. A Jira
webhook delivers issue and comment events to the yard. The yard answers in the
issue, opens issues and moves them along their workflow, and an agent may read
an issue or search by JQL. What a stage means in Jira is a flow pack's to say,
not this file's.

**The yard acts as one Atlassian account.** Every crew member given the
account's token, and every agent granted a call of this source, is that account
to Jira. It sees what the account sees, in every project the account belongs
to, and nobody is asked before it posts a comment, opens an issue or moves one.
The grant is the permission. Make the account for the yard alone, and give it
the projects the yard should touch and no others.

You need a Jira Cloud site, an administrator of it for step 4, and a public
HTTPS address for the yard's hooks. The pack's programs need `bash`, `curl` and
`jq` on the yard's machine. Commands below call the pack's directory (the `jira`
directory of the yardr-packs checkout) `<pack dir>`.

1. **The account and its token, in Atlassian.** Make an Atlassian account that
   only the yard uses. A service account fits best. Make it in Atlassian
   Administration, under Directory, Service accounts; an organization may have
   five for free. An ordinary account with an email of its own works too. Add it
   to the projects the yard should touch, with a role that may browse them,
   comment, create issues and transition them. The newer Jira screens call
   projects spaces.

   Then make its API token, with scopes. Atlassian recommends that, and gives a
   service account no other kind.
   - A service account: Atlassian Administration, Directory, Service accounts,
     the account, Create credential, API token.
   - An ordinary account: sign in as it, open
     https://id.atlassian.com/manage-profile/security/api-tokens and choose
     Create API token with scopes.

   Choose Jira and the scopes `read:jira-work`, `write:jira-work` and
   `read:jira-user`. Atlassian shows the token once. A token lasts 1 to 365 days,
   a year unless you choose otherwise, so note the day it ends. Step 10 says what
   to do then. A token made without scopes (Create API token) also works, and
   can do everything the account can. Step 2 says where it goes.

2. **The pack and the site's address.** Apply the pack as the operator:
   ```sh
   yardr pack apply <pack dir>
   ```
   The declaration it installs gives the source a placeholder address,
   `https://example.atlassian.net`. A source's credential goes only to the
   host its address names, so the yard must be given yours. Which way
   depends on the token of step 1. Each is one setting of the source, made on
   a card or in a terminal, and neither copies the file.

   A token without scopes is called at the site,
   `https://<site>.atlassian.net`. The declaration has a template for that
   address, so the yard is given the site's host:
   ```sh
   yardr source set jira host=<site>.atlassian.net
   ```
   A crew member who sets the yard up asks for it on a card instead, and the
   operator approves the card, which shows the address now and the one it sets:
   ```sh
   yardr bead ask <bead> - <<'ASK'
   Q: Point the yard's Jira source at our site?
   C: Until the credential is given (step 3), every call fails without sending anything, and the thread commands refuse to run.
   C: This sets it to <site>.atlassian.net, for a token made without scopes. The email and token are given afterwards, on their own card (step 3).
   R: source set jira host=<site>.atlassian.net
   ASK
   ```
   A token with scopes is called through Atlassian's gateway,
   `https://api.atlassian.com/ex/jira/<cloud id>`. That is one host for every
   site, and what differs is a path segment, the cloud id. The declaration has
   a template for that too, so the yard is given the site's cloud id and
   nothing else of the address. Your cloud id is the string after `/s/` in the
   address of admin.atlassian.com, and the site gives it without a login:
   ```sh
   curl -s https://<site>.atlassian.net/_edge/tenant_info
   ```
   It answers `{"cloudId":"<cloud id>"}`. As an example, yardr.atlassian.net
   answers `f84cdad3-1764-4e23-a125-a6259e2fcb7a`, an id that anyone can read
   from that address, so it is no secret. Give the yard yours, as here with that
   one:
   ```sh
   yardr source set jira site=f84cdad3-1764-4e23-a125-a6259e2fcb7a
   ```
   That makes the address
   `https://api.atlassian.com/ex/jira/f84cdad3-1764-4e23-a125-a6259e2fcb7a`.
   A crew member asks for it on a card instead, which the operator approves:
   ```sh
   yardr bead ask <bead> - <<'ASK'
   Q: Point the yard's Jira source at our site's gateway?
   C: Until the credential is given (step 3), every call fails without sending anything, and the thread commands refuse to run.
   C: This sets it to https://api.atlassian.com/ex/jira/<cloud id>, for a token made with scopes. The email and token are given afterwards, on their own card (step 3).
   R: source set jira site=<cloud id>
   ASK
   ```
   The yard keeps a key for the host and the cloud id together, so a key given
   for one site is held back from another until it is given again, and the card
   names the address it was given for. `site=`, `host=` and the placeholder
   replace each other: one address is in use, and `yardr source set jira
   site=` with nothing after it is the placeholder again. Look at the address
   the source calls now:
   ```sh
   yardr source show jira
   ```
   The first line of `source show` is the address in use. Until it is yours,
   `yardr source check jira` fails. The credential (step 3) is not set up yet,
   so nothing is sent. The thread commands refuse to run and say why. Once the
   credential is given, the check calls the address `source show` names. Do
   step 3 after this one and not before, so that the credential is never one
   the yard could send to the placeholder.

3. **The account's credentials, in the yard.** The credential is two names:
   `JIRA_EMAIL`, the account's email, and `JIRA_API_TOKEN`. The pack's `jira/mint`
   makes the Basic credential Atlassian takes from them. They live in env files,
   mode 0600, and never in the store.

   For the source's own calls, `yardr source key` asks for both and shows
   nothing as they are typed. It writes the file the source reads
   (`~/.yardr/sources/jira.env`). Then check the source:
   ```sh
   yardr source key jira
   ```
   ```sh
   yardr source check jira
   ```
   The check calls `GET /rest/api/3/myself` and prints the account: its
   `accountId`, name and email. Keep the `accountId` for step 6.

   A crew member speaks in Jira with the thread commands, and those read the
   crew member's own env file. Have the crew member ask for it, and answer on
   its card, in footplate or in `yardr chat` (`ctrl+o`), where the fields show
   dots:
   ```sh
   yardr bead ask <bead> "The email and token of the Jira account it speaks as" --secret jira --for-crew <name> --context "The yard's Jira account: its email, and an API token with the scopes of SETUP.md step 1."
   ```
   The yard's server writes both into the crew member's env file, or with none
   set into `~/.yardr/crew/<name>.env`, which is then set as `yardr crew set`
   sets it. By hand it is yours instead. A new file takes its mode from the
   shell's umask, so narrow it first. The token is never a command's word,
   because that line would stay in the shell's history. Each command below is one
   thing to type, in a block of its own. Run the third, paste the token blind and
   press Enter:
   ```sh
   umask 077
   ```
   ```sh
   printf 'JIRA_EMAIL=%s\n' '<the account email>' > ~/.yardr/crew/<name>.env
   ```
   ```sh
   IFS= read -rs v && printf 'JIRA_API_TOKEN=%s\n' "$v" >> ~/.yardr/crew/<name>.env; unset v
   ```
   ```sh
   chmod 600 ~/.yardr/crew/<name>.env
   ```
   ```sh
   yardr crew set <name> env_file=~/.yardr/crew/<name>.env
   ```
   The running session does not see a new value: restart the crew member after
   giving it.

4. **The webhook, in Jira.** Sign in as a Jira administrator, not as the yard's
   account: a webhook takes the Administer Jira permission. Choose Settings,
   System, and under Advanced, WebHooks, then create one. Fill it in:
   - The URL is `https://<public host>/hooks/<hook name>`. The path ends in the
     hook's name, the one step 5 gives. Jira delivers to HTTPS addresses whose
     certificate a trusted authority signed, on port 443.
   - The secret signs each delivery. Let Jira generate one and copy it before you
     save, because Jira never shows it again.
   - The events are Issue created and updated, and Comment created, updated and
     deleted. The yard reads those and nothing else.
   - A JQL filter limits the webhook to the projects the yard should hear, such
     as `project in (SHED, OPS)`. Without one Jira sends every issue of the site.
   - Exclude body stays off.

   If the yard's address sits behind a firewall, allow Atlassian's outgoing
   addresses, which https://ip-ranges.atlassian.com/ lists.

5. **The hook and its secret, in the yard.** The secret goes in a file, mode
   0600, which the hook names. A new file takes its mode from the shell's umask,
   so narrow it first. Each command below is one thing to type, in a block of its
   own. Run the second, paste the secret blind and press Enter:
   ```sh
   umask 077
   ```
   ```sh
   IFS= read -rs v && printf '%s' "$v" > ~/.yardr/jira.secret; unset v
   ```
   ```sh
   chmod 600 ~/.yardr/jira.secret
   ```
   ```sh
   yardr hook add jira --source jira --secret-file ~/.yardr/jira.secret --unknown allow
   ```
   One hook serves every crew member. `--unknown allow` hears every site member's
   comment, and keeps a delivery from a sender no yard user maps with the speaker
   `outside`. Give each person their identity (step 6) and their deliveries
   arrive named as them, which a subscription may filter with
   `--where speaker=<user>`.

   A crew member sets the hook up without handling the secret, by two asks on
   one bead, the secret first. The operator pastes the secret where Jira showed
   it, typed unseen, and the yard's server writes it to
   `<home>/hooks/jira.secret`:
   ```sh
   yardr bead ask <id> "The signing secret of the Jira webhook" --secret-hook jira --source jira --context "Jira shows it once, when the webhook is made."
   ```
   ```sh
   yardr bead ask <id> "Add the Jira hook" --run "hook add jira --source jira --unknown allow" --context "The webhook of SETUP.md step 4 posts to it."
   ```

6. **Its identity.** The account id from step 3 is how a delivery is matched to
   the crew member. It is mentioned when a comment or a description mentions the
   account, assigned when an issue's assignee is the account, and deaf to what it
   did itself. That last one matters, because the yard's own comments come back
   as webhooks.
   ```sh
   yardr crew identity <name> --source jira --id <account id>
   ```
   A person's account id ends the address of their Jira profile,
   `https://<site>.atlassian.net/jira/people/<account id>`. Their identity is what
   makes a comment of theirs arrive named as them, and what `yardr thread open
   --assign <user>` assigns by. An id names one user.
   ```sh
   yardr user identity <user> --source jira --id <their account id>
   ```

7. **The grants and who hears.** Opening issues and moving them are the
   operator's to grant:
   ```sh
   yardr crew set <name> open_threads=jira set_state=jira
   ```
   The reads an agent may ask for through `yardr call` are granted by name.
   `read` covers all three: `viewer` (who the account is), `issue` (one issue with
   its comments) and `search` (a JQL query, a page at a time). `yardr pack show
   jira` prints the pack's suggestion. A group of agents takes `--group <group>`
   in place of `--crew <name>`.
   ```sh
   yardr source grant jira read --crew <name>
   ```
   A crew member hears the source through a subscription. `mentions` hears what
   mentions it. `involved`, the default for a hook source, adds what is assigned
   to it and the threads it has opened or answered in. `all` hears every delivery
   the hook keeps.
   ```sh
   yardr subscribe <name> jira --scope involved
   ```

8. **Test it.** As the crew member, open an issue, mention the account from
   Jira, then move the issue:
   ```sh
   yardr thread open jira --in <project key> "Hello from the yard" -b "testing the wiring"
   ```
   In Jira, comment on that issue and type `@` and the account's name. The
   comment lands in the crew member's inbox as mentioned. `yardr thread list
   <name>` shows the thread, whose id is the issue key.
   ```sh
   yardr thread state <thread id> started
   ```
   Jira moves an issue by a transition, so the word picks the transition that
   leads to a status of the right kind. `started` takes a status of the In
   Progress kind. `review` takes one of that kind whose name says review, and
   otherwise does what `started` does. `done` takes a status of the Done kind
   that is not a way of not doing the work: Won't Do, Cancelled, Duplicate and
   the like are skipped. Where the workflow offers no such transition from the
   issue's status, the command says so and moves nothing. A transition that asks
   for a field on a screen, a resolution for instance, fails with Jira's own
   message and the issue stays where it was.

   To open an issue assigned to a person, give them their identity (step 6) and
   name them:
   ```sh
   yardr thread open jira --in <project key> --assign <user> "For you"
   ```

9. **Beads that track issues (optional).** The shipped declaration has no `link`
   key, because the address of a Jira issue starts with your site's own host and
   no pack can name that. Without the key, `yardr link add <bead> <Jira address>`
   is refused (yardr knows no issues there), so a bead cannot track a Jira issue
   and a stage map has nothing to move. The thread commands do not need it. They
   work on the thread's id, which is the issue key.

   To have it, add the key to a copy of the declaration from `link.example.yaml`,
   with your site's own host. Start from a fresh copy so the key is added once:
   copy `<pack dir>/jira.yaml` to `<pack dir>/jira.local.yaml` (your `host=` or
   `site=` setting stands over its placeholder), then
   ```sh
   sed 's|<site host>|<site>.atlassian.net|g' <pack dir>/link.example.yaml >> <pack dir>/jira.local.yaml
   ```
   ```sh
   yardr source add <pack dir>/jira.local.yaml
   ```
   After that `yardr link add <bead> https://<site>.atlassian.net/browse/SHED-7`
   makes the bead track the issue. The key stays as typed, and anything after the
   issue in the address, such as `?focusedCommentId=`, is dropped.

   A stage map moves the tracked issue when its bead enters a stage, as the crew
   member, and never backwards. `hook add` replaces the whole definition, so give
   the secret file and `--unknown allow` again:
   ```sh
   yardr hook add jira --source jira --secret-file ~/.yardr/jira.secret --unknown allow --as <name> --map task:new=started --map task:review=review --map task:merged=done
   ```

10. **Updating the pack, and when the token ends.** A pack applied again replaces
    the source's declaration whole. Your env file, the grants and the hook stay,
    and so does an address given with `yardr source set jira host=` or `site=`
    (step 2): it is a setting of the source and not part of the declaration, so
    the placeholder address does not come back for it and nothing is done after
    the apply. After pulling the checkout, read what would change:
    ```sh
    yardr pack check <pack dir>
    ```
    A copy added with `yardr source add` is the declaration, and a pack applied
    again replaces it. The copy of step 9 is there for the link key, and the
    address comes from your setting, so after the apply the link key is gone and
    the address stays. If you use the key, make the copy again from the new
    `jira.yaml` and add it, as step 9 says.

    An earlier version of step 2 had a token with scopes give its address in a
    copy too (`jira.local.yaml`, made with a `sed`), because the declaration had
    no template for the gateway. If you made one, the plan lists the address as
    `base: <your address> -> https://example.atlassian.net`, and the new template
    as `path_template: (none) -> https://api.atlassian.com/ex/jira/{site}`. The
    first is the copy being undone, which is what you want now. Apply the pack.
    Until you give the cloud id (step 2) the credential is held back from the
    placeholder, a host no yard owns: a call is refused and nothing is sent,
    `yardr source check jira` fails, and the thread commands refuse to run. Then
    give the key again (step 3): it was given for the gateway's host alone, and a
    key is held back from a site on that host until it is given for it. Nothing
    reads the copy after the apply, and you may delete it. If you use the link
    key, step 9 makes a new copy.

    When the token ends, make a new one as in step 1 and give it again: `yardr
    source key jira` for the source, and each crew member's card or file from
    step 3, then restart them. A token that expired or was revoked shows as a 401
    from `yardr source check jira`.

11. **Ending.** Disable or delete the webhook in Jira (Settings, System,
    WebHooks), and remove the hook. Events the hook accepted are kept. Revoke the
    token at id.atlassian.com, or delete the service account's credential in
    Atlassian Administration.
    ```sh
    yardr hook rm jira
    ```
