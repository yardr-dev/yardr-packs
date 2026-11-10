# The core part of the infomaniak-calendar test, sourced by ./test: the
# declaration as the yard reads it, the presets and the grants SETUP.md
# teaches, the check call, and each testdata/calls/*.case made through the
# real yardr against the stand-in on a loopback port (testdata/standin.py).
# Everything runs in a scratch yard under a short path (a unix socket's path
# is held to 100 bytes) with its own home and an environment of nothing but
# PATH: none of this session's YARDR_* variables lead back to a real yard. No
# daemon is started, so no agent is, and the only listener is the stand-in's,
# on 127.0.0.1 and a port the system chooses.
#
# ./test has set $YARDR, $here, $tmp, $token, $site, check, ok, set_routes,
# golden_of and cleanup (which stops the stand-in by its pid, stops the
# scratch yard's server, and removes the scratch yard, whatever core is by
# then), and reads $fail after this file ends.
# shellcheck disable=SC2154,SC2034
core=$(mktemp -d /tmp/ikcalt.XXXXXX)
mkdir -p "$core/h"
yrun() { env -i HOME="$core/h" PATH="$PATH" "$YARDR" --home "$core/y" --actor tester "$@"; }

if ! yrun init --harness claude --operator tester >"$core/init.out" 2>&1; then
  echo "test: core FAILED: the scratch yard could not be made: $(tail -c 300 "$core/init.out")"
  fail=1
elif ! yrun pack apply "$here" --yes >"$core/apply.out" 2>&1; then
  echo "test: core FAILED: the pack did not apply from its directory: $(tail -c 300 "$core/apply.out")"
  fail=1
