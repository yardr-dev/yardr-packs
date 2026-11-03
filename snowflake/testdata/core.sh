# The core part of the snowflake test, sourced by ./test: the declaration as
# the yard reads it, the presets and the grants SETUP.md teaches, the check
# call, and each testdata/calls/*.case made through the real yardr against a
# stand-in on a loopback port (testdata/standin.py). Everything runs in a
# scratch yard under a short path (a unix socket's path is held to 100
# bytes) with its own home and an environment of nothing but PATH: none of
# this session's YARDR_* variables lead back to a real yard. No daemon is
# started, so no agent is, and the only listener is the stand-in's, on
# 127.0.0.1 and a port the system chooses.
#
# ./test has set $YARDR, $here, $tmp, $keys (the throwaway key pair), $fp,
# $needle, check, ok, jwt_part, jwt_signed and cleanup (which stops the
# stand-in by its pid, stops the scratch yard's server, and removes the
# scratch yard, whatever core is by then).
core=$(mktemp -d /tmp/snowflaket.XXXXXX)
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
  yrun source show snowflake --json | jq -S .declaration >"$core/declaration.json"
  check "declaration as the yard reads it (base, credential, calls)" "$core/declaration.json" testdata/declaration.golden
  # The kinds are what keeps writing apart: read covers every read call and
  # no update, and execute, the one update, is granted by its name.
  jq -e '.base == "https://example.snowflakecomputing.com" and .check == "databases" and (has("idempotency") | not)
         and ([.calls[] | select(.kind == "read") | .name] == ["query", "databases", "schemas", "tables", "status"])
         and ([.calls[] | select(.kind == "update") | .name] == ["execute"])
         and (.credential.mint == ["SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_KEY_FILE"])
         and (.credential.not_secret == .credential.mint)
         and .credential.mint_command == ["snowflake/mint"] and .credential.env == "SNOWFLAKE_JWT"
         and .credential.header == "Authorization: Bearer {credential}"' "$core/declaration.json" >/dev/null
  ok "the shipped base is the placeholder, five calls read and execute the one update, the three mint names are asked in the clear, and no idempotency header is named" $?
  yrun pack show snowflake >"$core/packshow.out" 2>&1
  grep -q '1\. read: ' "$core/packshow.out" && grep -q '2\. write: ' "$core/packshow.out" &&
    awk '/1\. read: /{ r = 1; next } /2\. write: /{ r = 2; next } r == 1 && /snowflake:/ { read = $0 } r == 2 && /snowflake:/ { write = $0 }
         END { exit !(read ~ /snowflake: read$/ && write ~ /snowflake: execute$/) }' "$core/packshow.out"
  ok "pack show prints the two presets, read granting read and write granting execute alone" $?

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
    # What those grants gave: read as the word for the read calls, and
    # execute as an update, granted by its name; nothing else was granted.
    yrun source grants --json >"$core/grants.json" 2>&1
    jq -e 'length > 0
           and ([.[] | .kinds | to_entries[]] | all((.key == "read" and .value == "read") or (.key == "execute" and .value == "update")))
           and ([.[] | .kinds | has("read")] | any) and ([.[] | .kinds | has("execute")] | any)' "$core/grants.json" >/dev/null
    ok "SETUP.md's grants give read as read and execute as an update, nothing else" $? "$(head -c 300 "$core/grants.json")"
  fi

  # -- the calls and the check, through the real yardr against the stand-in.
  # The operator's copy is the declaration with its base replaced, as
  # SETUP.md makes it; here the account is the stand-in.
  mkdir -p "$core/mine"
  cp -R "$here/snowflake" "$core/mine/"
  : >"$core/requests"
  : >"$core/tokens"
  printf '{}\n' >"$core/answer.json"
  python3 -I testdata/standin.py "$core/port" "$core/requests" "$core/answer.json" "$core/tokens" 2>"$core/standin.err" &
  standin_pid=$!
  i=0
  while [ ! -s "$core/port" ] && [ "$i" -lt 200 ]; do sleep 0.05; i=$((i + 1)); done
  if [ ! -s "$core/port" ]; then
    echo "test: core FAILED: the stand-in did not listen: $(cat "$core/standin.err")"
    fail=1
  else
    site=http://127.0.0.1:$(cat "$core/port")
    sed "s|^base: .*|base: $site|" "$here/snowflake.yaml" >"$core/mine/snowflake.yaml"
    # The credential is given as SETUP.md gives it: yardr source key, with
    # the three names on its standard input, which the server writes into
    # the source's env file. The account is lower case here and the user
    # too, so the claims show the mint uppercasing them.
    yrun source add "$core/mine/snowflake.yaml" >"$core/add.out" 2>&1 \
      && printf 'SNOWFLAKE_ACCOUNT=myorg-acct1\nSNOWFLAKE_USER=yardr\nSNOWFLAKE_KEY_FILE=%s\n' "$keys/k.p8" | yrun source key snowflake >>"$core/add.out" 2>&1 \
      && yrun source set snowflake calls_per_hour=1000 >>"$core/add.out" 2>&1 \
      && yrun source set snowflake updates_per_hour=1000 >>"$core/add.out" 2>&1
    ok "the operator's copy is added and its three names given by source key" $? "$(tail -c 300 "$core/add.out")"

    # -- the check call, minted by the pack's own mint
    : >"$core/requests"
    printf '%s\n' "$(cat testdata/answers/show-databases.json)" >"$core/answer.json"
    yrun source check snowflake >"$core/check.out" 2>&1
    rc=$?
    [ "$rc" = 0 ] && grep -q 'SNOWFLAKE_SAMPLE_DATA' "$core/check.out"
    ok "source check reaches the account with a minted token and shows the databases" $? "exit $rc: $(tail -c 300 "$core/check.out")"
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
      yrun call snowflake "$@" --json >"$d/stdout" 2>"$d/stderr"
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

    # Of all the requests the cases made: every one came to the one path, a
    # POST or, for status, a GET of a handle, with a token of the shape
    # Snowflake takes, and Snowflake's headers.
    cat "$core"/case_*/golden >"$core/all.golden"
    ! grep -q 'auth: WRONG\|auth: missing' "$core/all.golden"
    ok "every request carried a bearer token of the shape Snowflake takes" $?
    ! grep -E '^[A-Z]+ ' "$core/all.golden" | grep -vE '^(POST /api/v2/statements(\?async=true)?|GET /api/v2/statements/[0-9a-f-]{36})$' | grep -q .
    ok "every request is a POST to /api/v2/statements (async only as async=true) or a GET of one statement" $?
    ! grep -E '^  (accept|content-type|user-agent): ' "$core/all.golden" | grep -vE '^  (accept: application/json|content-type: application/json|user-agent: yardr)$' | grep -q .
    ok "every request asked for JSON, sent JSON and named yardr as its User-Agent" $?

    # -- the token the yard sent: the real mint, from the env file's names
    kill "$standin_pid" 2>/dev/null
    standin_pid=
    ntok=$(grep -c . "$core/tokens")
    bad=
    [ "$ntok" -ge 1 ] || bad=" the stand-in saw no token;"
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      jwt_signed "$tok" "$keys/pub.pem" || bad="$bad a token is not signed by the key;"
      jwt_part "$tok" 2 | jq -e --arg iss "MYORG-ACCT1.YARDR.$fp" --arg sub MYORG-ACCT1.YARDR '.iss == $iss and .sub == $sub and (.exp - .iat) == 3540' >/dev/null ||
        bad="$bad a token's claims are not those of the env file's account and user;"
    done <"$core/tokens"
    [ -z "$bad" ]
    ok "the token the yard sent was minted by snowflake/mint from the env file ($ntok seen), signed by the key and claiming the account and user" $? "$bad"

    # -- the key is in no file the run made, and no token is either
    envfile=$core/y/sources/snowflake.env
    grep -qF "$keys/k.p8" "$envfile" && ! grep -qF "$needle" "$envfile"
    ok "the env file names the key by its path and holds none of its bytes" $?
    leaks=$(grep -rlF -e "$needle" "$core/y" "$core/h" 2>/dev/null)
    [ -z "$leaks" ]
    ok "the key's bytes are in no file of the yard" $? "found in: $leaks"
    # (One token or two: holding, in ./test, says why.)
    tleaks=$(holding "$core/tokens" "$core/y" "$core/h")
    [ -z "$tleaks" ]
    ok "no token is in any file of the yard (it is minted in memory)" $? "found in: $tleaks"
    ! grep -qF -e "$needle" "$core/check.out" "$core/add.out" "$core"/case_*/stdout "$core"/case_*/stderr
    ok "the key is in no output of the yard's commands" $?
  fi
fi
[ -z "${standin_pid:-}" ] || { kill "$standin_pid" 2>/dev/null; standin_pid=; }
