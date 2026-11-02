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
   `https://example.atlassian.net`. A source's credential goes only to the hosts
   its file names, so the yard's copy of the file must name yours. A token with
   scopes is called through Atlassian's gateway,
   `https://api.atlassian.com/ex/jira/<cloud id>`. Your cloud id is the string
   after `/s/` in the address of admin.atlassian.com, and the site gives it
   without a login:
   ```sh
   curl -s https://<site>.atlassian.net/_edge/tenant_info
   ```
   A token without scopes is called at the site, `https://<site>.atlassian.net`.
   Write the address you need into a copy of the declaration, beside the
   original so that the programs it names are found, and add the copy to the
   yard. The copy is ignored by git.
   ```sh
   sed 's|^base: .*|base: https://api.atlassian.com/ex/jira/<cloud id>|' <pack dir>/jira.yaml > <pack dir>/jira.local.yaml
   ```
   ```sh
   yardr source add <pack dir>/jira.local.yaml
   ```
   ```sh
   yardr source show jira
   ```
   The first line of `source show` is the address in use. Until it is yours,
   `yardr source check jira` calls the placeholder and fails, and the thread
   commands refuse to run and say why.

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

   To have it, add the key to your copy from `link.example.yaml`, with your site's
   own host. Start from a fresh copy so the key is added once: run step 2's `sed`
   again, then
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
    the source's declaration whole, and the placeholder address comes back with
    it. Your env file, the grants and the hook stay. After pulling the checkout,
    read what would change:
    ```sh
    yardr pack check <pack dir>
    ```
    If you apply the pack, the plan lists the address as `base: <your address> ->
    https://example.atlassian.net`. That line is how you notice, and it is the
    edit being undone. Until you add your copy again, `yardr source check jira`
    calls the placeholder, a host no yard owns, and the thread commands refuse to
    run. The shorter way skips the apply. Make the copy again from the new
    `jira.yaml` with step 2's `sed`, add it with `yardr source add`, and repeat
    step 9 if you use the key. The source then never points at the placeholder.

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
