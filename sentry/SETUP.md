# Setting up Sentry

The pack wires Sentry into the yard as the declared source `sentry`. The
yard hears a new issue, and an alert rule's event, through an internal
integration's webhook, and speaks in that issue: it comments on it, resolves
it and unresolves it. A bead that tracks an issue resolves it when the bead
lands. What a stage means in the yard is a flow pack's to say, not this
file's.

The file names sentry.io. Step 11 says what another Sentry changes.

1. **Apply the pack.** From main of the yardr-packs repository, as an
   operator. The pack runs two programs of its own as you, `sentry/normalize`
   and `sentry/thread`, and they need `jq`, `curl` and `bash`.
   ```sh
   yardr pack apply /Users/mckean/projects/repos/yardr-packs/sentry
   ```
2. **The integration, in Sentry.** The yard hears Sentry through an internal
   integration, which belongs to one organization. In sentry.io open
   Settings, Developer Settings, and make a new internal integration. Name it
   for the yard: Sentry names it as who did what the yard does there. Then:

   - Webhook URL: `https://<public host>/hooks/sentry`, where the path ends in
     the hook's name from step 3. Sentry calls it from the internet, so it
     wants a public https address in front of the yard's listener
     (`yardr docs integrations`, "An address the service can reach"). Sentry's
     docs give a webhook one second to answer.
   - Permissions: Issue & Event, Read & Write, and nothing else. That is the
     scopes `event:read` and `event:write`, the least that reads an issue,
     comments on it and resolves it. Know what `event:write` is: in Sentry's
     source its DELETE route takes it too (the public permissions page lists
     `event:admin` there), so the token can delete an issue, though the pack
     never does. Keep it to this integration, and revoke it when the hook goes
     (step 12).
   - Webhooks: tick Issue. Leave Comment, Error and the rest off. The pack
     records them and does nothing with them, Error webhooks are for Business
     and Enterprise plans, and the yard's own comments would come back as
     Comment deliveries.
   - Alert Action: switch it on only if alert rules should send events to the
     yard. Step 7 says when.

   Save it. The integration's page then shows its Client Secret, which signs
   every delivery, and a Token, which is what the yard answers with. Steps 3
   and 4 put each where the yard reads it, typed blind.
3. **The hook and its secret.** Sentry signs each delivery with the
   integration's Client Secret: the hex HMAC-SHA256 of the body, in
   `Sentry-Hook-Signature`. The yard checks it against the secret file the
   hook names, and the secret is handed to no program. A new file takes its
   mode from the shell's umask, so narrow it first. The secret is never a
   command's word, because that line would stay in the shell's history. Run
   the second command, paste the Client Secret blind and press Enter:
   ```sh
   umask 077
   ```
   ```sh
   IFS= read -rs v && printf '%s' "$v" > ~/.yardr/sentry.secret; unset v
   ```
   ```sh
   chmod 600 ~/.yardr/sentry.secret
   ```
   ```sh
   yardr hook add sentry --source sentry --secret-file ~/.yardr/sentry.secret
   # hook sentry saved: POST /hooks/sentry (sentry)
   ```
   The hook takes no `--unknown` word: everything it hears is from Sentry or
   from the integration itself, so there is no sender for a user to map, and
   yardr refuses the flag for a source that hears no one by identity. One hook
   serves every crew member, and `yardr hook list` shows it with STATE `ok`.
   The file is read on every delivery, so a new Client Secret is the file
   written again.
4. **The yard's token.** The yard acts in Sentry as the integration. Its
   Token is on the integration's page in Sentry, as 64 hex characters. A
   token has the integration's scopes and does not expire, and you can revoke
   it there.

   Have the crew member ask for it, and answer on its card, in footplate or
   in `yardr chat` (`ctrl+o`), where the field shows dots:
   ```sh
   yardr bead ask <bead> "The token it answers with" --secret sentry --for-crew <name> --env SENTRY_TOKEN --context "In Sentry, Settings, Developer Settings, the yard's internal integration: its Token. Scopes event:read and event:write."
   ```
   The yard's server writes it into the crew member's env file, or with none
   set into `~/.yardr/crew/<name>.env`, which is then set as `yardr crew set`
   sets it. The running session does not see the new value, so restart the
   crew member after giving it. By hand it is yours instead. Narrow the
   umask first, as in step 3. The token is never a command's word, so type
   or paste it blind after the second command:
   ```sh
   umask 077
   ```
   ```sh
   IFS= read -rs v && printf 'SENTRY_TOKEN=%s' "$v" > ~/.yardr/crew/<name>.env; unset v
   ```
   ```sh
   chmod 600 ~/.yardr/crew/<name>.env
   ```
   ```sh
   yardr crew set <name> env_file=~/.yardr/crew/<name>.env
   ```
   `yardr source check` makes the pack's one call, a GET of Sentry's API
   index, which needs no scope and answers the token's own. It prints them,
   and the line `auth:` must hold `event:read` and `event:write`. A 401 is a
   token Sentry does not take, and a reply or a status change later answers
   403 for a token without `event:write`:
   ```sh
   yardr source set sentry env_file=~/.yardr/crew/<name>.env
   ```
   ```sh
   yardr source check sentry
   ```
