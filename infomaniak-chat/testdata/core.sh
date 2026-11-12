# The core part of the infomaniak-chat test, sourced by ./test: the
# declaration as the yard reads it, the presets and the grants SETUP.md
# teaches, the check and the calls against a stand-in on a loopback
# port (testdata/standin.py), and deliveries to the yard's own hook
# listener, one heard with the webhook's token and two refused without
# it, then yardr reply and thread show in the heard thread. Everything
# runs in a scratch yard under a short path (a unix socket's path is
# held to 100 bytes) with its own home and an environment of nothing
# but PATH: none of this session's YARDR_* variables lead back to a
# real yard. No daemon is started, so no agent is, and the only
# listeners are the stand-in's and the yard's own hook listener, each
# on 127.0.0.1 and a port the system chooses (the yard takes no port 0,
# so a free one is found first, as in sentry's test).
#
# ./test has set $YARDR, $here, $tmp, $token (the bot token), $wtoken
# (the webhook's token), $site, check, ok, set_routes, split_case and
# cleanup. Both tokens are made there for the run and thrown away.
# shellcheck disable=SC2154
core=$(mktemp -d /tmp/ikchat.XXXXXX) || { core=; echo "test: core FAILED: no temp directory under /tmp for the scratch yard"; exit 1; }
mkdir -p "$core/h"
# The zone is UTC, so that the times thread show prints are the same
# on every machine.
yrun() {
  env -i HOME="$core/h" PATH="$core/bin:$PATH" TZ=UTC \
    "$YARDR" --home "$core/y" --actor tester "$@"
}
# yrunc is yrun with the bot token in the command's environment, as an
# agent's pane has it: the thread commands are made from the process
# that runs them.
real_curl=$(command -v curl)
real_jq=$(command -v jq)
mkdir -p "$core/bin"
cat >"$core/bin/curl" <<SH
#!/bin/sh
printf '%s\n' "\$@" >>"$core/subprocess.args"
exec "$real_curl" "\$@"
SH
cat >"$core/bin/jq" <<SH
#!/bin/sh
printf '%s\n' "\$@" >>"$core/subprocess.args"
exec "$real_jq" "\$@"
SH
chmod +x "$core/bin/curl" "$core/bin/jq"
yrunc() {
  env -i HOME="$core/h" PATH="$core/bin:$PATH" TZ=UTC \
    YARDR_CREW=yardmaster INFOMANIAK_CHAT_TOKEN="$token" \
    "$YARDR" --home "$core/y" --actor tester "$@"
}

CHAN=chan0000000000000000000001
ROOT=post0000000000000000000001
ADA=user0000000000000000000001
BOB=user0000000000000000000002

# golden_of <dir> <status>: a case's golden from the stand-in's log
# and the files the run left in the dir.
golden_of() {
  echo "--- requests"
  cat "$tmp/requests"
  echo "--- status"
  echo "$2"
  echo "--- stdout"
  if [ -s "$1/stdout" ]; then jq -S . "$1/stdout" 2>/dev/null || cat "$1/stdout"; fi
  echo "--- stderr"
  cat "$1/stderr"
}

