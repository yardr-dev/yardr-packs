# The core part of the sentry test, sourced by ./test: the declaration as the
# yard reads it, deliveries made to the yard's own listener (signed as Sentry
# signs them, and not), the links a bead makes to an issue, the stage map, and
# the check call and the thread commands made through the real yardr against a
# stand-in on a loopback port (testdata/standin.py). Everything runs in a
# scratch yard under a short path (a unix socket's path is held to 100 bytes)
# with its own home and an environment of nothing but PATH. No daemon is
# started, so no agent is, and the only listeners are the yard's own hook
# listener, on 127.0.0.1 and a port found free here (yardr takes no port 0),
# and the stand-in's, on a port the system chooses.
#
# ./test has set $YARDR, $here, $tmp, $token, check, ok and cleanup (which
# stops the stand-in by its pid, stops the scratch yard's server, and removes
# the scratch yard, whatever core is by then).
core=$(mktemp -d /tmp/sentryt.XXXXXX)
mkdir -p "$core/h"
#
# The zone is UTC, so that the times thread show prints are the same on every
# machine.
yrun() { env -i HOME="$core/h" PATH="$PATH" TZ=UTC "$YARDR" --home "$core/y" --actor tester "$@"; }
# yrunc is yrun with the token in the command's environment, as an agent's
# pane has it: the thread commands are made from the process that runs them.
yrunc() { env -i HOME="$core/h" PATH="$PATH" TZ=UTC SENTRY_TOKEN="$token" "$YARDR" --home "$core/y" --actor tester "$@"; }
# The integration's client secret, which no file of the run may hold but the
# one the hook names.
secret=signing_canary_7c1d5e9f3a2b4c6d8e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d

# sign <secret>: Sentry's documented signature of the body on stdin, the hex
# HMAC-SHA256 of its exact bytes under the secret (docs.sentry.io, Webhooks,
# Verifying the Signature).
sign() {
  SECRET=$1 python3 -I -c 'import hashlib, hmac, os, sys; print(hmac.new(os.environ["SECRET"].encode("utf-8"), sys.stdin.buffer.read(), hashlib.sha256).hexdigest())'
}

# deliver <resource> <request id> <timestamp> <signature, or none> <body file>:
# the request Sentry makes to the hook, its status in $code and its answer in
# $core/out.
deliver() {
  if [ "$4" = none ]; then
    code=$(curl -s -o "$core/out" -w '%{http_code}' -X POST "http://127.0.0.1:$hp/hooks/sentry" \
      -H "Request-ID: $2" -H "Sentry-Hook-Resource: $1" -H "Sentry-Hook-Timestamp: $3" \
      -H 'Content-Type: application/json' --data-binary @"$5")
  else
    code=$(curl -s -o "$core/out" -w '%{http_code}' -X POST "http://127.0.0.1:$hp/hooks/sentry" \
      -H "Sentry-Hook-Signature: $4" -H "Request-ID: $2" -H "Sentry-Hook-Resource: $1" -H "Sentry-Hook-Timestamp: $3" \
      -H 'Content-Type: application/json' --data-binary @"$5")
  fi
}

# listen: the yard's server takes webhooks on a free loopback port. yardr
# refuses port 0, so a free port is found first, which something else could
# take before the server does: then another is tried.
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

# hookevents: the hook events the yard has, as JSON.
hookevents() { yrun events --kind hook --json -n 1000; }

if ! yrun init --harness claude --operator tester >"$core/init.out" 2>&1; then
  echo "test: core FAILED: the scratch yard could not be made: $(tail -c 300 "$core/init.out")"
  fail=1
elif ! yrun pack apply "$here" --yes >"$core/apply.out" 2>&1; then
  echo "test: core FAILED: the pack did not apply from its directory: $(tail -c 300 "$core/apply.out")"
  fail=1
