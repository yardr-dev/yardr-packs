# Setting up GitLab

The pack wires GitLab into the yard as the declared source `gitlab`. The
yard hears a project's issues, merge requests and comments through a
webhook, and answers in those threads: it replies, opens an issue, and
closes or reopens an issue or a merge request. What a stage means in
GitLab is a flow pack's to say, not this file's.

This is the first slice of the pack. Reading a merge request and its
pipelines back, and the calls an agent makes, come in the next one. The
file names gitlab.com. Step 9 says what a self-managed instance changes.

1. **Apply the pack.** From main of the yardr-packs repository, as an
   operator. The pack runs two programs of its own as you, `gitlab/normalize`
   and `gitlab/thread`, and they need `jq`, `curl` and `bash`.
   ```sh
   yardr pack apply /Users/mckean/projects/repos/yardr-packs/gitlab
   ```
2. **The hook and its secret.** GitLab sends the secret back in the
   `X-Gitlab-Token` header of every delivery, and the hook compares it as
   it arrives. Make a long random one. This prints it once, so copy it for
   step 3:
   ```sh
   openssl rand -hex 32
   ```
   The secret goes in a file, mode 0600, which the hook names. A new file
   takes its mode from the shell's umask, so narrow it first. The secret is
   never a command's word, because that line would stay in the shell's
   history. Run the second command, paste the secret blind and press Enter:
   ```sh
   umask 077
   ```
   ```sh
   IFS= read -rs v && printf '%s' "$v" > ~/.yardr/gitlab.secret; unset v
   ```
   ```sh
   chmod 600 ~/.yardr/gitlab.secret
   ```
   ```sh
   yardr hook add gitlab --source gitlab --secret-file ~/.yardr/gitlab.secret --unknown unknown
   # hook gitlab saved: POST /hooks/gitlab (gitlab)
   ```
   `--unknown` says what the hook does with a sender no user maps. `unknown`
   holds the delivery on a mapping card until the operator answers it.
   `allow` hears the sender as an outsider, whose words reach an inbox as
   information, not instructions, which suits a public project. `ignore`
   drops them. One hook serves every crew member, and `yardr hook list`
   shows it with STATE `ok`.
3. **The webhook, on the project.** In GitLab open the project, then
   Settings, Webhooks, Add new webhook. Set the URL to
   `https://<public host>/hooks/gitlab`, where the path ends in the hook's
   name from step 2, and the Secret token to step 2's secret. Tick the
   triggers Comments, Work item events and Merge request events. Older
   GitLab calls the second one Issues events. Leave SSL verification on.

   Leave the confidential and internal triggers off. The yard answers with
   an ordinary comment, which everyone who can read the thread sees, so it
   should not hear what only members may read.

   GitLab also offers a signing token and calls the secret token weaker.
   This pack checks the secret token, which every GitLab version sends. It
   takes project webhooks. A group webhook sends the same bodies, but
   nothing here has run against one.
4. **The yard's token.** The yard acts in GitLab as one account. From that
   account make a personal access token: the avatar, Edit profile, Access,
   Personal access tokens, Generate token, Legacy token. Give it the scope
   `api` and no other. A token with `read_api` can read but not write, so
   every reply, opened issue and status change answers 403. By default
   GitLab lets a token live a year at most. Put the expiry in a calendar,
   because an expired token answers 401.

   Have the crew member ask for it, and answer on its card, in footplate or
   in `yardr chat` (`ctrl+o`), where the field shows dots:
   ```sh
   yardr bead ask <bead> "The token it answers with" --secret gitlab --for-crew <name> --env GITLAB_TOKEN --context "In GitLab, from the account the yard acts as: avatar, Edit profile, Access, Personal access tokens, Generate token, Legacy token. Scope api, and an expiry within a year."
   ```
   The yard's server writes it into the crew member's env file, or with none
   set into `~/.yardr/crew/<name>.env`, which is then set as `yardr crew set`
   sets it. The running session does not see the new value, so restart the
   crew member after giving it. By hand it is yours instead. Narrow the
   umask first, as in step 2. The token is never a command's word, so type
   or paste it blind after the second command:
   ```sh
   umask 077
   ```
   ```sh
   IFS= read -rs v && printf 'GITLAB_TOKEN=%s' "$v" > ~/.yardr/crew/<name>.env; unset v
   ```
   ```sh
   chmod 600 ~/.yardr/crew/<name>.env
   ```
   ```sh
   yardr crew set <name> env_file=~/.yardr/crew/<name>.env
   ```
   `yardr source check` looks over the credential and every thread command,
   and sends nothing to GitLab:
   ```sh
   yardr source set gitlab env_file=~/.yardr/crew/<name>.env
   ```
   ```sh
   yardr source check gitlab
   ```