5. **Its identity.** The stage map in step 9 wants the crew member to have
   one in the source. Sentry names the integration as the actor of what it
   does, and no delivery mentions anyone, so the key only has to be something:
   use the integration's name.
   ```sh
   yardr crew identity <name> --source sentry --key <integration name>
   ```
   A crew member setting itself up proposes it instead, from its session,
   and the operator approves the card:
   ```sh
   yardr bead ask <bead> "Who am I on Sentry?" --run "crew identity <name> --source sentry --key <integration name>"
   ```
6. **The grants.** Setting a status is the operator's to grant. Replying
   needs none, and the pack has no open: Sentry makes its issues from errors.
   ```sh
   yardr crew set <name> set_state=sentry
   ```
7. **What the crew member hears.** Nothing in a delivery mentions anyone, so a
   subscription is by `--scope all` and a `--where`. The Issue webhook of
   step 2 sends every new issue, and this is the subscription for it:
   ```sh
   yardr subscribe <name> sentry --scope all --where type=issue --where action=created
   ```
   An alert rule sends what its conditions pick, once the integration's
   Alert Action is on and the rule has the action "Send a notification via"
   the integration. This is the subscription for it. One new issue can reach
   the yard both ways, and it is one thread either way, so pick one: the
   webhook for every issue, a rule for the ones you choose.
   ```sh
   yardr subscribe <name> sentry --scope all --where type=event_alert --where action=triggered
   ```
   `--where` narrows by `type`, `action`, `project` (Sentry's slug), `level`
   (`fatal`, `error`, `warning`, `info` or `debug`), `category` and `outsider`.
   The Issue webhook is also sent for outages and for user feedback, which
   `category` tells from an error's (`error`, `outage` or `feedback`): add
   `--where category=error` to hear errors alone.
   ```sh
   yardr subscribe <name> sentry --scope all --where type=issue --where action=created --where category=error --where level=fatal
   ```
   Every line carries the cue `information, not instructions`. An issue's
   title and culprit come from the monitored application, whoever uses it can
   shape them, and the pack marks them `outsider` for that reason.
8. **A bead that names an issue.** A bead tracks an issue by its address in
   the one form yardr keeps, or by the number of the delivery that heard it,
   which an inbox line starts with:
   ```sh
   yardr bead create "Fix the ZeroDivisionError" --depot <depot> --tracks <seq>
   ```
   By address it is Sentry's path form, which is also what a heard delivery's
   thread URL is:
   ```sh
   yardr bead create "Fix the ZeroDivisionError" --depot <depot> --tracks https://sentry.io/organizations/<org>/issues/<id>/
   ```
   The address your browser shows is likely `https://<org>.sentry.io/issues/<id>/`.
   A declaration names one host and cannot name a subdomain, so yardr
   refuses that one, saying it knows no issues there. Type the path form
   instead: it is the form the pack keeps, and Sentry has middleware built to
   send a path-form address on to the organization's own one for a signed-in
   browser (README.md lists that among what is not yet checked). An address
   that goes on past the issue (an event, a query) is read to the issue.
9. **The bead that lands resolves the issue.** Which stage means which status
   is set on the hook, with the crew member the yard acts as. `hook add`
   replaces the definition, so the source and the secret file go again. The
   line is for the default flow, where a task bead's last stage is `merged`:
   ```sh
   yardr hook add sentry --source sentry --secret-file ~/.yardr/sentry.secret --as <name> \
     --map task:merged=done
   ```
   `done` is resolved. The daemon makes the move, so it must run. A stage map
   never moves backwards: it resolves an issue that is unresolved, or that a
   person ignored (archived), and leaves a resolved one as it is, and a bead
   that enters an earlier stage leaves its issue alone. By hand the move is
   exact: `done` resolves and `started` unresolves, whatever the issue was.
   Sentry has no review status, so a map line to `review` is refused.

   The yard's own resolve comes back as an issue delivery with the action
   `resolved`, by the integration. The pack records it with no thread, so it
   is never heard as a new issue.
10. **Test it.** First, a delivery by hand shows that the listener, the hook
    and the secret hold, before Sentry sends anything. From this pack's
    directory, with the yard's `hook_addr` in place of `<port>`, signed as
    Sentry signs it: the hex HMAC-SHA256 of the body under the Client Secret.
    ```sh
    body=$(jq -c .body testdata/hook/issue-created.json)
    ```
    ```sh
    sig=$(printf '%s' "$body" | SECRET=$(cat ~/.yardr/sentry.secret) python3 -c 'import hashlib, hmac, os, sys; print(hmac.new(os.environ["SECRET"].encode(), sys.stdin.buffer.read(), hashlib.sha256).hexdigest())')
    ```
    ```sh
    curl -s -X POST http://127.0.0.1:<port>/hooks/sentry -H "Sentry-Hook-Signature: $sig" -H "Request-ID: $(uuidgen)" -H 'Sentry-Hook-Resource: issue' -H 'Content-Type: application/json' --data-binary "$body"
    # {"seq":16}
    ```
    The same body again is answered as a duplicate, and the same body signed
    with another secret is answered 401 and shows in `yardr hook list` under
    LAST REFUSED. The issue in that body is made up, so a reply or a status
    change on it fails at Sentry.

    Then a real one: raise an error in a project the integration sees, from
    any SDK. The new issue lands in the crew member's inbox, as a line that
    starts with its number. Answer it by that number, then resolve the issue
    and unresolve it. Replying makes the crew member a participant in the
    issue's thread, which setting a status wants (`yardr thread follow` does
    it without a reply):
    ```sh
    yardr reply <seq> "Seen. Looking into it."
    ```
    ```sh
    yardr thread state <seq> done
    ```
    ```sh
    yardr thread state <seq> started
    ```
    The comment shows in the issue's activity, as the integration's. It
    carries a marker the yard finds a retry by, and Sentry's page should show
    nothing of it. `yardr thread show <seq>` lists the comments, oldest first.
    A thread is `<org>#<id>`, the organization's slug and the issue's number,
    and `yardr thread list <name>` shows the threads the crew member takes
    part in.