else
  # -- the declaration as the yard reads it
  yrun source show sentry --json | jq -S .declaration >"$core/declaration.json"
  check "declaration as the yard reads it (hook, thread, link, calls)" "$core/declaration.json" testdata/declaration.golden
  jq -e '.base == "https://sentry.io/api/0" and .check == "scopes" and .credential.env == "SENTRY_TOKEN"
         and (.calls | map(.name) == ["scopes"]) and ([.calls[] | .kind == "read" and .request.method == "GET"] | all)
         and .hook.verify.scheme == "hmac-sha256" and .hook.verify.signed == "body"
         and .hook.verify.signature == {header: "Sentry-Hook-Signature", encoding: "hex"}
         and .hook.verify.delivery == {header: "Request-ID"} and (.hook.verify | has("timestamp") | not)
         and .hook.bodies == "unique-per-hook" and .hook.untimed == true
         and .thread.states == ["started", "done"] and (.thread | has("open") | not) and (has("hear") | not)
         and .link.host == "sentry.io"' "$core/declaration.json" >/dev/null
  ok "the shipped base is sentry.io, the one call is a GET, the signature is Sentry's (body, hex, no timestamp), and the thread has no open" $?

  # -- a delivery to the yard's own listener, signed as Sentry signs it
  umask 077
  printf '%s' "$secret" >"$core/secret"
  umask 022
  yrun hook add sentry --source sentry --secret-file "$core/secret" >"$core/hook.out" 2>&1
  ok "the hook is added for the source the pack declares" $? "$(tail -c 300 "$core/hook.out")"
  if ! listen; then
    echo "test: core FAILED: the yard's server did not take webhooks on a free loopback port"
    fail=1
  else
    jq -c .body testdata/hook/issue-created.json >"$core/created.body"
    sig=$(sign "$secret" <"$core/created.body")
    rid=5d1e0c3f9b7a4c26a8e3f1b2d4c6a790
    deliver issue "$rid" 1762807380 "$sig" "$core/created.body"
    [ "$code" = 200 ] && jq -e 'has("seq") and (has("duplicate") | not)' "$core/out" >/dev/null
    ok "a delivery signed as Sentry signs it is taken" $? "status $code: $(head -c 200 "$core/out")"
    seq=$(jq -r .seq "$core/out")

    # A duplicate is answered 200, with the seq of the first, and leaves no
    # event.
    deliver issue "$rid" 1762807380 "$sig" "$core/created.body"
    [ "$code" = 200 ] && jq -e --argjson s "$seq" '.duplicate == true and .seq == $s' "$core/out" >/dev/null
    ok "the same delivery again is answered 200 as the first's duplicate (told by the Request-ID)" $? "status $code: $(head -c 200 "$core/out")"
    # Sentry makes a new Request-ID and a new timestamp for a retry, and
    # repeats the body: the body tells it.
    deliver issue 0123456789abcdef0123456789abcdef 1762807999 "$sig" "$core/created.body"
    [ "$code" = 200 ] && jq -e --argjson s "$seq" '.duplicate == true and .seq == $s' "$core/out" >/dev/null
    ok "a retry with a new Request-ID and timestamp and the same body is answered 200 as a duplicate (told by the body)" $? "status $code: $(head -c 200 "$core/out")"

    # Refused: each is answered 401 and left no event (the count below).
    { cat "$core/created.body"; printf x; } >"$core/tampered.body"
    deliver issue aaaaaaaaaaaa4c26a8e3f1b2d4c6a790 1762807380 "$sig" "$core/tampered.body"
    [ "$code" = 401 ]
    ok "a body that was changed after it was signed is refused with 401" $? "status $code"
    sigw=$(sign "another-secret-entirely" <"$core/created.body")
    deliver issue bbbbbbbbbbbb4c26a8e3f1b2d4c6a790 1762807380 "$sigw" "$core/created.body"
    [ "$code" = 401 ]
    ok "a body signed with another secret is refused with 401" $? "status $code"
    deliver issue cccccccccccc4c26a8e3f1b2d4c6a790 1762807380 none "$core/created.body"
    [ "$code" = 401 ]
    ok "a body with no signature is refused with 401" $? "status $code"
    # Sentry signs the exact bytes: the same JSON laid out another way is
    # another body.
    jq . "$core/created.body" >"$core/pretty.body"
    deliver issue dddddddddddd4c26a8e3f1b2d4c6a790 1762807380 "$sig" "$core/pretty.body"
    [ "$code" = 401 ]
    ok "the same JSON laid out another way, under the signature of the bytes first sent, is refused with 401" $? "status $code"

    jq -c .body testdata/hook/event-alert.json >"$core/alert.body"
    sig2=$(sign "$secret" <"$core/alert.body")
    deliver event_alert c0a7d2e94b1f4a85960e3d7b5f1a2c48 1762807502 "$sig2" "$core/alert.body"
    [ "$code" = 200 ]
    ok "an alert rule's event signed as Sentry signs it is taken" $? "status $code: $(head -c 200 "$core/out")"
    aseq=$(jq -r .seq "$core/out")

    # The yard's own resolve comes back as an issue delivery of action
    # resolved, by the integration. Its timestamp is Sentry's unsigned
    # header, which nothing here reads.
    jq -c .body testdata/hook/issue-resolved.json >"$core/resolved.body"
    sig3=$(sign "$secret" <"$core/resolved.body")
    deliver issue f3e1b5a7c9d24680a1b2c3d4e5f60718 1 "$sig3" "$core/resolved.body"
    [ "$code" = 200 ]
    ok "an issue resolved, with a timestamp from 1970, is taken: the timestamp is not signed and not read" $? "status $code"
    rseq=$(jq -r .seq "$core/out")

    # What the yard recorded, in one look: the three deliveries taken, and
    # no duplicate and no refused one.
    hookevents >"$core/hookevents.json"
    jq -e 'map(.data.type) == ["issue", "event_alert", "issue"]' "$core/hookevents.json" >/dev/null
    ok "the yard recorded the three deliveries taken, and no duplicate and no refused one" $? "$(jq -c 'map([.seq, .data.type, .data.action])' "$core/hookevents.json")"
    for pair in "$seq:issue-created" "$aseq:event-alert"; do
      s=${pair%%:*}
      f=${pair#*:}
      jq -S --argjson s "$s" '.[] | select(.seq == $s) | .data | del(.delivery, .hook, .deliveries, .new_mentions)' "$core/hookevents.json" >"$core/event.json"
      jq -S . "testdata/hook/$f.golden" >"$core/golden.json"
      cmp -s "$core/event.json" "$core/golden.json"
      ok "the event the yard records for $f is the envelope normalize printed" $? "$(diff "$core/golden.json" "$core/event.json" | head -6)"
    done
    [ "$(jq -r --argjson s "$seq" '.[] | select(.seq == $s) | .data.delivery' "$core/hookevents.json")" = "$rid" ]
    ok "the delivery's id is Sentry's Request-ID" $?
    jq -e --argjson s "$rseq" '.[] | select(.seq == $s) | .data | .action == "resolved" and .thread == {} and (has("text") | not)' "$core/hookevents.json" >/dev/null
    ok "the yard's own resolve coming back is recorded with no thread, so it is never a new issue" $?

    yrun hook list >"$core/hooklist.out" 2>&1
    grep -q ' ok ' "$core/hooklist.out" && grep -q 'unauthorized' "$core/hooklist.out"
    ok "hook list shows the hook ok, with the refusals as unauthorized" $? "$(tail -c 300 "$core/hooklist.out")"
  fi

  # -- a bead names the issue: by a typed address, and by the delivery that
  # heard it
  # One bead takes a relates link for each address, which keeps the one fixed
  # form as a tracks link does and allows any number of them; what link add
  # prints names it.
  nl=0
  lbead=$(yrun bead create "the addresses people type" --json 2>/dev/null | jq -r .id)
  while IFS='	' read -r url want <&3; do
    case $url in '' | '#'*) continue ;; esac
    nl=$((nl + 1))
    if yrun link add "$lbead" "$url" --relates >"$core/link.out" 2>&1; then
      got=$(sed -n 's/^.* -relates-> \(.*\) (sentry)$/\1/p' "$core/link.out")
    else
      got=-
    fi
    if [ "$got" = "$want" ]; then
      echo "test: link $url ok"
    else
      echo "test: link $url: got '$got', want '$want': $(tail -c 200 "$core/link.out")"
      fail=1
    fi
  done 3<testdata/link.txt
  seq=${seq:-0}
  bead=$(yrun bead create "tracks the heard issue" --json 2>/dev/null | jq -r .id)
  yrun link add "$bead" "$seq" >"$core/link.out" 2>&1
  [ "$(yrun link list "$bead" --json | jq -r '.[0].url + " " + .[0].source')" = "https://sentry.io/organizations/example-org/issues/1234567890 sentry" ]
  ok "a bead is linked to the issue a delivery names, by the delivery's number" $? "$(tail -c 200 "$core/link.out")"
  bead2=$(yrun bead create "a second tracker" --json 2>/dev/null | jq -r .id)
  yrun link add "$bead2" https://sentry.io/organizations/Example-Org/issues/1234567890/ >"$core/dup.out" 2>&1
  [ $? != 0 ] && grep -q "$bead" "$core/dup.out"
  ok "the same issue typed in another case has the one tracker, which the refusal names" $? "$(tail -c 200 "$core/dup.out")"
  aseq=${aseq:-0}
  bead3=$(yrun bead create "made to track an alert's issue" --tracks "$aseq" --json 2>/dev/null | jq -r .id)
  [ "$(yrun link list "$bead3" --json | jq -r '.[0].url')" = "https://sentry.io/organizations/test-org/issues/1117540176" ]
  ok "a bead made with --tracks of an alert's delivery tracks that alert's issue" $?

  # -- the commands SETUP.md teaches that the yard can run at once, run as
  # written, in the order it gives them: the hook, the crew member's identity
  # and grant, the subscriptions with the keys they filter by, and the hook
  # again with the map that resolves an issue when its bead lands. They are
  # read out of SETUP.md and not copied here: a copy would pass whatever SETUP
  # teaches. A command that ends in a backslash goes on in the next line, and
  # <name> is the crew member the yard starts with. An address typed in a
  # step is its own.
  awk '{ line = $0; sub(/^ +/, "", line)
         buf = cont ? buf " " line : line
         if (buf ~ /\\$/) { sub(/ *\\$/, "", buf); cont = 1; next }
         cont = 0
         if (buf ~ /^yardr (hook add sentry |subscribe |crew identity |crew set <name> set_state=)/) print buf
         buf = "" }' SETUP.md | sed -e 's/^yardr //' -e 's/<name>/yardmaster/g' -e 's/<integration name>/yardr/g' -e "s|~/.yardr/sentry.secret|$core/secret|g" >"$core/taught"
  if [ "$(wc -l <"$core/taught")" -lt 6 ]; then
    echo "test: SETUP.md teaches fewer commands than the test looks for: $(tr '\n' '|' <"$core/taught")"
    fail=1
  fi
  while IFS= read -r cmd <&4; do
    # The words are plain, so $cmd is split on purpose, and its stdin is
    # /dev/null so that it cannot read the rest of the list.
    # shellcheck disable=SC2086
    if yrun $cmd </dev/null >"$core/out" 2>&1; then
      echo "test: SETUP.md: yardr $cmd ok"
    else
      echo "test: SETUP.md: yardr refused 'yardr $cmd', which SETUP.md teaches: $(tail -c 300 "$core/out")"
      fail=1
    fi
  done 4<"$core/taught"

  # -- the stage map: a bead that lands resolves its issue
  yrun hook add sentry --source sentry --secret-file "$core/secret" --as yardmaster --map task:new=started --map task:merged=done >"$core/map.out" 2>&1
  grep -q 'moves tracked sentry issues as yardmaster: task:merged=done task:new=started' "$core/map.out"
  ok "the hook takes a stage map: merged is done (resolved) and new is started (unresolved)" $? "$(tail -c 300 "$core/map.out")"
  yrun hook add sentry --source sentry --secret-file "$core/secret" --as yardmaster --map task:review=review >"$core/map2.out" 2>&1
  [ $? != 0 ]
  ok "a map to review is refused: Sentry has no such status" $? "$(tail -c 300 "$core/map2.out")"

  # -- the check call and the thread commands, through the real yardr. The
  # operator's copy is the declaration with its base replaced, as SETUP.md's
  # last step makes one for another Sentry; here the Sentry is the stand-in.
  sd=$core/sd
  mkdir -p "$sd" "$core/mine"
  python3 -I testdata/standin.py "$sd" 2>"$core/standin.err" <<EOF &