5. **Its identity.** The username of the account the token acts as, the
   handle after the @ on its GitLab profile. A comment that says
   `@<username>` mentions the crew member, and what the account writes
   itself never reaches its inbox.
   ```sh
   yardr crew identity <name> --source gitlab --key <username>
   ```
   A crew member setting itself up proposes it instead, from its session,
   and the operator approves the card:
   ```sh
   yardr bead ask <bead> "Who am I on GitLab?" --run "crew identity <name> --source gitlab --key <username>"
   ```
   A username is kept lowercase, however it was typed.
6. **Who is heard.** The pack hears by identity. A delivery is kept when its
   sender is a user of the yard, and step 2's `--unknown` word says what
   happens to anyone else. Map each person by their GitLab username. The
   same key is whom the yard assigns an issue to when it opens one for them:
   ```sh
   yardr user identity <user> --source gitlab --key <their username>
   ```
   Then subscribe the crew member to what it should hear. Mentions are the
   usual start:
   ```sh
   yardr subscribe <name> gitlab --scope mentions
   ```
   `--scope involved` adds the threads it takes part in, and `--scope all`
   everything the hook lets through. `--where` narrows by `type`, `action`,
   `repo`, `label`, `noteable`, `state`, `number`, `head_branch`, `base` and
   `speaker`.
7. **The grants.** Opening issues and setting their status are the
   operator's to grant:
   ```sh
   yardr crew set <name> open_threads=gitlab set_state=gitlab
   ```
8. **Test it.** As the crew member, open an issue in a project the account
   can write to. The project may sit in subgroups, as
   `<group>/<subgroup>/<project>`:
   ```sh
   yardr thread open gitlab --in <group>/<project> "Hello from the yard" -b "testing the wiring"
   ```
   The answer names the thread, `<group>/<project>#<n>`. Comment
   `@<username>` on the issue in GitLab and the comment lands in the crew
   member's inbox as mentioned. Answer it by its number, then close the
   issue and open it again:
   ```sh
   yardr reply <seq> "Seen. Closing this."
   ```
   ```sh
   yardr thread state <group>/<project>#<n> done
   ```
   ```sh
   yardr thread state <group>/<project>#<n> started
   ```
   A merge request is `<group>/<project>!<n>`. `done` closes it without
   merging, `started` reopens a closed one, and one that is merged stays
   merged. `label:<name>` adds a label to either and never removes one.
   `yardr thread list <name>` shows the threads the crew member takes part
   in.

   To open an issue assigned to a person, map them in step 6 and name them.
   GitLab Free takes one assignee. If GitLab makes the issue and drops the
   assignee, the command says so and the issue stays:
   ```sh
   yardr thread open gitlab --in <group>/<project> --assign <user> "For you"
   ```
9. **A self-managed instance.** The file names gitlab.com in four places. For
   an instance at `gitlab.example.com`, copy the pack's directory, set
   `base` to `https://gitlab.example.com/api/v4`, `link.host` to
   `gitlab.example.com`, and the two `fixed` templates under `link` to the
   same host. Apply the copy instead. A second instance is a second copy
   under another source name, which also changes `name` in `pack.yaml` and
   `gitlab.yaml`. The copy's tests expect gitlab.com, so update them or leave
   them out of your copy.
10. **Ending hearing.** Remove the hook, then delete the webhook in GitLab
    and revoke the token there:
    ```sh
    yardr hook rm gitlab
    ```
    Events the hook accepted are kept.

Two limits matter before the yard writes in a project, and README.md has
both in full. A line of a reply that starts with a slash is posted with one
space in front, because GitLab would run it as a quick action. And GitLab
numbers issues and merge requests apart while the core takes issue 7 and
merge request 7 for one thread, which matters once a hook has `says` or
`makes` lines.
