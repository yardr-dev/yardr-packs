# The core part of the postiz test, sourced by ./test: the declaration as
# the yard reads it, the presets and the grants SETUP.md teaches, the check
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
core=$(mktemp -d /tmp/pozt.XXXXXX) || { core=; echo "test: core FAILED: no temp directory under /tmp for the scratch yard"; exit 1; }
mkdir -p "$core/h"
yrun() { env -i HOME="$core/h" PATH="$PATH" "$YARDR" --home "$core/y" --actor tester "$@"; }

# The key typed into the scratch yard: a made-up string, new for each run and
# no secret, which the stand-in takes for the one right key. No file of the
# pack holds one.
token=TESTKEY-$$-$(date +%s)

if ! yrun init --harness claude --operator tester >"$core/init.out" 2>&1; then
  echo "test: core FAILED: the scratch yard could not be made: $(tail -c 300 "$core/init.out")"
  fail=1
elif ! yrun pack apply "$here" --yes >"$core/apply.out" 2>&1; then
  echo "test: core FAILED: the pack did not apply from its directory: $(tail -c 300 "$core/apply.out")"
  fail=1
else
  # -- the declaration as the yard reads it, with the shipped base
  yrun source show postiz --json | jq -S .declaration >"$core/declaration.json"
  check "declaration as the yard reads it (base, credential, calls)" "$core/declaration.json" testdata/declaration.golden
  # The kinds are what keeps writing apart, and the methods and paths what
  # keeps publishing at once, deleting and editing out: three reads that all
  # GET, and three updates that POST a draft, a schedule or an upload, the
  # first two built by build-post.
  jq -e '.base == "https://api.postiz.com/public/v1" and .check == "channels" and (has("idempotency") | not)
         and ([.calls[] | select(.kind == "read") | .name] == ["channels", "posts", "slot"])
         and ([.calls[] | select(.kind == "read") | .request.method] | all(. == "GET"))
         and ([.calls[] | select(.kind == "update") | .name] == ["draft", "schedule", "upload"])
         and ([.calls[] | select(.name == "draft" or .name == "schedule") | .request | .method + " " + .path] | all(. == "POST /posts"))
         and ([.calls[] | select(.name == "draft") | .build] == [["build-post", "draft"]])
         and ([.calls[] | select(.name == "schedule") | .build] == [["build-post", "schedule"]])
         and ([.calls[] | select(.name == "upload") | .request | .method + " " + .path] == ["POST /upload"])
         and ([.calls[] | select(.name == "upload") | has("build")] | any | not)
         and ([.calls[] | .request.method] | all(. != "PUT" and . != "PATCH" and . != "DELETE"))
         and ([.calls[] | .request.path] | all(test("/(now|delete|status|settings|trigger|analytics|video|clipping|webhook|group)") | not))
         and .credential.env == "POSTIZ_API_KEY" and .credential.header == "Authorization: {credential}"
         and (.credential | has("mint") | not) and (.credential | has("update_env") | not)' "$core/declaration.json" >/dev/null
  ok "the shipped base is Postiz's cloud, three calls read (all GET) and draft, schedule and upload are the updates (two POSTs built by build-post, one multipart upload), no call's path deletes or edits, and the key goes bare" $?
  yrun pack show postiz >"$core/packshow.out" 2>&1
  grep -q '1\. read: ' "$core/packshow.out" && grep -q '2\. drafts: ' "$core/packshow.out" && grep -q '3\. schedule: ' "$core/packshow.out" &&
    awk '/1\. read: /{ r = 1; next } /2\. drafts: /{ r = 2; next } /3\. schedule: /{ r = 3; next } r == 1 && /postiz:/ { read = $0 } r == 2 && /postiz:/ { drafts = $0 } r == 3 && /postiz:/ { sched = $0 }
         END { exit !(read ~ /postiz: read$/ && drafts ~ /postiz: read, draft, upload$/ && sched ~ /postiz: read, schedule, upload$/) }' "$core/packshow.out"
  ok "pack show prints the three presets, read granting read, drafts granting read, draft and upload, schedule granting read, schedule and upload" $?

  # -- SETUP.md says what the key is, where it is made and where calls go
  grep -q 'POSTIZ_API_KEY' SETUP.md && grep -q 'Developers' SETUP.md && grep -q 'api.postiz.com/public/v1' SETUP.md && grep -q '/api/public/v1' SETUP.md
  ok "SETUP.md names the variable, the Developers tab, the cloud base and the self-hosted base" $?

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
    # What those grants gave: read as the word for the read calls, and draft,
    # schedule and upload as updates, granted each by its name; nothing else
    # was granted.
    yrun source grants --json >"$core/grants.json" 2>&1
    jq -e 'length > 0
           and ([.[] | .kinds | to_entries[]] | all((.key == "read" and .value == "read") or (.key == "draft" and .value == "update") or (.key == "schedule" and .value == "update") or (.key == "upload" and .value == "update")))
           and ([.[] | .kinds | has("read")] | any) and ([.[] | .kinds | has("draft")] | any)
           and ([.[] | .kinds | has("schedule")] | any) and ([.[] | .kinds | has("upload")] | any)' "$core/grants.json" >/dev/null
    ok "SETUP.md's grants give read as read and draft, schedule and upload as updates, nothing else" $? "$(head -c 300 "$core/grants.json")"
  fi

  # -- the calls and the check, through the real yardr against the stand-in.
  # The operator's copy is the declaration with its base replaced: the real
  # one is https and Postiz's. The /public/v1 stays a path, so that the
  # requests the stand-in sees are shaped as the service's own.
  mkdir -p "$core/mine"
  cp "$here/build-post" "$core/mine/"
  # The picture the upload case sends, and the one the service must never see:
  # 11 MiB, over the call's 10, which yardr refuses before anything is sent.
  head -c 11534336 /dev/zero >"$core/big.png"
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
    sed "s|^base: .*|base: $site/public/v1|" "$here/postiz.yaml" >"$core/mine/postiz.yaml"
    # The key is given as SETUP.md gives it: yardr source key, with the
    # name on its standard input, which the server writes into the source's
    # env file.
    yrun source add "$core/mine/postiz.yaml" >"$core/add.out" 2>&1 \
      && printf 'POSTIZ_API_KEY=%s\n' "$token" | yrun source key postiz >>"$core/add.out" 2>&1 \
      && yrun source set postiz calls_per_hour=1000 >>"$core/add.out" 2>&1 \
      && yrun source set postiz updates_per_hour=1000 >>"$core/add.out" 2>&1
    ok "the operator's copy is added and the key given by source key" $? "$(tail -c 300 "$core/add.out")"

    # -- the check call: channels, with the bare key
    : >"$core/requests"
    cp testdata/answers/channels.json "$core/answer.json"
    yrun source check postiz >"$core/check.out" 2>&1
    rc=$?
    # The answer is a list, so the check prints its size and not its fields;
    # the request golden below holds what was asked and the channels case what
    # the call keeps of the answer.
    [ "$rc" = 0 ] && grep -q 'check call channels (GET /integrations): 200' "$core/check.out" \
      && grep -q 'command call.draft.build (build-post draft): can be run' "$core/check.out" \
      && grep -q 'command call.schedule.build (build-post schedule): can be run' "$core/check.out"
    ok "source check makes the channels call with the key and says build-post can be run for both" $? "exit $rc: $(tail -c 300 "$core/check.out")"
    check "the check call's request" "$core/requests" testdata/check.requests.golden

    # A case file is sections, each opened by a line "=== name": args (the
    # call and its parameters, one word to a line; @testfile:<name> stands
    # for the fixture under testdata/, @tmpfile:<name> for the file the test
    # made under its scratch directory), answer (the stand-in's body; a line
    # "@name" stands for testdata/answers/name.json) and status (its HTTP
    # status, 200 if left out).
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
      while IFS= read -r word; do
        case $word in
          file=@testfile:*) word="file=$here/testdata/${word#file=@testfile:}" ;;
          file=@tmpfile:*) word="file=$core/${word#file=@tmpfile:}" ;;
        esac
        set -- "$@" "$word"
      done <"$d/args"
      yrun call postiz "$@" --json >"$d/stdout" 2>"$d/stderr"
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
      # A draft's date is the current time: NOW where it stands, as in the
      # build part. The freshness check there says it is current.
      case $n in draft|draft-*) sed 's/"date":"[^"]*"/"date":"NOW"/' "$d/golden" >"$d/still" && mv "$d/still" "$d/golden" ;; esac
      check "call $n" "$d/golden" "testdata/calls/$n.golden"
    done
    rm -f "$core/answer.json.status"

    # Of all the requests the cases made: each is a read of the channels, the
    # posts or a slot, the one multipart upload, or the one POST that writes
    # a draft or a schedule. No other method, no other address: nothing
    # published at once, deleted, edited, threaded or analysed.
    cat "$core"/case_*/golden >"$core/all.golden"
    grep -c '^GET ' "$core/all.golden" >/dev/null
    ok "the cases made reads" $?
    ! grep -E '^[A-Z]+ ' "$core/all.golden" | grep -vE '^(GET /public/v1/integrations|GET /public/v1/posts\?[^ ]*|GET /public/v1/find-slot/[A-Za-z0-9_-]+|POST /public/v1/posts|POST /public/v1/upload)$' | grep -q .
    ok "every request is a GET of the channels, the posts or a slot, or a POST of a draft, a schedule or an upload" $?
    posts=$(grep -c '^POST /public/v1/posts$' "$core/all.golden")
    sed -n 's/^  body: //p' "$core/all.golden" >"$core/bodies"
    [ "$posts" -gt 0 ] && [ "$(grep -c . "$core/bodies")" = "$posts" ] && jq -s -e 'all(.[]; (.type == "draft" or .type == "schedule") and .shortLink == false and (.posts | length) >= 1)' "$core/bodies" >/dev/null
    ok "every POST /posts ($posts) has a body, and every body is a draft or a schedule with entries" $?
    jq -s -e '[.[] | select(.type == "schedule")] | length > 0 and all(.[]; .date > "2029")' "$core/bodies" >/dev/null
    ok "a schedule was sent, and every schedule's date is in the future" $?
    ! grep -E '^  (accept|content-type|user-agent): ' "$core/all.golden" | grep -vE '^  (accept: application/json|content-type: (application/json|multipart/form-data)|user-agent: yardr)$' | grep -q .
    ok "every request asked for JSON, sent JSON or an upload where it had a body, and named yardr as its User-Agent" $?
    grep -q '^  part: file filename=pic.png type=image/png size=69 sha256=' "$core/all.golden" && ! grep -q '^  field: ' "$core/all.golden"
    ok "the upload is one file part, the picture as it stands, with no other field" $?
    ! grep -q 'auth: WRONG\|auth: missing' "$core/all.golden" testdata/check.requests.golden
    ok "every request carried the key bare" $?

    # -- the key is in the one file that holds it, and nowhere else
    kill "$standin_pid" 2>/dev/null
    standin_pid=
    envfile=$core/y/sources/postiz.env
    grep -qF "$token" "$envfile"
    ok "the env file holds the key" $?
    leaks=$(grep -rlF -e "$token" "$core/y" "$core/h" 2>/dev/null | grep -vxF "$envfile")
    [ -z "$leaks" ]
    ok "the key is in no file of the yard but its env file" $? "found in: $leaks"
    ! grep -qF -e "$token" "$core/check.out" "$core/add.out" "$core/all.golden" "$core"/case_*/stdout "$core"/case_*/stderr
    ok "the key is in no output of the yard's commands" $?
  fi
fi
[ -z "${standin_pid:-}" ] || { kill "$standin_pid" 2>/dev/null; standin_pid=; }