$token
EOF
  standin_pid=$!
  i=0
  while [ ! -s "$sd/port" ] && [ "$i" -lt 200 ]; do sleep 0.05; i=$((i + 1)); done
  if [ ! -s "$sd/port" ]; then
    echo "test: core FAILED: the stand-in did not listen: $(cat "$core/standin.err")"
    fail=1
  else
    port=$(cat "$sd/port")
    cp -R "$here/sentry" "$core/mine/"
    sed "s|^base: .*|base: http://127.0.0.1:$port/api/0|" "$here/sentry.yaml" >"$core/mine/sentry.yaml"
    # The credential is given as SETUP.md gives it: yardr source key, here
    # with the line on its standard input, which the server writes into the
    # source's env file.
    yrun source add "$core/mine/sentry.yaml" >"$core/add.out" 2>&1 \
      && printf 'SENTRY_TOKEN=%s\n' "$token" | yrun source key sentry >>"$core/add.out" 2>&1
    ok "the operator's copy is added and its credential given by source key" $? "$(tail -c 300 "$core/add.out")"

    # against <name> <case dir> <command...>: one command of the yard, with
    # the stand-in answering as the case does; its words, its status and the
    # requests the stand-in saw are the golden testdata/core/<name>.golden.
    # The stand-in's port, the scratch yard's path, a call's milliseconds and
    # a reply's key are masked.
    against() {
      name=$1
      cdir=$2
      shift 2
      printf '%s\n' "$cdir" >"$sd/case"
      rm -f "$sd/n"
      : >"$sd/requests"
      "$@" >"$core/cli.out" 2>&1
      cli_status=$?
      {
        echo "--- output"
        cat "$core/cli.out"
        echo "--- status"
        echo "$cli_status"
        echo "--- requests"
        cat "$sd/requests"
      } | sed -e "s|127.0.0.1:$port|<stand-in>|g" -e "s|$core|<yard>|g" -e 's/ in [0-9][0-9]*ms/ in <n>ms/g' -e 's/yardr-reply [0-9a-f-]\{36\}/yardr-reply <key>/g' >"$core/$name.got"
      check "core $name" "$core/$name.got" "testdata/core/$name.golden"
    }

    against check "$here/testdata/core/check" yrun source check sentry
    grep -q 'event:write' "$core/cli.out" && ! grep -q 'hidden@example.com' "$core/cli.out"
    ok "source check shows the scopes of the token, and nothing else of the answer" $?
    against check-refused "$here/testdata/core/check-refused" yrun source check sentry
    [ "$cli_status" != 0 ]
    ok "source check fails on a token Sentry does not take" $?

    # The status of an issue: the crew member takes part in its thread, and
    # may set a status in sentry, which only the operator grants.
    yrun crew set yardmaster set_state=sentry >/dev/null 2>&1
    yrun thread follow yardmaster --source sentry 'example-org#1234567890' >/dev/null 2>&1
    against state "$here/testdata/core/state" yrunc thread state "$seq" done --crew yardmaster
    [ "$cli_status" = 0 ] && grep -q 'is now resolved (was unresolved)' "$core/cli.out"
    ok "thread state done by the delivery's number resolves the issue" $?
    yrun events --kind thread_state --json | jq -e '.[-1].data | .state == "done" and .status == "resolved" and .was == "unresolved" and .thread == "example-org#1234567890"' >/dev/null
    ok "and the yard logs it as a thread_state event" $?

    against reply "$here/testdata/core/reply" yrunc reply "$seq" "Fix landed in 4d2c1ab." --crew yardmaster
    [ "$cli_status" = 0 ]
    ok "a reply is posted as a comment" $?
    # A reply whose answer was lost: the first try fails, and the same reply
    # again finds the comment its key left and posts nothing.
    mkdir -p "$core/lost" "$core/found"
    printf '500\n{"detail":"the stand-in broke"}\n' >"$core/lost/answer_1"
    against reply-lost "$core/lost" yrunc reply "$seq" "A reply that landed and was lost." --crew yardmaster
    [ "$cli_status" != 0 ]
    ok "a reply Sentry answers 500 is no success" $?
    key=$(sed -n 's/.*yardr-reply \([0-9a-f-]\{36\}\).*/\1/p' "$sd/requests" | head -n 1)
    printf '200\n[{"id":"7060","commentId":"7060","user":null,"sentry_app":null,"type":"note","data":{"text":"A reply that landed and was lost.\\n\\n<!-- yardr-reply %s -->"},"dateCreated":"2026-11-07T10:30:00Z"}]\n' "$key" >"$core/found/answer_1"
    against reply-found "$core/found" yrunc reply "$seq" "A reply that landed and was lost." --crew yardmaster
    [ "$cli_status" = 0 ] && [ "$(grep -c '^POST ' "$sd/requests")" = 0 ] && [ "$(grep -c '^GET ' "$sd/requests")" = 1 ]
    ok "the same reply again finds the comment its key left, and posts nothing" $?

    against show "$here/testdata/core/show" yrunc thread show "$seq"
    [ "$cli_status" = 0 ]
    ok "thread show reads the comments of the issue" $?

    # -- the token is where the yard keeps it and nowhere else, and so is
    # the signing secret
    kill "$standin_pid" 2>/dev/null
    standin_pid=
    leaks=$(grep -rlF -e "$token" "$core" 2>/dev/null | grep -v -e "^$core/y/sources/sentry.env\$" | head -5)
    [ -z "$leaks" ]
    ok "the token is in no file of the run but the source's env file (the stand-in's goldens and the thread commands' output hold none)" $? "found in: $leaks"
    grep -qF "$token" "$core/y/sources/sentry.env"
    ok "(and that env file does hold the token, so the search above looked at something)" $?
    leaks=$(grep -rlF -e "$secret" "$core" 2>/dev/null | grep -v -e "^$core/secret\$" | head -5)
    [ -z "$leaks" ]
    ok "the signing secret is in no file of the run but the one the hook names" $? "found in: $leaks"
    ! yrun events --json | grep -qF -e "$secret" -e "$token"
    ok "neither is in any event the yard logged" $?
  fi
fi
[ -z "${standin_pid:-}" ] || { kill "$standin_pid" 2>/dev/null; standin_pid=; }
