# Setting up Flagsmith

The pack wires Flagsmith into the yard as the declared source
`flagsmith`. An agent lists the organisations the token sees, the
projects, a project's environments and a project's flags, and reads an
environment's flag states: whether each flag is on and what value it
carries. It only reads. Switching a flag changes the live product at
once, so no call here switches, creates or changes anything.

Read this before the steps. The yard reads as one organisation API
token, an identity of its own. Whatever that token may read, every
agent the operator grants this source reads, and the yard does not
narrow it per person. A token made as a full organisation admin reads
every project of the organisation. Where different people may see
different projects, this source does not fit: a token with RBAC roles
that reads only some projects is the narrower route, and the calls it
may not make fail at Flagsmith.

The steps follow Flagsmith's Management API documentation as of 20
November 2026, and none was run against a live organisation when the
pack was written.

Commands below call the pack's directory (the `flagsmith` directory of
the yardr-packs checkout) `<pack dir>`.

1. **The token.** In Flagsmith, click the organisation name in the top
   navigation panel, open the API Access tab, and Create API Key. Give
   it a name for the yard, and either full organisation admin or the
   RBAC roles it needs; the calls act with whatever it was made with.
   Copy the token for step 3, and do not save it in a file, a command
   line, a nonsecret card or a note. If a crew member needs it, share it
   only by answering the secret card described in step 3. The pack's
   variable for it is `FLAGSMITH_API_KEY`.
2. **The pack, and the base.** Read what applying it does, then apply
   it as the operator, in a terminal:
   ```sh
   yardr pack check <pack dir>
   ```
   ```sh
   yardr pack apply <pack dir>
   ```
   The source's address is `https://api.flagsmith.com/api/v1`, and the
   token goes to no other host.

   A yard on a self-hosted Flagsmith does not call the cloud: give the
   host, and the calls go to `https://<the Flagsmith domain>/api/v1`:
   ```sh
   yardr source set flagsmith host=flagsmith.example.com
   ```
   Give the token again afterwards with step 3: a credential is sent
   only to the host it was given for, so a token given for the cloud
   is held back from the new host until then. The first line of
   `yardr source show flagsmith` is the address in use:
   ```sh
   yardr source show flagsmith
   ```
   Applying the pack again keeps the host, and the shown line says so;
   `yardr source set flagsmith host=` puts the cloud address back.
3. **The token, in the yard.** `yardr source key` asks for it and shows
   nothing as you type. The yard's server writes it into the source's
   env file, `~/.yardr/sources/flagsmith.env`, with mode 0600. The
   value is never an argument or a command's variable, where every
   process of your user could read it:
   ```sh
   yardr source key flagsmith
   ```
   A crew member who needs the token asks for it on a secret card, and
   you answer it at a terminal with `yardr bead answer <bead> <ask>
   --secret`, which reads the value the same way. The answer on the
   bead holds the name and never the value:
   ```sh
   yardr bead ask <bead> "Give the Flagsmith organisation token" --secret flagsmith --context "A token copied from the organisation's settings, API Access tab; the pack's SETUP.md, step 1."
   ```
4. **Who may call what.** A pack of kind source asks no grants at
   import, so what a crew member may call is granted afterwards.
   `yardr pack show flagsmith` prints the pack's one suggested preset:
   1. `read`: every read call, `organisations`, `projects`,
      `environments`, `features` and `featurestates`, and any read call
      the source is later given; it writes nothing.

   A pack applied from a directory takes a preset by the calls it
   names, as this line does:
   ```sh
   yardr source grant flagsmith read --crew yardmaster
   ```
   A grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read Flagsmith" --run "source grant flagsmith read --group reviewers" --context "The reviewers read flag states to check a bead's rollout; the card names each call it covers."
   ```
   One caller may make 60 calls of a source in an hour. Flagsmith
   itself takes 500 requests a minute of its Management API by
   default; a self-hoster changes it with `USER_THROTTLE_RATE`. The
   operator raises the yard's limit where the work needs it:
   ```sh
   yardr source set flagsmith calls_per_hour=300
   ```
   To take a grant back, run `yardr source revoke flagsmith read
   --crew yardmaster`.
5. **Check it.** The source's check call is `organisations`, which
   needs no argument. It confirms the token is set, then asks
   Flagsmith for the organisations and reports the answer:
   ```sh
   yardr source check flagsmith
   ```
   If the check fails, the status it prints is the service's refusal.
   The usual causes are a token that was mistyped or deleted, or a
   self-hosted host that is not the one the yard was told (step 2).
   Give it again with step 3, or check the shown line. Which status
   Flagsmith answers to a wrong token was read from its docs and not
   seen: the pack has never been run against it.
6. **Try it.** As the operator, who may make any call, or in a session
   that was granted the calls. Ids come from the call before. From the
   organisations to their ids:
   ```sh
   yardr call flagsmith organisations
   ```
   From every project to one project's id (`organisation` in each
   entry matches the id above):
   ```sh
   yardr call flagsmith projects
   ```
   From a project's id to its environments, each with the `api_key`
   the states call takes:
   ```sh
   yardr call flagsmith environments project=<id>
   ```
   From a project's id to its flags, each with the `id` the states
   call filters by:
   ```sh
   yardr call flagsmith features project=<id>
   ```
   From an environment's `api_key` to its flag states:
   ```sh
   yardr call flagsmith featurestates environment=<api_key>
   ```
   Each state says its `enabled`, `feature_state_value`, `feature`
   and `identity`. For one flag alone, filter by the id `features`
   gave, or by its name:
   ```sh
   yardr call flagsmith featurestates environment=<api_key> feature=<id>
   ```
   ```sh
   yardr call flagsmith features project=<id> search=<words>
   ```
   Every list answers its first page alone. An answer that has more
   keeps `next` and follows none; `count` says how many there are.
7. **When it does not work.**
   - *the service refuses the token*: a 401 or 403, whatever Flagsmith
     answers. See step 5.
   - *a 429*: the caller spent Flagsmith's 500 requests for the
     minute. Nothing was read by the refused call. Wait for the
     minute.
   - *the answer is over its bound*: yardr refuses an answer over the
     call's bound and does not cut it. The lists are held to 64 KB.
     Narrow with `search`, `is_archived`, `feature` or `feature_name`.
   - *an argument is refused with its pattern*: the call was not sent.
     `yardr source show flagsmith` lists each call's arguments and
     their patterns.
   - *a call that worked stops working, or answers in another shape*:
     Flagsmith changed its Management API. README.md names what the
     pack was built from; compare it with the docs and the swagger's
     current state.
8. **Ending.** Take the grants back, then remove the source. The file
   with the token stays at `~/.yardr/sources/flagsmith.env`, so
   delete it yourself, and delete the token on Flagsmith's API Access
   tab:
   ```sh
   yardr source revoke flagsmith read --crew yardmaster
   ```
   ```sh
   yardr source rm flagsmith
   ```
