# The core part of the infomaniak-drive test, sourced by ./test: the
# declaration as the yard reads it, the presets and the grants SETUP.md
# teaches, the check, and each testdata/calls/*.case made through the real
# yardr against a stand-in on a loopback port (testdata/standin.py). Everything
# runs in a scratch yard under a short path (a unix socket's path is held to
# 100 bytes) with its own home and an environment of nothing but PATH: none of
# this session's YARDR_* variables lead back to a real yard. No daemon is
# started, so no agent is, and the only listener is the stand-in's, on
# 127.0.0.1 and a port the system chooses.
#
# ./test has set $YARDR, $here, $tmp, check, ok and cleanup (which stops the
# stand-in by its pid, stops the scratch yard's server, and removes the
# scratch yard, whatever core is by then).
core=$(mktemp -d /tmp/idrv.XXXXXX) || { core=; echo "test: core FAILED: no temp directory under /tmp for the scratch yard"; exit 1; }
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
  yrun source show infomaniak-drive --json | jq -S .declaration >"$core/declaration.json"
  check "declaration as the yard reads it (base, credential, calls)" "$core/declaration.json" testdata/declaration.golden
  # The kinds are what keeps writing apart, and the methods and paths what
  # keeps deleting, trashing and access changes out: five reads that all
  # GET but the download, which a command answers, and three updates, of
  # which the upload's GET reads the file back and the other two POST.
  jq -e '.base == "https://api.infomaniak.com" and (has("check") | not) and (has("idempotency") | not)
         and ([.calls[] | select(.kind == "read") | .name] == ["files", "file", "search", "comments", "download"])
         and ([.calls[] | select(.kind == "read" and .name != "download") | .request.method] | all(. == "GET"))
         and ([.calls[] | select(.name == "download") | .run] == [["drive-file", "download"]])
         and ([.calls[] | select(.name == "download") | .request] == [{method: "", path: ""}])
         and ([.calls[] | select(.kind == "update") | .name] == ["upload", "comment", "share"])
         and ([.calls[] | select(.name == "upload") | .request | .method + " " + .path] == ["GET /3/drive/{drive}/files/{folder}/name"])
         and ([.calls[] | select(.name == "upload") | .build] == [["drive-file", "upload"]])
         and ([.calls[] | select(.name == "comment") | .request | .method + " " + .path] == ["POST /2/drive/{drive}/files/{fileId}/comments"])
         and ([.calls[] | select(.name == "share") | .request | .method + " " + .path] == ["POST /2/drive/{drive}/files/{fileId}/link"])
         and ([.calls[] | select(.name != "upload") | has("build")] | any | not)
         and ([.calls[] | select(.request.method != "") | .request.method] | all(. == "GET" or . == "POST"))
         and ([.calls[] | select(.request.path != "") | .request.path] | all(test("/(trash|delete|archive|rename|move|copy|access|invitation|version|restore|convert)") | not))
         and .credential.env == "INFOMANIAK_DRIVE_TOKEN" and .credential.header == "Authorization: Bearer {credential}"
         and (.credential | has("mint") | not) and (.credential | has("update_env") | not)' "$core/declaration.json" >/dev/null
  ok "the shipped base is Infomaniak's, five calls read (four GET, the download by drive-file) and three update (the upload's GET by name, a comment POST, a link POST), no call's path deletes, trashes or grants access, and the token is one bearer variable" $?
  yrun pack show infomaniak-drive >"$core/packshow.out" 2>&1
  grep -q '1\. read: ' "$core/packshow.out" && grep -q '2\. make: ' "$core/packshow.out" && grep -q '3\. everything: ' "$core/packshow.out" &&
    awk '/1\. read: /{ r = 1; next } /2\. make: /{ r = 2; next } /3\. everything: /{ r = 3; next } r == 1 && /infomaniak-drive:/ { read = $0 } r == 2 && /infomaniak-drive:/ { make = $0 } r == 3 && /infomaniak-drive:/ { all = $0 }
         END { exit !(read ~ /infomaniak-drive: read$/ && make ~ /infomaniak-drive: read, upload, comment$/ && all ~ /infomaniak-drive: read, upload, comment, share$/) }' "$core/packshow.out"
  ok "pack show prints the three presets, read granting read, make read with upload and comment, everything those and share" $?

  # -- SETUP.md says what the token is and where it is made
  grep -q 'INFOMANIAK_DRIVE_TOKEN' SETUP.md && grep -q 'scope `drive`' SETUP.md && grep -q 'manager.infomaniak.com/v3/ng/accounts/token/list' SETUP.md
  ok "SETUP.md names the variable, the scope drive and the manager's token list" $?

  # -- the grants SETUP.md teaches, run as written. They are read out of
  # SETUP.md and not copied here: a copy would pass whatever SETUP teaches.
  # The card of SETUP.md grants the group reviewers, which a fresh yard has
  # none of.
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
    # What those grants gave: read as the word for the read calls, and each
    # update by its name; nothing else was granted.
    yrun source grants --json >"$core/grants.json" 2>&1
    jq -e 'length > 0
           and ([.[] | .kinds | to_entries[]] | all((.key == "read" and .value == "read") or ((.key == "upload" or .key == "comment" or .key == "share") and .value == "update")))
           and ([.[] | .kinds | has("read")] | any) and ([.[] | .kinds | has("upload")] | any)
           and ([.[] | .kinds | has("comment")] | any) and ([.[] | .kinds | has("share")] | any)' "$core/grants.json" >/dev/null
    ok "SETUP.md's grants give read as read and upload, comment and share as updates, nothing else" $? "$(head -c 300 "$core/grants.json")"
  fi

  # -- the calls and the check, through the real yardr against the stand-in.
  # The operator's copy is the declaration with its base replaced: the real
  # one is https and Infomaniak's. The /api stays, so that the paths the
  # stand-in sees are the ones the service gets. The copy sits beside its
  # program, which source add copies into the yard.
  mkdir -p "$core/mine" "$core/files"
  cp "$here/drive-file" "$core/mine/"
  # One file to upload, and one a byte past the call's bound, which reads
  # instantly and holds no bytes.
  printf 'Hello, kDrive.\n' >"$core/files/hello.txt"
  python3 -c "open('$core/files/big.bin','wb').truncate(10*1024*1024+1)"
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
    sed "s|^base: .*|base: $site/api|" "$here/infomaniak-drive.yaml" >"$core/mine/infomaniak-drive.yaml"
    # The token is given as SETUP.md gives it: yardr source key, with the
    # name on its standard input, which the server writes into the source's
    # env file.
    yrun source add "$core/mine/infomaniak-drive.yaml" >"$core/add.out" 2>&1 \
      && printf 'INFOMANIAK_DRIVE_TOKEN=%s\n' "$token" | yrun source key infomaniak-drive >>"$core/add.out" 2>&1 \
      && yrun source set infomaniak-drive calls_per_hour=1000 >>"$core/add.out" 2>&1 \
      && yrun source set infomaniak-drive updates_per_hour=1000 >>"$core/add.out" 2>&1
    ok "the operator's copy is added and the token given by source key" $? "$(tail -c 300 "$core/add.out")"

    # -- the check: the file names no check call (every call takes the
    # drive), so the check looks at the credential and the program, and
    # sends nothing.
    : >"$core/requests"
    yrun source check infomaniak-drive >"$core/check.out" 2>&1
    rc=$?
    [ "$rc" = 0 ] && grep -q 'credential: INFOMANIAK_DRIVE_TOKEN is set' "$core/check.out" \
      && grep -q 'names no check call' "$core/check.out" \
      && grep -q 'command call.download.run (drive-file download): can be run' "$core/check.out" \
      && grep -q 'command call.upload.build (drive-file upload): can be run' "$core/check.out" \
      && [ ! -s "$core/requests" ]
    ok "source check says the credential is set and drive-file can be run, and sends nothing" $? "exit $rc: $(tail -c 300 "$core/check.out")"

    # A case file is sections, each opened by a line "=== name": args (the
    # call and its parameters, one word to a line; __CORE__ is this scratch
    # yard, __HERE__ the pack's directory), answer (the stand-in's body; a
    # line "@name" stands for testdata/answers/name.json) and status (its
    # HTTP status, 200 if left out). A download's bytes come from dl (a line
    # "@name" stands for testdata/downloads/name) with dlstatus and
    # dllocation beside it; without dl the download gets the answer.
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
      rm -f "$core/answer.json.status" "$core/answer.json.download" "$core/answer.json.download.status" "$core/answer.json.download.location"
      [ ! -e "$d/status" ] || cp "$d/status" "$core/answer.json.status"
      if [ -e "$d/dl" ]; then
        first=$(head -n 1 "$d/dl")
        case $first in
          @*) cp "testdata/downloads/${first#@}" "$core/answer.json.download" ;;
          *) cp "$d/dl" "$core/answer.json.download" ;;
        esac
      fi
      [ ! -e "$d/dlstatus" ] || cp "$d/dlstatus" "$core/answer.json.download.status"
      [ ! -e "$d/dllocation" ] || cp "$d/dllocation" "$core/answer.json.download.location"
      : >"$core/requests"
      set --
      while IFS= read -r word; do
        case $word in
          *__CORE__*|*__HERE__*) word=$(printf '%s' "$word" | sed -e "s|__CORE__|$core|g" -e "s|__HERE__|$here|g") ;;
        esac
        set -- "$@" "$word"
      done <"$d/args"
      yrun call infomaniak-drive "$@" --json >"$d/stdout" 2>"$d/stderr"
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
    rm -f "$core/answer.json.status" "$core/answer.json.download" "$core/answer.json.download.status" "$core/answer.json.download.location"

    # Of all the requests the cases made: each is a read of the drive's
    # files, a search, a comment listed or written, a share link made, or
    # the one upload. No other method, no other address: nothing deleted,
    # trashed, restored, renamed, moved, copied or granted access.
    cat "$core"/case_*/golden >"$core/all.golden"
    grep -c '^GET ' "$core/all.golden" >/dev/null
    ok "the cases made reads" $?
    ! grep -E '^[A-Z]+ ' "$core/all.golden" | grep -vE '^(GET /api/3/drive/[0-9]+/files/[0-9]+/files(\?[^ ]*)?$|GET /api/3/drive/[0-9]+/files/[0-9]+$|GET /api/3/drive/[0-9]+/files/search\?[^ ]*$|GET /api/3/drive/[0-9]+/files/[0-9]+/name\?[^ ]*$|GET /api/2/drive/[0-9]+/files/[0-9]+/comments\?[^ ]*$|GET /api/2/drive/[0-9]+/files/[0-9]+/download(\?[^ ]*)?$|POST /api/2/drive/[0-9]+/files/[0-9]+/(comments|link)$|POST /api/3/drive/[0-9]+/upload\?[^ ]*)$' | grep -q .
    ok "every request is a GET of a folder, a file, a search, a name, comments or a download, a POST of a comment or a link, or the upload" $?
    ! grep -E '^(PUT|PATCH|DELETE|HEAD) ' "$core/all.golden" | grep -q .
    ok "no request is a PUT, PATCH, DELETE or HEAD" $?
    # The upload goes as the service takes it: octet-stream with the
    # folder, the name, the size and conflict=error in the query.
    uploads=$(grep -c '^POST .*\/upload\?' "$core/all.golden")
    [ "$uploads" -gt 0 ] \
      && grep '^POST .*\/upload\?' "$core/all.golden" | grep -q 'directory_id=' \
      && grep '^POST .*\/upload\?' "$core/all.golden" | grep -q 'file_name=' \
      && grep '^POST .*\/upload\?' "$core/all.golden" | grep -q 'total_size=' \
      && grep '^POST .*\/upload\?' "$core/all.golden" | grep -q 'conflict=error'
    ok "the cases made an upload, and every upload POST carries directory_id, file_name, total_size and conflict=error ($uploads)" $?
    sed -n 's/^  body: //p' "$core/all.golden" >"$core/bodies"
    notjson=$(grep -c 'NOT JSON' "$core/bodies")
    [ "$notjson" = "$uploads" ]
    ok "every upload body is bytes, not JSON, and every other body is JSON ($notjson of $uploads)" $?
    grep -v 'NOT JSON' "$core/bodies" >"$core/jsonbodies"
    jq -s -e 'all(.[]; . == {"ok":true}
      or (keys == ["body"] and (.body | type == "string"))
      or . == {"right":"public"}
      or ((keys | sort) == ["password","right"] and .right == "password" and (.password | type == "string")))' "$core/jsonbodies" >/dev/null
    ok "every JSON body is the confirm's {ok:true}, a comment's {body:[one text]} or a link's {right[, password]}" $?
    ! grep -E '^  (accept|content-type|user-agent): ' "$core/all.golden" | grep -vE '^  (accept: application/json|content-type: (application/json|application/octet-stream)|user-agent: yardr)$' | grep -q .
    ok "every request asked for JSON or sent bytes where it had them, and named yardr as its User-Agent" $?
    ! grep -q 'auth: WRONG\|auth: missing' "$core/all.golden"
    ok "every request carried the token as a bearer token" $?

    # -- the token is in the one file that holds it, and nowhere else
    kill "$standin_pid" 2>/dev/null
    standin_pid=
    envfile=$core/y/sources/infomaniak-drive.env
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
