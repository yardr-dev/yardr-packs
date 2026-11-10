# The core part of the infomaniak-mail test, sourced by ./test: the declaration
# as the yard reads it, the presets and the grants SETUP.md teaches, the check
# call, and each testdata/calls/*.case made through the real yardr against a
# stand-in on a loopback port (testdata/standin.py). Everything runs in a
# scratch yard under a short path (a unix socket's path is held to 100 bytes)
# with its own home and an environment of nothing but PATH: none of this
# session's YARDR_* variables lead back to a real yard. No daemon is started,
# so no agent is, and the only listener is the stand-in's, on 127.0.0.1 and a
# port the system chooses.
#
# ./test has set $YARDR, $here, $tmp, check, ok and cleanup (which stops the
# stand-in by its pid, stops the scratch yard's server, and removes the
# scratch yard, whatever core is by then).
core=$(mktemp -d /tmp/imkt.XXXXXX) || { core=; echo "test: core FAILED: no temp directory under /tmp for the scratch yard"; exit 1; }
mkdir -p "$core/h"
yrun() { env -i HOME="$core/h" PATH="$PATH" "$YARDR" --home "$core/y" --actor tester "$@"; }

# The token typed into the scratch yard: a made-up string, new for each run and
# no secret, which the stand-in takes for the one right token. No file of the
# pack holds one.
token=TESTTOKEN-$$-$(date +%s)

if ! yrun init --harness claude --operator tester >"$core/init.out" 2>&1; then
  echo "test: core FAILED: the scratch yard could not be made: $(tail -c 300 "$core/init.out")"
  fail=1
elif ! yrun pack apply "$here" --yes >"$core/apply.out" 2>&1; then
  echo "test: core FAILED: the pack did not apply from its directory: $(tail -c 300 "$core/apply.out")"
  fail=1