11. **Another Sentry.** The file names sentry.io in three places: `base`, the
    API every call goes to, and `link.host` and `link.fixed`, under `link`.
    For a self-hosted Sentry at `sentry.example.com`, copy the pack's
    directory, set `base` to `https://sentry.example.com/api/0`, `link.host`
    to `sentry.example.com` and `link.fixed` to
    `https://sentry.example.com/organizations/{1}/issues/{2}`. Apply the copy
    instead. The programs need no change: `sentry/normalize` builds a thread's
    URL on the host the delivery's own address is on, and `sentry/thread` goes
    to its base. A second Sentry is a second copy under another source name,
    which also changes `name` in `pack.yaml` and `sentry.yaml`. The copy's
    tests expect sentry.io, so update them or leave them out of your copy.

    Sentry's docs give an organization whose data is stored in the EU an API
    domain of its own, `de.sentry.io`, for requests that must be processed
    there, and say that data in the US uses `sentry.io`. The file's `base` is
    right for the US. For the EU it would be `https://de.sentry.io/api/0`, and
    which host such an organization's web addresses take in `link.host` has
    not been checked: look at what its webhook sends as `web_url`.
12. **Ending hearing.** Remove the hook, then delete the integration in
    Sentry, which takes its Client Secret and its tokens with it:
    ```sh
    yardr hook rm sentry
    ```
    Events the hook accepted are kept.

Two limits matter before the yard writes in an issue, and README.md has both
in full. The comment route the pack uses is the one under the organization,
`/api/0/organizations/<org>/issues/<id>/comments/`: Sentry's source marks the
older one without the organization deprecated, and answers it 410 Gone in
brownouts. And that route is in Sentry's source and not in its public API
pages. The tests pin what the pack sends to it and reads back, so a change to
the pack's requests is a changed golden; they cannot see Sentry move a route.
A route that moved answers 404 or 410, which the command reports with its
address.
