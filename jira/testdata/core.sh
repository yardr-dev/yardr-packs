# The core part of the jira test, sourced by ./test: the declaration as the
# yard reads it, the check call made through the real yardr (at the site's
# address, and at the gateway's), and a pack applied again over an edited
# host, with the host and the site the templates make. Everything runs in a
# scratch yard
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

    # base_template and path_template are what let SETUP.md step 2 give the
    # host or the cloud id on a card, and a golden written again would pass
    # without them, so they are checked here too. The gateway's product
    # segment is the file's, and {site} is the one segment after it.
    jq -e '.base == "https://example.atlassian.net" and .base_template == "https://{host}" and .path_template == "https://api.atlassian.com/ex/jira/{site}" and ([.calls[] | .kind == "read"] | all) and (.calls | length) == 3' "$core/declaration.json" >/dev/null
    ok "the shipped host is the placeholder with its two templates, and every call is a read" $?

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

    # -- the same call through the gateway a token with scopes is called at,
    # which SETUP.md step 2 reaches with `source set jira site=<cloud id>`: the
    # path template with the cloud id in its one segment, and the path of the
    # call after it. The template the file ships is https at api.atlassian.com
    # and the stand-in is plain http, so the copy has the scheme and host of its
    # template replaced by the stand-in's and keeps the path as the file has it;
    # the setting does the rest. The address is given before the key, as
    # SETUP.md has it, and the key is given for it (step 3). The golden is
    # its own: the request has the cloud id in its path, which the unscoped
    # call's has not.
    cloud=0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d
    sed -e "s|^base: .*|base: $site|" -e "s|^path_template: https://[^/]*|path_template: $site|" "$here/jira.yaml" >"$core/mine/jira.local.yaml"
    grep -qF "path_template: $site/ex/jira/{site}" "$core/mine/jira.local.yaml"
    ok "the copy's path template is the file's, aimed at the stand-in" $?
    yrun source add "$core/mine/jira.local.yaml" >"$core/add.gateway.out" 2>&1 && yrun source set jira site=$cloud >>"$core/add.gateway.out" 2>&1 && printf 'JIRA_EMAIL=%s\nJIRA_API_TOKEN=%s\n' "$email" "$token" | yrun source key jira >>"$core/add.gateway.out" 2>&1
    ok "the copy is added, its site set to a cloud id, and the key given for it" $? "$(tail -c 300 "$core/add.gateway.out")"
    : >"$core/requests"
    yrun source check jira >"$core/check.gateway.out" 2>&1
    rc=$?
    grep -q 'Yard Bot' "$core/check.gateway.out" && [ "$rc" = 0 ]
    ok "source check reaches the site through the gateway's address and shows the account" $? "exit $rc: $(tail -c 300 "$core/check.gateway.out")"
    check "the check call's request through the gateway's address" "$core/requests" testdata/gateway.requests.golden
    ! grep -qF -e "$token" -e "$auth" "$core/check.gateway.out" "$core/add.gateway.out"
    ok "the token is in no output of the yard's commands through the gateway either" $?
    # What follows is about the unscoped copy again: the site is given up and
    # that copy is the declaration, as it was.
    yrun source set jira site= >/dev/null 2>&1
    yrun source add "$core/mine/jira.yaml" >/dev/null 2>&1

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

    # The host the template makes, which is how SETUP.md step 2 points a token
    # without scopes at the site. It is a setting of the source and not part
    # of the declaration, so it is shown as the address in use, stands across
    # a pack applied again (step 10) and over a copy added after it (step 2
    # clears it first), and gives the declaration's own address back when it
    # is emptied. No call goes through it here: the template is https and the
    # stand-in is plain http on loopback.
    yrun source set jira host=mysite.atlassian.net >"$core/host.set.out" 2>&1
    yrun source show jira >"$core/show.host" 2>&1
    sed -n 1p "$core/show.host" | grep -qF 'https://mysite.atlassian.net'
    ok "source set host= makes https://<host>, which source show names first" $? "$(tail -c 300 "$core/host.set.out")"
    yrun pack apply "$here" --yes >/dev/null 2>&1
    yrun source show jira >"$core/show.host.reapplied" 2>&1
    sed -n 1p "$core/show.host.reapplied" | grep -qF 'https://mysite.atlassian.net' && grep -qF "$core/jira.env" "$core/show.host.reapplied"
    ok "a host that was set stands across a pack applied again, so the placeholder does not come back for it" $?
    sed "s|^base: .*|base: $site/ex/jira/$cloud|" "$here/jira.yaml" >"$core/mine/jira.local.yaml"
    yrun source add "$core/mine/jira.local.yaml" >/dev/null 2>&1
    yrun source show jira >"$core/show.host.copy" 2>&1
    sed -n 1p "$core/show.host.copy" | grep -qF 'https://mysite.atlassian.net'
    ok "a host that was set stands over the address of a copy added after it" $?
    yrun source set jira host= >/dev/null 2>&1
    yrun source show jira >"$core/show.host.cleared" 2>&1
    sed -n 1p "$core/show.host.cleared" | grep -qF "$site/ex/jira/$cloud" && ! grep -qF 'mysite.atlassian.net' "$core/show.host.cleared"
    ok "host= with nothing after it clears the host, and the copy's own address is in use" $?

    # The site the path template makes, which is how SETUP.md step 2 points a
    # token with scopes at the gateway: a setting of the source as the host is,
    # and shown, kept and given up as the host is. The cloud id is the one
    # SETUP.md gives as its example, so that the example is held to what the
    # template makes of it. No call goes through it here either: the call of
    # the gateway is the one above, through a copy aimed at the stand-in.
    yardcloud=f84cdad3-1764-4e23-a125-a6259e2fcb7a
    gateway=https://api.atlassian.com/ex/jira/$yardcloud
    yrun source set jira site=$yardcloud >"$core/site.set.out" 2>&1
    yrun source show jira >"$core/show.site" 2>&1
    sed -n 1p "$core/show.site" | grep -qF "$gateway (site $yardcloud)"
    ok "source set site= makes the gateway's address with the cloud id in it, which source show names first" $? "$(tail -c 300 "$core/site.set.out")"
    grep -qF "yardr source set jira site=$yardcloud" SETUP.md && grep -qF "$gateway" SETUP.md
    ok "SETUP.md's example is that cloud id and the address the template makes of it" $?
    yrun pack apply "$here" --yes >/dev/null 2>&1
    yrun source show jira >"$core/show.site.reapplied" 2>&1
    sed -n 1p "$core/show.site.reapplied" | grep -qF "$gateway (site $yardcloud)" && grep -qF "$core/jira.env" "$core/show.site.reapplied"
    ok "a site that was set stands across a pack applied again, so the placeholder does not come back for it" $?
    # The copy step 9 starts from is the declaration as it ships, its
    # placeholder as the base, and the setting stands over that.
    cp "$here/jira.yaml" "$core/mine/jira.local.yaml"
    yrun source add "$core/mine/jira.local.yaml" >/dev/null 2>&1
    yrun source show jira >"$core/show.site.copy" 2>&1
    sed -n 1p "$core/show.site.copy" | grep -qF "$gateway (site $yardcloud)"
    ok "a site that was set stands over the placeholder of a copy added after it, as step 9's copy is" $?
    # One address is in use (SETUP.md step 2): a host given after a site takes
    # its place, and a site given after a host takes it back.
    yrun source set jira host=mysite.atlassian.net >/dev/null 2>&1
    yrun source show jira >"$core/show.site.host" 2>&1
    sed -n 1p "$core/show.site.host" | grep -qF 'https://mysite.atlassian.net' && ! grep -qF "$gateway" "$core/show.site.host"
    ok "a host given after a site takes its place" $?
    yrun source set jira site=$yardcloud >/dev/null 2>&1
    yrun source show jira >"$core/show.site.again" 2>&1
    sed -n 1p "$core/show.site.again" | grep -qF "$gateway (site $yardcloud)" && ! grep -qF 'mysite.atlassian.net' "$core/show.site.again"
    ok "a site given after a host takes its place" $?
    yrun source set jira site= >/dev/null 2>&1
    yrun source show jira >"$core/show.site.cleared" 2>&1
    sed -n 1p "$core/show.site.cleared" | grep -qF 'https://example.atlassian.net' && ! grep -qF "$gateway" "$core/show.site.cleared"
    ok "site= with nothing after it clears the site, and the copy's own address is in use" $?

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