else
  # -- the declaration as the yard reads it, with the shipped base
  yrun source show infomaniak-mail --json | jq -S .declaration >"$core/declaration.json"
  check "declaration as the yard reads it (base, credential, calls)" "$core/declaration.json" testdata/declaration.golden
  # The kinds are what keeps writing apart, and the methods and paths what keeps
  # sending, moving and deleting out: five reads that all GET, and one update
  # that POSTs to the draft's address, whose body draft builds with build-draft.
  jq -e '.base == "https://mail.infomaniak.com/api" and .check == "mailboxes" and (has("idempotency") | not)
         and ([.calls[] | select(.kind == "read") | .name] == ["mailboxes", "folders", "search", "message", "drafts"])
         and ([.calls[] | select(.kind == "read") | .request.method] | all(. == "GET"))
         and ([.calls[] | select(.kind == "update") | .name] == ["draft"])
         and ([.calls[] | select(.name == "draft") | .request | .method + " " + .path] == ["POST /mail/{mailbox}/draft"])
         and ([.calls[] | select(.name == "draft") | .build] == [["build-draft"]])
         and ([.calls[] | select(.name != "draft") | has("build")] | any | not)
         and ([.calls[] | .request.path] | all(test("/(seen|unseen|star|unstar|move|delete|archive|rename|attachment|send)") | not))
         and .credential.env == "INFOMANIAK_MAIL_TOKEN" and .credential.header == "Authorization: Bearer {credential}"
         and (.credential | has("mint") | not) and (.credential | has("update_env") | not)' "$core/declaration.json" >/dev/null
  ok "the shipped base is Infomaniak's, five calls read (all GET) and draft is the one update (a POST to the draft's address, built by build-draft), no call's path moves, marks or deletes, and the token is one bearer variable" $?
  yrun pack show infomaniak-mail >"$core/packshow.out" 2>&1
  grep -q '1\. read: ' "$core/packshow.out" && grep -q '2\. drafts: ' "$core/packshow.out" &&
    awk '/1\. read: /{ r = 1; next } /2\. drafts: /{ r = 2; next } r == 1 && /infomaniak-mail:/ { read = $0 } r == 2 && /infomaniak-mail:/ { drafts = $0 }
         END { exit !(read ~ /infomaniak-mail: read$/ && drafts ~ /infomaniak-mail: read, draft$/) }' "$core/packshow.out"
  ok "pack show prints the two presets, read granting read and drafts granting read and draft" $?

  # -- SETUP.md says what the token is and where it is made
  grep -q 'INFOMANIAK_MAIL_TOKEN' SETUP.md && grep -q 'workspace:mail' SETUP.md && grep -q 'manager.infomaniak.com/v3/ng/accounts/token/list' SETUP.md
  ok "SETUP.md names the variable, the scope workspace:mail and the manager's token list" $?

  # -- the grants SETUP.md teaches, run as written. They are read out of
  # SETUP.md and not copied here: a copy would pass whatever SETUP teaches,
  # and --preset is refused for a pack applied from a directory. The card of
  # SETUP.md grants the group reviewers, which a fresh yard has none of.
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
    # What those grants gave: read as the word for the read calls, and draft
    # as an update, granted by its name; nothing else was granted.
    yrun source grants --json >"$core/grants.json" 2>&1
    jq -e 'length > 0
           and ([.[] | .kinds | to_entries[]] | all((.key == "read" and .value == "read") or (.key == "draft" and .value == "update")))
           and ([.[] | .kinds | has("read")] | any) and ([.[] | .kinds | has("draft")] | any)' "$core/grants.json" >/dev/null
    ok "SETUP.md's grants give read as read and draft as an update, nothing else" $? "$(head -c 300 "$core/grants.json")"
  fi

  # -- the calls and the check, through the real yardr against the stand-in.
  # The operator's copy is the declaration with its base replaced: the real
  # one is https and Infomaniak's. The /api stays, so that the paths the
  # stand-in sees are the ones the service gets. The copy sits beside its
  # program, which source add copies into the yard.
  mkdir -p "$core/mine"
  cp "$here/build-draft" "$core/mine/"
  : >"$core/requests"
  printf '%s\n' "$token" >"$core/token"
  printf '{}\n' >"$core/answer.json"
  python3 -I testdata/standin.py "$core/port" "$core/requests" "$core/answer.json" "$core/token" 2>"$core/standin.err" &
  standin_pid=$!
  i=0
  while [ ! -s "$core/port" ] && [ "$i" -lt 200 ]; do sleep 0.05; i=$((i + 1)); done
  if [ ! -s "$core/port" ]; then
    echo "test: core FAILED: the stand-in did not listen: $(cat "$core/standin.err")"
    fail=1
  else
    site=http://127.0.0.1:$(cat "$core/port")
    sed "s|^base: .*|base: $site/api|" "$here/infomaniak-mail.yaml" >"$core/mine/infomaniak-mail.yaml"
    # The token is given as SETUP.md gives it: yardr source key, with the
    # name on its standard input, which the server writes into the source's
    # env file.
    yrun source add "$core/mine/infomaniak-mail.yaml" >"$core/add.out" 2>&1 \
      && printf 'INFOMANIAK_MAIL_TOKEN=%s\n' "$token" | yrun source key infomaniak-mail >>"$core/add.out" 2>&1 \
      && yrun source set infomaniak-mail calls_per_hour=1000 >>"$core/add.out" 2>&1 \
      && yrun source set infomaniak-mail updates_per_hour=1000 >>"$core/add.out" 2>&1
    ok "the operator's copy is added and the token given by source key" $? "$(tail -c 300 "$core/add.out")"

    # -- the check call: mailboxes, with the token as a bearer token
    : >"$core/requests"
    cp testdata/answers/mailboxes.json "$core/answer.json"
    yrun source check infomaniak-mail >"$core/check.out" 2>&1
    rc=$?
    [ "$rc" = 0 ] && grep -q 'check call mailboxes (GET /mailbox): 200' "$core/check.out" && grep -q 'yardr@example.com' "$core/check.out" \
      && grep -q 'command call.draft.build (build-draft): can be run' "$core/check.out"
    ok "source check makes the mailboxes call with the token, shows the mailbox and says build-draft can be run" $? "exit $rc: $(tail -c 300 "$core/check.out")"
    check "the check call's request" "$core/requests" testdata/check.requests.golden

    # A case file is sections, each opened by a line "=== name": args (the
    # call and its parameters, one word to a line), answer (the stand-in's
    # body; a line "@name" stands for testdata/answers/name.json) and status
    # (its HTTP status, 200 if left out).
    for c in testdata/calls/*.case; do
      n=$(basename "$c" .case)
      d="$core/case_$n"
      mkdir "$d"
      awk -v dir="$d" '/^=== /{ name = substr($0, 5); f = dir "/" name; printf "" > f; next } { print >> f }' "$c"
      if [ -e "$d/answer" ]; then
        first=$(head -n 1 "$d/answer")
        case $first in
          @*) cp "testdata/answers/${first#@}.json" "$core/answer.json" ;;
          *) cp "$d/answer" "$core/answer.json" ;;
        esac
      else
        printf '{}\n' >"$core/answer.json"
      fi
      rm -f "$core/answer.json.status"
      [ ! -e "$d/status" ] || cp "$d/status" "$core/answer.json.status"
      : >"$core/requests"
      set --
      while IFS= read -r word; do set -- "$@" "$word"; done <"$d/args"
      yrun call infomaniak-mail "$@" --json >"$d/stdout" 2>"$d/stderr"
      status=$?
      {
        echo "--- requests"
        cat "$core/requests"
        echo "--- status"
        echo "$status"
        echo "--- stdout"
        if [ -s "$d/stdout" ]; then jq -S . "$d/stdout" 2>/dev/null || cat "$d/stdout"; fi
        echo "--- stderr"
        cat "$d/stderr"
      } >"$d/golden"
      check "call $n" "$d/golden" "testdata/calls/$n.golden"
    done
    rm -f "$core/answer.json.status"

    # Of all the requests the cases made: each is a read of one of the
    # service's lists or messages, or the one POST that writes a draft. No
    # other method, no other address: nothing sent, moved, marked, flagged,
    # archived, deleted, renamed or uploaded, and no draft replaced or removed.
    cat "$core"/case_*/golden >"$core/all.golden"
    grep -c '^GET ' "$core/all.golden" >/dev/null
    ok "the cases made reads" $?
    ! grep -E '^[A-Z]+ ' "$core/all.golden" | grep -vE '^(GET /api/mailbox\?with=[^ ]*|GET /api/mail/[0-9A-Za-z-]+/folder\?with=ik-static|GET /api/mail/[0-9A-Za-z-]+/folder/[A-Za-z0-9_=+%-]+/message(/[0-9]+)?\?[^ ]*|POST /api/mail/[0-9A-Za-z-]+/draft)$' | grep -q .
    ok "every request is a GET of the mailboxes, the folders, a folder's messages or one message, or a POST to a mailbox's draft" $?
    posts=$(grep -c '^POST ' "$core/all.golden")
    sed -n 's/^  body: //p' "$core/all.golden" >"$core/bodies"
    [ "$posts" -gt 0 ] && [ "$(grep -c . "$core/bodies")" = "$posts" ] && jq -s -e 'all(.[]; .action == "save" and .delay == 0)' "$core/bodies" >/dev/null
    ok "every POST ($posts) has a body, and every body is a draft: action save, no delay" $?
    ! grep -E '^  (accept|content-type|user-agent): ' "$core/all.golden" | grep -vE '^  (accept: application/json|content-type: application/json|user-agent: yardr)$' | grep -q .
    ok "every request asked for JSON, sent JSON where it had a body and named yardr as its User-Agent" $?
    ! grep -q 'auth: WRONG\|auth: missing' "$core/all.golden" testdata/check.requests.golden
    ok "every request carried the token as a bearer token" $?

    # -- the token is in the one file that holds it, and nowhere else
    kill "$standin_pid" 2>/dev/null
    standin_pid=
    envfile=$core/y/sources/infomaniak-mail.env
    grep -qF "$token" "$envfile"
    ok "the env file holds the token" $?
    leaks=$(grep -rlF -e "$token" "$core/y" "$core/h" 2>/dev/null | grep -vxF "$envfile")
    [ -z "$leaks" ]
    ok "the token is in no file of the yard but its env file" $? "found in: $leaks"
    ! grep -qF -e "$token" "$core/check.out" "$core/add.out" "$core/all.golden" "$core"/case_*/stdout "$core"/case_*/stderr
    ok "the token is in no output of the yard's commands" $?
  fi
fi
[ -z "${standin_pid:-}" ] || { kill "$standin_pid" 2>/dev/null; standin_pid=; }
