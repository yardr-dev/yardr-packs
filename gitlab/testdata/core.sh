# The core part of the gitlab test, sourced by ./test: the declaration as the
# yard reads it, the preset and the grants SETUP.md teaches, and the calls
# made through the real yardr against a stand-in on a loopback port
# (testdata/standin.py). Everything runs in a scratch yard under a short path
# (a unix socket's path is held to 100 bytes) with its own home and an
# environment of nothing but PATH: none of this session's YARDR_* variables
# lead back to a real yard. No daemon is started, so no agent is, and the
# only listener is the stand-in's, on 127.0.0.1 and a port the system
# chooses.
#
# ./test has set $YARDR, $here, $work, check, ok and cleanup (which stops the
# stand-in by its pid, stops the scratch yard's server, and removes the
# scratch yard, whatever core is by then).
core=$(mktemp -d /tmp/gitlabt.XXXXXX)
mkdir -p "$core/h"
yrun() { env -i HOME="$core/h" PATH="$PATH" "$YARDR" --home "$core/y" --actor tester "$@"; }
token=glpat-FIXTUREa1b2c3d4e5f6

if ! yrun init --harness claude --operator tester >"$core/init.out" 2>&1; then
  echo "test: core FAILED: the scratch yard could not be made: $(tail -c 300 "$core/init.out")"
  fail=1
elif ! yrun pack apply "$here" --yes >"$core/apply.out" 2>&1; then
  echo "test: core FAILED: the pack did not apply from its directory: $(tail -c 300 "$core/apply.out")"
  fail=1
else
  # -- the declaration as the yard reads it, with the shipped base
  yrun source show gitlab --json | jq -S .declaration >"$core/declaration.json"
  check "declaration as the yard reads it (hook, events, thread, link, calls)" "$core/declaration.json" testdata/declaration.golden
  jq -e '.base == "https://gitlab.com/api/v4" and ([.calls[] | .kind == "read" and .request.method == "GET"] | all)
         and (.calls | map(.name) == ["user", "project", "merge_request", "pipelines", "issues", "issue"])
         and .events.runs == ["pipeline"] and .events.head_from == ["merge_request"]
         and .events.pr == ["gitlab/mr", "pr"] and .events.ci == ["gitlab/mr", "ci"]' "$core/declaration.json" >/dev/null
  ok "the shipped base is gitlab.com, every call is a read by GET, and events name pipeline, merge_request and the two commands" $?
  yrun pack show gitlab >"$core/packshow.out" 2>&1
  grep -q '1\. read: ' "$core/packshow.out" && grep -q 'gitlab: read' "$core/packshow.out"
  ok "pack show prints the one preset, read, as SETUP.md says" $?

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
  fi

  # -- the calls, through the real yardr against the stand-in. The operator's
  # copy is the declaration with its base replaced, as SETUP.md's last step
  # makes one for a self-managed instance; here the instance is the stand-in.
  mkdir -p "$core/mine"
  cp -R "$here/gitlab" "$core/mine/"
  : >"$core/requests"
  printf '{}\n' >"$core/answer.json"
  python3 -I testdata/standin.py "$core/port" "$core/requests" "$core/answer.json" 2>"$core/standin.err" <<EOF &
$token
EOF
  standin_pid=$!
  i=0
  while [ ! -s "$core/port" ] && [ "$i" -lt 200 ]; do sleep 0.05; i=$((i + 1)); done
  if [ ! -s "$core/port" ]; then
    echo "test: core FAILED: the stand-in did not listen: $(cat "$core/standin.err")"
    fail=1
  else
    site=http://127.0.0.1:$(cat "$core/port")
    sed "s|^base: .*|base: $site/api/v4|" "$here/gitlab.yaml" >"$core/mine/gitlab.yaml"
    # The credential is given as SETUP.md gives it: yardr source key, here
    # with the line on its standard input, which the server writes into the
    # source's env file.
    yrun source add "$core/mine/gitlab.yaml" >"$core/add.out" 2>&1 \
      && printf 'GITLAB_TOKEN=%s\n' "$token" | yrun source key gitlab >>"$core/add.out" 2>&1 \
      && yrun source set gitlab calls_per_hour=1000 >>"$core/add.out" 2>&1
    ok "the operator's copy is added and its credential given by source key" $? "$(tail -c 300 "$core/add.out")"

    # A case file is sections, each opened by a line "=== name": args (the
    # call and its parameters, one word to a line), answer (the stand-in's
    # body) and status (its HTTP status, 200 if left out).
    for c in testdata/calls/*.case; do
      n=$(basename "$c" .case)
      d="$core/case_$n"
      mkdir "$d"
      awk -v dir="$d" '/^=== /{ name = substr($0, 5); f = dir "/" name; printf "" > f; next } { print >> f }' "$c"
      if [ -e "$d/answer" ]; then cp "$d/answer" "$core/answer.json"; else printf '{}\n' >"$core/answer.json"; fi
      rm -f "$core/answer.json.status"
      [ ! -e "$d/status" ] || cp "$d/status" "$core/answer.json.status"
      : >"$core/requests"
      set --
      while IFS= read -r word; do set -- "$@" "$word"; done <"$d/args"
      yrun call gitlab "$@" --json >"$d/stdout" 2>"$d/stderr"
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
    # Reads only: of all the requests the cases made, the stand-in saw GETs.
    methods=$(awk '/^--- requests/ { r = 1; next } /^--- status/ { r = 0 } r && /^[A-Z]/ { print $1 }' "$core"/case_*/golden | sort -u)
    [ "$methods" = GET ]
    ok "no request of any case is anything but a GET" $? "methods seen: $methods"
    ! grep -q 'auth: WRONG' "$core"/case_*/golden
    ok "every request carried the credential in PRIVATE-TOKEN" $?

    # -- the token is in no file the run left but the env file, and in no output
    kill "$standin_pid" 2>/dev/null
    standin_pid=
    envfile=$core/y/sources/gitlab.env
    leaks=$(grep -rlF -e "$token" "$core" 2>/dev/null | grep -vxF "$envfile")
    [ -z "$leaks" ]
    ok "the token is in no file of the run but the env file" $? "found in: $leaks"
    grep -qF "$token" "$envfile"
    ok "(and the env file does hold the token, so the search above looked at something)" $?
  fi
fi
[ -z "${standin_pid:-}" ] || { kill "$standin_pid" 2>/dev/null; standin_pid=; }