else
  # -- the declaration as the yard reads it, with the shipped base
  yrun source show infomaniak-calendar --json | jq -S .declaration >"$core/declaration.json"
  check "declaration as the yard reads it (base, credential, calls)" "$core/declaration.json" testdata/declaration.golden
  # The kinds are what keeps writing apart: read covers every read call and
  # no update, and create and edit are granted by their names. What the pack
  # never does is in the declaration as data: no delete, no attendees, and
  # the one body that creates names nobody and notifies nobody.
  jq -e '.base == "https://api.infomaniak.com" and .check == "calendars"
         and .credential == {env: "INFOMANIAK_CALENDAR_TOKEN", header: "Authorization: Bearer {credential}"}
         and (has("idempotency") | not) and (has("hook") | not) and (has("notify") | not) and (has("thread") | not) and (has("link") | not)
         and ([.calls[] | select(.kind == "read") | .name] == ["calendars", "events", "event"])
         and ([.calls[] | select(.kind == "update") | .name] == ["create", "edit"])
         and ([.calls[] | select(.kind == "read") | .request.method] | all(. == "GET"))
         and ([.calls[] | .request.method] | all(. == "GET" or . == "POST" or . == "PUT"))
         and ([.calls[] | .params[]? | .name] | all(. != "attendees" and . != "sendUpdates" and . != "notifyAttendees"))
         and ((.calls[] | select(.name == "create") | .request.body) | (.attendees == [] and .notifyAttendees == false and .fullday == false))
         and ((.calls[] | select(.name == "edit") | .build) == ["infomaniak-calendar/build-edit"])' "$core/declaration.json" >/dev/null
  ok "the shipped base is Infomaniak's, three reads, create and edit the two updates, nobody invited, no delete, no idempotency header, hook, notify, thread or link" $?
  yrun pack show infomaniak-calendar >"$core/packshow.out" 2>&1
  grep -q '1\. read: ' "$core/packshow.out" && grep -q '2\. create: ' "$core/packshow.out" && grep -q '3\. everything: ' "$core/packshow.out" &&
    awk '/1\. read: /{ r = 1; next } /2\. create: /{ r = 2; next } /3\. everything: /{ r = 3; next }
         r == 1 && /infomaniak-calendar:/ { one = $0 } r == 2 && /infomaniak-calendar:/ { two = $0 } r == 3 && /infomaniak-calendar:/ { three = $0 }
         END { exit !(one ~ /infomaniak-calendar: read$/ && two ~ /infomaniak-calendar: read, create$/ && three ~ /infomaniak-calendar: read, create, edit$/) }' "$core/packshow.out"
  ok "pack show prints the three presets: read, then create beside it, then edit too" $?

  grep -qF 'FAQ 2582' SETUP.md &&
    grep -qF 'https://manager.infomaniak.com/v3/ng/profile/user/token/list' SETUP.md
  ok "SETUP.md names the exact manager path linked by Infomaniak's FAQ" $?

  # -- the grants SETUP.md teaches, run as written. They are read out of
  # SETUP.md and not copied here: a copy would pass whatever SETUP teaches,
  # and --preset is refused for a pack applied from a directory, so SETUP.md
  # teaches each call by its name. The card of SETUP.md grants the group
  # reviewers, which a fresh yard has none of.
  grep -o 'source grant [^`"]*' SETUP.md >"$core/grants"
  if [ ! -s "$core/grants" ]; then
    echo "test: grant FAILED: SETUP.md teaches no source grant command"
    fail=1
  elif ! yrun group add reviewers --runner manual >"$core/out" 2>&1; then
    echo "test: grant FAILED: the group of the card could not be made: $(tail -c 300 "$core/out")"
    fail=1
  else
    while IFS= read -r cmd; do
      # A grant is plain words, so $cmd is split on purpose. Its stdin is
      # /dev/null so that it cannot read the rest of the list.
      # shellcheck disable=SC2086
      if yrun $cmd </dev/null >"$core/out" 2>&1; then
        echo "test: grant ok (yardr $cmd)"
      else
        echo "test: grant FAILED: yardr refused 'yardr $cmd', which SETUP.md teaches: $(tail -c 300 "$core/out")"
        fail=1
      fi
    done <"$core/grants"
    # What those grants gave: read as the word for the read calls, and
    # create and edit as updates, each by its name; nothing else was granted.
    yrun source grants --json >"$core/grants.json" 2>&1
    jq -e 'length > 0
           and ([.[] | .kinds | to_entries[]] | all((.key == "read" and .value == "read") or ((.key == "create" or .key == "edit") and .value == "update")))
           and ([.[] | .kinds | has("read")] | any) and ([.[] | .kinds | has("create")] | any) and ([.[] | .kinds | has("edit")] | any)' "$core/grants.json" >/dev/null
    ok "SETUP.md's grants give read as read, create and edit as updates, nothing else" $? "$(head -c 300 "$core/grants.json")"
  fi

  # -- the calls and the check, through the real yardr against the stand-in.
  # The operator's copy is the declaration with its base replaced, as a
  # person would set it; here the service is the stand-in, and the program
  # edit names is the pack's own, copied beside it as the yard copies it.
  mkdir -p "$core/mine"
  cp -R "$here/infomaniak-calendar" "$core/mine/"
  sed "s|^base: .*|base: $site|" "$here/infomaniak-calendar.yaml" >"$core/mine/infomaniak-calendar.yaml"
  # The token is given as SETUP.md gives it: yardr source key, with the name
  # on its standard input, which the server writes into the source's env
  # file. (Typed at a terminal it is asked unseen; a script gives NAME=value.)
  yrun source add "$core/mine/infomaniak-calendar.yaml" >"$core/add.out" 2>&1 \
    && printf 'INFOMANIAK_CALENDAR_TOKEN=%s\n' "$token" | yrun source key infomaniak-calendar >>"$core/add.out" 2>&1 \
    && yrun source set infomaniak-calendar calls_per_hour=1000 >>"$core/add.out" 2>&1 \
    && yrun source set infomaniak-calendar updates_per_hour=1000 >>"$core/add.out" 2>&1
  ok "the operator's copy is added and the token given by source key" $? "$(sed "s/$token/<TOKEN>/g" "$core/add.out" | tail -c 300)"

  # -- the check call, with the token the yard was given
  : >"$tmp/requests"
  set_routes /dev/null
  printf '%s\n' "GET /1/calendar/pim/calendar 200 $here/testdata/answers/calendars.json" >"$tmp/routes"
  yrun source check infomaniak-calendar >"$core/check.out" 2>&1
  rc=$?
  [ "$rc" = 0 ] && grep -q 'check call calendars (GET /1/calendar/pim/calendar): 200' "$core/check.out" && grep -q '"name":"Personal"' "$core/check.out" &&
    grep -q 'command call.edit.build (infomaniak-calendar/build-edit): can be run' "$core/check.out"
  ok "source check reaches the service with the token, shows the calendars, and finds edit's program" $? "exit $rc: $(sed "s/$token/<TOKEN>/g" "$core/check.out" | tail -c 300)"
  check "the check call's request" "$tmp/requests" testdata/check.requests.golden

  # Each case: args (the call and its parameters, one word to a line) and
  # routes (what the stand-in answers; a request no line names is a 404).
  for c in testdata/calls/*.case; do
    n=$(basename "$c" .case)
    d="$core/case_$n"
    mkdir "$d"
    split_case "$c" "$d"
    set_routes "$d/routes"
    : >"$tmp/requests"
    set --
    while IFS= read -r word; do set -- "$@" "$word"; done <"$d/args"
    yrun call infomaniak-calendar "$@" --json >"$d/stdout" 2>"$d/stderr"
    status=$?
    golden_of "$d" "$status" >"$d/golden"
    check "call $n" "$d/golden" "testdata/calls/$n.golden"
  done

  # Of all the requests the cases made: each carried the token, each is one of
  # the five routes the declaration names and nothing else (no DELETE, no
  # PATCH, no route beside the calendar's), and nothing that was sent invites
  # or notifies anyone.
  cat "$core"/case_*/golden >"$core/all.golden"
  ! grep -qE 'auth: (missing|WRONG)' "$core/all.golden"
  ok "every request carried the token as a bearer" $?
  ! grep -E '^[A-Z]+ ' "$core/all.golden" | grep -vE '^(GET /1/calendar/pim/calendar|GET /1/calendar/pim/event(\?[^ ]*)?|GET /1/calendar/pim/event/[1-9][0-9]*|POST /1/calendar/pim/event|PUT /1/calendar/pim/event/[1-9][0-9]*)$' | grep -q .
  ok "every request is one of the five routes of the declaration: no DELETE, no PATCH, nothing beside /1/calendar/pim" $?
  ! grep -E '^  body: ' "$core/all.golden" | grep -qE '"(notifyAttendees|imip_request)":true'
  ok "no body notifies anyone: notifyAttendees and imip_request are never true" $?
  awk '/^[A-Z]+ /{ method = $1 } /^  body: /{ if (method == "POST" && $0 !~ /"attendees":\[\]/) bad = 1; posts += (method == "POST") } END { exit (bad || !posts) }' "$core/all.golden"
  ok "every event created has no attendees, and some were created" $?
  ! grep -E '^  content-type: ' "$core/all.golden" | grep -vqE '^  content-type: application/json$'
  ok "every write is JSON" $?
  ! grep -E '^  user-agent: ' "$core/all.golden" | grep -vqE '^  user-agent: (yardr|other)$'
  ok "the yard names itself as yardr" $?

  # -- the token is in the env file the yard wrote and nowhere else
  envfile=$core/y/sources/infomaniak-calendar.env
  grep -qF "$token" "$envfile" && [ -n "$(find "$envfile" -type f -perm 600)" ]
  ok "the env file holds the token, and only its owner reads it" $?
  leaks=$(grep -rlF "$token" "$core/y" "$core/h" 2>/dev/null | grep -vxF "$envfile")
  [ -z "$leaks" ]
  ok "the token is in no other file of the yard" $? "found in: $leaks"
  ! grep -qF "$token" "$core/add.out" "$core/check.out" "$core"/case_*/stdout "$core"/case_*/stderr "$core"/case_*/golden
  ok "the token is in no output of the yard's commands" $?
fi