# listen: the yard's server takes webhooks on a free loopback port.
listen() {
  tries=0
  while [ "$tries" -lt 5 ]; do
    hp=$(python3 -I -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
    yrun settings set hook_addr "127.0.0.1:$hp" >/dev/null 2>&1
    yrun server stop >/dev/null 2>&1
    yrun events -n 1 >/dev/null 2>&1 # a command that asks the server starts it, on the address
    i=0
    while [ "$i" -lt 40 ]; do
      [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$hp/hooks/none" 2>/dev/null)" != 000 ] && return 0
      sleep 0.1
      i=$((i + 1))
    done
    tries=$((tries + 1))
  done
  return 1
}
hookevents() { yrun events --kind hook --json -n 1000; }

if ! yrun init --harness claude --operator tester >"$core/init.out" 2>&1; then
  echo "test: core FAILED: the scratch yard could not be made: $(tail -c 300 "$core/init.out")"
  fail=1
elif ! yrun pack apply "$here" --yes >"$core/apply.out" 2>&1; then
  echo "test: core FAILED: the pack did not apply from its directory: $(tail -c 300 "$core/apply.out")"
  fail=1
else
  # -- the declaration as the yard reads it, with the shipped base
  yrun source show infomaniak-chat --json | jq -S .declaration >"$core/declaration.json"
  check "declaration as the yard reads it (base, credential, calls, hook, thread)" "$core/declaration.json" testdata/declaration.golden
  jq -e '.base == "https://example.kchat.infomaniak.com" and .check == "whoami"
         and .credential == {env: "INFOMANIAK_CHAT_TOKEN", header: "Authorization: Bearer {credential}"}
         and (has("idempotency") | not) and (has("notify") | not) and (has("link") | not)
         and ([.calls[] | select(.kind == "read") | .name] == ["whoami", "history", "thread"])
         and ([.calls[] | select(.kind == "update") | .name] == ["post"])
         and .hook.verify.scheme == "secret" and .hook.verify.signature.body == "token" and .hook.verify.delivery.body == "post_id"
         and .hook.bodies == "unique" and .hook.untimed == true and .hook.keys == ["channel", "team", "sender", "trigger"]
         and .hear.field == "sender" and .hear.by == "identity"
         and (.thread | keys == ["posted", "read", "reply"])' "$core/declaration.json" >/dev/null
  ok "the shipped base is the placeholder, the token is one Bearer credential, three calls read and post is the one update, the hook verifies the body's token, hearing is by sender, and the thread has reply, posted and read alone" $?
  yrun pack show infomaniak-chat >"$core/packshow.out" 2>&1
  grep -q '1\. read: ' "$core/packshow.out" && grep -q '2\. post: ' "$core/packshow.out" &&
    awk '/1\. read: /{ r = 1; next } /2\. post: /{ r = 2; next } r == 1 && /infomaniak-chat:/ { read = $0 } r == 2 && /infomaniak-chat:/ { post = $0 }
         END { exit !(read ~ /infomaniak-chat: read$/ && post ~ /infomaniak-chat: read, post$/) }' "$core/packshow.out"
  ok "pack show prints the two presets, read granting read and post granting read and post" $?

  # -- SETUP.md says what each token is and where it is made
  grep -q 'INFOMANIAK_CHAT_TOKEN' SETUP.md && grep -q 'Bot accounts' SETUP.md && grep -q 'application/json' SETUP.md && grep -q 'scope.*kchat\|kchat.*scope' SETUP.md
  ok "SETUP.md names the variable, the bot accounts, the JSON pin and the manager token's kchat scope" $?

  # -- the grants SETUP.md teaches, run as written (read out of
  # SETUP.md, not copied here: a copy would pass whatever SETUP
  # teaches). The card of SETUP.md grants the group reviewers, which
  # a fresh yard has none of.
  grep -o 'source grant [^`"]*' SETUP.md >"$core/grants"
  if [ ! -s "$core/grants" ]; then
    echo "test: grant FAILED: SETUP.md teaches no source grant command"
    fail=1
  elif ! yrun group add reviewers --runner manual >"$core/out" 2>&1; then
    echo "test: grant FAILED: the group of the card could not be made: $(tail -c 300 "$core/out")"
    fail=1
  else
    while IFS= read -r cmd; do
      # A grant is plain words, so $cmd is split on purpose. Its stdin
      # is /dev/null so that it cannot read the rest of the list.
      # shellcheck disable=SC2086
      if yrun $cmd </dev/null >"$core/out" 2>&1; then
        echo "test: grant ok (yardr $cmd)"
      else
        echo "test: grant FAILED: yardr refused 'yardr $cmd', which SETUP.md teaches: $(tail -c 300 "$core/out")"
        fail=1
      fi
    done <"$core/grants"
    yrun source grants --json >"$core/grants.json" 2>&1
    jq -e 'length > 0
           and ([.[] | .kinds | to_entries[]] | all((.key == "read" and .value == "read") or (.key == "post" and .value == "update")))
           and ([.[] | .kinds | has("read")] | any) and ([.[] | .kinds | has("post")] | any)' "$core/grants.json" >/dev/null
    ok "SETUP.md's grants give read as read and post as an update, nothing else" $? "$(head -c 300 "$core/grants.json")"
  fi

  # -- the calls and the check, through the real yardr against the
  # stand-in. The operator's copy is the declaration with its base
  # replaced by the stand-in's, as SETUP.md replaces the team; the
  # programs it names are copied beside it, as the yard copies them.
  mkdir -p "$core/mine"
  cp -R "$here/infomaniak-chat" "$core/mine/"
  sed "s|^base: .*|base: $site|" "$here/infomaniak-chat.yaml" >"$core/mine/infomaniak-chat.yaml"
  yrun source add "$core/mine/infomaniak-chat.yaml" >"$core/add.out" 2>&1 \
    && printf 'INFOMANIAK_CHAT_TOKEN=%s\n' "$token" | yrun source key infomaniak-chat >>"$core/add.out" 2>&1 \
    && yrun source set infomaniak-chat calls_per_hour=1000 >>"$core/add.out" 2>&1 \
    && yrun source set infomaniak-chat updates_per_hour=1000 >>"$core/add.out" 2>&1
  ok "the operator's copy is added and the bot token given by source key" $? "$(tail -c 300 "$core/add.out")"

  # -- the check call: whoami, with the token as a Bearer credential
  printf '%s\n' "GET /api/v4/users/me 200 $here/testdata/answers/whoami.json" >"$tmp/routes"
  : >"$tmp/requests"
  yrun source check infomaniak-chat >"$core/check.out" 2>&1
  rc=$?
  [ "$rc" = 0 ] && grep -q 'check call whoami (GET /api/v4/users/me): 200' "$core/check.out" && grep -q 'yardrbot' "$core/check.out" && grep -q 'can be run' "$core/check.out"
  ok "source check makes the whoami call with the token, shows the bot and says the programs can be run" $? "exit $rc: $(tail -c 300 "$core/check.out")"
  check "the check call's request" "$tmp/requests" testdata/check.requests.golden

  # -- each call case
  for c in testdata/calls/*.case; do
    n=$(basename "$c" .case)
    d="$core/case_$n"
    mkdir "$d"
    split_case "$c" "$d"
    set_routes "$d/routes"
    : >"$tmp/requests"
    set --
    while IFS= read -r word; do set -- "$@" "$word"; done <"$d/args"
    yrun call infomaniak-chat "$@" --json >"$d/stdout" 2>"$d/stderr"
    status=$?
    golden_of "$d" "$status" >"$d/golden"
    check "call $n" "$d/golden" "testdata/calls/$n.golden"
  done

  # Of all the requests the cases made: each carried the token, and
  # each is one of the four routes the declaration names.
  cat "$core"/case_*/golden >"$core/all.golden"
  ! grep -qE 'auth: (missing|WRONG)' "$core/all.golden" testdata/check.requests.golden
  ok "every request carried the bot token as a bearer" $?
  cat testdata/check.requests.golden >>"$core/all.golden"
  ! grep -E '^[A-Z]+ ' "$core/all.golden" | grep -vE '^(GET /api/v4/users/me|POST /api/v4/posts|GET /api/v4/channels/[A-Za-z0-9_-]+/posts\?page=[0-9]+&per_page=[0-9]+|GET /api/v4/posts/[A-Za-z0-9_-]+/thread)$' | grep -q .
  ok "every request is one of the declaration's four routes, with history's page and limit in its query" $?
  grep -E '^  body: ' "$core/all.golden" | grep -q '"root_id":"post0000000000000000000001"'
  ok "a post with a root sends that thread's id in its body" $?

  # -- deliveries to the yard's own hook listener
  if ! yrun user add ada >"$core/user.out" 2>&1 || ! yrun user identity ada --source infomaniak-chat --id "$ADA" --key ada >>"$core/user.out" 2>&1; then
    echo "test: core FAILED: the speaker of the heard delivery could not be mapped: $(tail -c 300 "$core/user.out")"
    fail=1
  fi
  umask 077 && printf '%s' "$wtoken" >"$core/wsecret" && umask 022
  yrun hook add infomaniak-chat --source infomaniak-chat --secret-file "$core/wsecret" --unknown unknown >"$core/hook.out" 2>&1
  ok "the hook is added for the source the pack declares, with SETUP.md's unknown word" $? "$(tail -c 300 "$core/hook.out")"
  if ! listen; then
    echo "test: core FAILED: the yard's server did not take webhooks on a free loopback port"
    fail=1
  else
    deliver() { # <body file>: the status in $code, the answer in $core/out
      code=$(curl -s -o "$core/out" -w '%{http_code}' -X POST "http://127.0.0.1:$hp/hooks/infomaniak-chat" \
        -H 'Content-Type: application/json' --data-binary @"$1")
    }
    jq -c --arg t "$wtoken" '.body.token = $t | .body' testdata/hook/message.json >"$core/good.body"
    jq -c '.body.token = "a-wrong-token-entirely" | .body' testdata/hook/message.json >"$core/wrong.body"
    jq -c 'del(.body.token) | .body' testdata/hook/message.json >"$core/none.body"
    jq -c --arg t "$wtoken" --arg u "$BOB" '.body.token = $t | .body.user_id = $u | .body.user_name = "bob" | .body.post_id = "post0000000000000000000099" | .body' testdata/hook/message.json >"$core/bob.body"

    deliver "$core/wrong.body"
    [ "$code" = 401 ]
    ok "a delivery with a wrong webhook token is refused with 401" $? "status $code"
    deliver "$core/none.body"
    [ "$code" = 401 ]
    ok "a delivery with no webhook token is refused with 401" $? "status $code"
    deliver "$core/good.body"
    [ "$code" = 200 ] && jq -e 'has("seq") and (has("duplicate") | not)' "$core/out" >/dev/null
    ok "a delivery with the webhook's token is taken" $? "status $code: $(head -c 200 "$core/out")"
    seq=$(jq -r .seq "$core/out")

    deliver "$core/good.body"
    [ "$code" = 200 ] && jq -e --argjson s "$seq" '.duplicate == true and .seq == $s' "$core/out" >/dev/null
    ok "the same delivery again is answered 200 as the first's duplicate (told by its post_id)" $? "status $code: $(head -c 200 "$core/out")"
    deliver "$core/bob.body"
    bobcode=$code
    hookevents >"$core/hookevents.json"
    jq -e 'map(.data.type) == ["message"]' "$core/hookevents.json" >/dev/null
    ok "the yard recorded the one heard delivery: no refused one, no duplicate, and the unmapped speaker held by the hook's unknown word (status $bobcode)" $? "$(jq -c 'map([.seq, .data.type])' "$core/hookevents.json")"
    jq -S --argjson s "$seq" '.[] | select(.seq == $s) | .data | del(.delivery, .hook, .deliveries, .new_mentions)' "$core/hookevents.json" >"$core/event.json"
    jq -S '.fields.speaker = ["ada"]' testdata/hook/message.golden >"$core/golden.json"
    cmp -s "$core/event.json" "$core/golden.json"
    ok "the event the yard records is the envelope normalize printed, with ada as its speaker" $? "$(diff "$core/golden.json" "$core/event.json" | head -6)"

    # The stored body holds no token: the field was removed before
    # the body was kept, as hook show prints it.
    yrun hook show "$seq" >"$core/show.out" 2>&1
    ! grep -qF "$wtoken" "$core/show.out" && ! grep -q '"token"' "$core/show.out"
    ok "the delivery the yard kept holds no token field and no token value" $?

    # -- answering in the heard thread, and reading it back
    printf '%s\n' "POST /api/v4/posts 201 $here/testdata/answers/thread-reply.json" "GET /api/v4/posts/$ROOT/thread 200 $here/testdata/answers/thread-after.json" >"$tmp/routes"
    : >"$tmp/requests"
    reply_text='Noted; Monday it is.'
    : >"$core/subprocess.args"
    printf '%s' "$reply_text" | yrunc reply "$seq" - >"$core/reply.out" 2>"$core/reply.err"
    rc=$?
    # The typed reply reaches the named thread in the request body, not
    # jq's or curl's process arguments, where other local users can read it.
    [ "$rc" = 0 ] && grep -q '"channel_id":"chan0000000000000000000001","message":"Noted; Monday it is.","root_id":"post0000000000000000000001"' "$tmp/requests" \
      && ! grep -Fq "$reply_text" "$core/subprocess.args" \
      && ! grep -qE 'auth: (missing|WRONG)' "$tmp/requests"
    ok "yardr reply posts into the heard thread with the bot token, keeping the typed reply out of jq and curl arguments" $? "exit $rc: $(cat "$tmp/requests" "$core/reply.err" | head -c 400)"
    yrunc thread show "$seq" >"$core/showthread.out" 2>"$core/showthread.err"
    rc=$?
    [ "$rc" = 0 ]
    ok "yardr thread show reads the heard thread back" $? "exit $rc: $(head -c 300 "$core/showthread.err")"
    check "thread show prints the thread oldest first, the reply among it" "$core/showthread.out" testdata/thread-show.golden
  fi

  # -- the tokens are in the files that hold them, and nowhere else
  envfile=$core/y/sources/infomaniak-chat.env
  grep -qF "$token" "$envfile"
  ok "the env file holds the bot token" $?
  leaks=$(grep -rlF -e "$token" "$core/y" "$core/h" 2>/dev/null | grep -vxF "$envfile")
  [ -z "$leaks" ]
  ok "the bot token is in no file of the yard but its env file" $? "found in: $leaks"
  ! grep -qF -e "$token" -e "$wtoken" "$core/check.out" "$core/add.out" "$core/all.golden" "$core/hookevents.json" "$core/reply.out" 2>/dev/null
  ok "neither token is in an output of the yard's commands" $?
  ! grep -qF "$wtoken" "$core/hookevents.json"
  ok "the webhook's token is in no hook event" $?
fi
