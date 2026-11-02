# The core part of the jira test, sourced by ./test: the declaration as the
# yard reads it, the check call made through the real yardr, and a pack
# applied again over an edited host. Everything runs in a scratch yard
# under a short path (a unix socket's path is held to 100 bytes) with its
# own home and an environment of nothing but PATH: none of this session's
# YARDR_* variables lead back to a real yard. No daemon is started, so no
# agent is, and the only listener is the stand-in's, on 127.0.0.1 and a
# port the system chooses.
core=$(mktemp -d /tmp/jirat.XXXXXX)
mkdir -p "$core/h"
yrun() { env -i HOME="$core/h" PATH="$PATH" "$YARDR" --home "$core/y" --actor tester "$@"; }

if ! yrun init --harness claude --operator tester >"$core/init.out" 2>&1; then
  echo "test: core FAILED: the scratch yard could not be made: $(tail -c 300 "$core/init.out")"
  fail=1
else
  # -- the declaration as the yard reads it
  if yrun pack apply "$here" --yes >"$core/apply.out" 2>&1; then
    yrun source show jira --json | jq -S .declaration >"$core/declaration.json"
    check "declaration as the yard reads it (base, credential, hook, hear, thread, calls)" "$core/declaration.json" testdata/declaration.golden

    # Atlassian's own test vector for X-Hub-Signature: the declaration's
    # header, prefix and encoding, applied to their secret and payload, make
    # their signature.
    hv=$(jq -c .hook.verify "$core/declaration.json")
    sig=$(printf 'Hello World!' | openssl dgst -sha256 -hmac "It's a Secret to Everybody" | awk '{print $NF}')
    [ "$(jq -r '.scheme + " " + .signed + " " + .signature.header + " " + .signature.encoding + " " + .delivery.header' <<<"$hv")" = "hmac-sha256 body X-Hub-Signature hex X-Atlassian-Webhook-Identifier" ] \
      && [ "$(jq -r .signature.prefix <<<"$hv")$sig" = "sha256=a4771c39fbe90f317c7824e83ddef3caae9cb3d976c214ace1f2937e133263c9" ]
    ok "hook.verify reads Atlassian's documented signature (header, prefix, hex over the body) and delivery id" $?
  else
    echo "test: core FAILED: the pack did not apply: $(tail -c 300 "$core/apply.out")"
    fail=1
  fi

  # -- the check call, through the real yardr, minted by jira/mint
  # The operator's copy: the pack's declaration with its base replaced, and
  # the programs beside it. Here the site is the stand-in.
  mkdir -p "$core/mine"
  cp "$here/jira.yaml" "$core/mine/"
  cp -R "$here/jira" "$core/mine/"
  : >"$core/requests"
  python3 -I testdata/standin.py "$core/port" "$core/requests" testdata/myself.json "$auth" 2>"$core/standin.err" &
  standin_pid=$!
  i=0
  while [ ! -s "$core/port" ] && [ "$i" -lt 200 ]; do sleep 0.05; i=$((i + 1)); done
  if [ ! -s "$core/port" ]; then
    echo "test: core FAILED: the stand-in did not listen: $(cat "$core/standin.err")"
    fail=1
  else
    site=http://127.0.0.1:$(cat "$core/port")
    sed "s|^base: .*|base: $site|" "$here/jira.yaml" >"$core/mine/jira.yaml"
    umask 077
    printf 'JIRA_EMAIL=%s\nJIRA_API_TOKEN=%s\n' "$email" "$token" >"$core/jira.env"
    umask 022
    yrun source add "$core/mine/jira.yaml" >"$core/add.out" 2>&1 && yrun source set jira env_file="$core/jira.env" >>"$core/add.out" 2>&1
    ok "the operator's copy is added and its env file set" $? "$(tail -c 300 "$core/add.out")"
    yrun source check jira >"$core/check.out" 2>&1
    rc=$?
    grep -q 'Yard Bot' "$core/check.out" && grep -q '5b10ac8d82e05b22cc7d4ef5' "$core/check.out" && [ "$rc" = 0 ]
    ok "source check reaches the site with a minted credential and shows the account" $? "exit $rc: $(tail -c 300 "$core/check.out")"
    ! grep -q -e 'avatarUrls' -e 'Europe/Warsaw' -e 'applicationRoles' "$core/check.out"
    ok "source check keeps to the fields the call selects" $?
    ! grep -qF -e "$token" -e "$auth" "$core/check.out" "$core/add.out"
    ok "the token is in no output of the yard's commands" $?
    check "the check call's request" "$core/requests" testdata/check.requests.golden

    # -- a pack applied again over an edited host
    yrun source show jira >"$core/show.before-grant" 2>&1
    yrun source grant jira read --crew yardmaster >/dev/null 2>&1
    umask 077
    printf 'a secret for the hook' >"$core/jira.secret"
    umask 022
    yrun hook add jira --source jira --secret-file "$core/jira.secret" --unknown allow >/dev/null 2>&1
    yrun source show jira >"$core/show.edited" 2>&1
    yrun pack check "$here" >"$core/plan.out" 2>&1
    yrun pack apply "$here" --yes >"$core/reapply.out" 2>&1
    yrun source show jira >"$core/show.reapplied" 2>&1
    grep -qF "$site" "$core/show.edited" && ! grep -qF "https://example.atlassian.net" "$core/show.edited"
    ok "the operator's host is what the source calls after the edit is added" $?
    grep -qF "$site" "$core/plan.out"
    ok "the plan of an update names the host it would take away (how the operator notices)" $?
    grep -qF "https://example.atlassian.net" "$core/show.reapplied" && ! grep -qF "$site" "$core/show.reapplied"
    ok "a pack applied again puts the shipped host back (the edit does not survive)" $?
    grep -qF "$core/jira.env" "$core/show.reapplied"
    ok "the env file stays set across the re-apply" $?
    ! grep -q yardmaster "$core/show.before-grant" && grep -q yardmaster "$core/show.edited" && grep -q yardmaster "$core/show.reapplied"
    ok "a grant of the source stands across the re-apply" $?
    yrun hook list 2>&1 | grep -q '^jira '
    ok "the hook stands across the re-apply" $?
    yrun source add "$core/mine/jira.yaml" >/dev/null 2>&1
    yrun source show jira >"$core/show.readded" 2>&1
    grep -qF "$site" "$core/show.readded" && grep -qF "$core/jira.env" "$core/show.readded"
    ok "adding the edited copy again restores the host, and the env file still stands" $?

    # -- links: none in the pack, and the optional key SETUP.md offers
    bead=$(yrun bead create "a bead to link" --json 2>/dev/null | jq -r .id)
    issue_url=https://acme.atlassian.net/browse/SHED-7?focusedCommentId=10300
    yrun link add "$bead" "$issue_url" >"$core/link.none" 2>&1
    [ $? != 0 ] && ! yrun link list "$bead" 2>&1 | grep -q 'SHED-7'
    ok "without a link key a Jira address links no bead (the per-site cost)" $?
    cp "$core/mine/jira.yaml" "$core/mine/jira.local.yaml"
    sed 's|<site host>|acme.atlassian.net|g' "$here/link.example.yaml" >>"$core/mine/jira.local.yaml"
    yrun source add "$core/mine/jira.local.yaml" >/dev/null 2>&1
    yrun link add "$bead" "$issue_url" >"$core/link.some" 2>&1
    yrun link list "$bead" >"$core/link.list" 2>&1
    grep -qF 'https://acme.atlassian.net/browse/SHED-7' "$core/link.list" && ! grep -q 'focusedCommentId' "$core/link.list"
    ok "with link.example.yaml a Jira address links a bead, kept as the issue's one form" $?
  fi
fi
[ -z "${standin_pid:-}" ] || { kill "$standin_pid" 2>/dev/null; standin_pid=; }
