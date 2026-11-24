# The request yardr makes for a call of microsoft.yaml, and the answer it
# keeps, built from the declaration as data. Input: {decl, call, given,
# answer}, where decl is microsoft.yaml read as JSON, given the call's
# parameters as the command line gives them (name=value, so all strings)
# and answer a recorded Graph answer. Output: {request, kept, bound}, or
# {request, answer: "file"} for a call whose answer is a file, or {error}
# where yardr refuses the call before sending it.
#
# It follows internal/source/call.go of yardr, read on 2 November 2026,
# and, for the call whose answer is a file, internal/source/download.go
# and callread.go, read on 24 November 2026, and stands in for them only
# where this pack's declaration uses them:
#   values       each parameter is held to its type, max and pattern, in
#                the order declared; a default stands in for a parameter
#                not given, and an optional one with none is left out
#   target       each {param} in the path becomes one escaped segment (the
#                values here never hold more than jq's @uri and Go's
#                url.PathEscape both escape alike); the query is sorted by
#                key and each side escaped as url.QueryEscape does, a space
#                being a +; a pair whose value is exactly {param} is left
#                out when the parameter was not given
#   fill         a body string that is exactly {param} becomes the
#                parameter's typed value, and is left out when the
#                parameter was not given; any other string has its
#                {param}s replaced by the text
#   headers      Accept, User-Agent, Content-Type with a body, and the
#                credential's header, with <token> for the credential
#   selected     an object answer keeps the named top-level keys
#   file         where the call says answer.file, the request is made as
#                any other is, with the same headers, and the answer is
#                the bytes of the last response, after the redirects Graph
#                answers with, so nothing of it is kept as JSON: select is
#                refused beside file, as yardr's reader refuses it, and the
#                file's bound is the yard's blob_max_bytes, which no
#                declaration holds (a max beside file bounds only the JSON
#                of a refusal that errors keeps, and this pack names none)
# yardr's own tests run these against a stand-in server; nothing here
# does, so it can only be as faithful as the reading above.

def mark: "\\{(?<n>[A-Za-z_][A-Za-z0-9_]*)\\}";
def exact: "^\\{(?<n>[A-Za-z_][A-Za-z0-9_]*)\\}$";

# a body with its {param}s filled; empty stands for "left out"
def fill($vals):
  if type == "object" then
    [to_entries[] | .key as $k | (.value | fill($vals)) as $v | {key: $k, value: $v}] | from_entries
  elif type == "array" then
    [.[] | fill($vals)]
  elif type == "string" then
    if . == "{credential}" then "<token>"
    elif test(exact) then
      capture(exact).n as $n | if $vals[$n] != null then $vals[$n].typed else empty end
    else gsub(mark; $vals[.n].text // "") end
  else . end;

def render:
  .decl as $d | .call as $name | (.given // {}) as $given
  | ($d.calls[$name]) as $c
  | ($c.params // {}) as $params
  | if $c == null then error("the source has no call of that name") else . end
  # values
  | ([$given | keys_unsorted[] | select($params[.] == null)] | first // null) as $unknown
  | if $unknown != null then
      error("\($unknown | tojson) is no parameter of the call (it takes: \($params | keys_unsorted | join(", ") | if . == "" then "none" else . end))")
    else . end
  | ([ $params | to_entries[] | .key as $n | .value as $p
       | ($given[$n] // (if $p | has("default") then $p.default | tostring else null end)) as $s
       | if $s == null then
           (if $p.optional // false then empty else error("parameter \($n) is missing") end)
         else
           (if $p.type == "string" then
              (if $p.max != null and ($s | length) > $p.max then
                 error("parameter \($n) is \($s | length) characters, and at most \($p.max)")
               elif $p.pattern != null and ($s | test($p.pattern) | not) then
                 error("parameter \($n) does not match its pattern \($p.pattern)")
               else null end)
            elif $p.type == "int" then
              (if ($s | test("^[-+]?[0-9]+$") | not) then error("parameter \($n) is no whole number") else null end)
            elif $p.type == "bool" then
              (if $s != "true" and $s != "false" then error("parameter \($n) is true or false") else null end)
            elif $p.type == "enum" then
              (if ($p.values | index($s)) == null then error("parameter \($n) is one of \($p.values | join(", "))") else null end)
            else error("parameter \($n) has no type") end) as $_
           | {key: $n, value: {text: $s, typed: (if $p.type == "int" then ($s | tonumber) elif $p.type == "bool" then ($s == "true") else $s end)}}
         end
     ] | from_entries) as $vals
  # target
  | ($c.request.path | split("/")) as $segs
  | (if any($segs[]; test(mark) and ((gsub(mark; $vals[.n].text // "")) | . == "." or . == "..")) then
       error("a parameter makes a segment of the path that leaves the source's base")
     else . end)
  | ($segs | map(if test(mark) then gsub(mark; ($vals[.n].text // "") | @uri) else . end) | join("/")) as $path
  | ([ ($c.request.query // {}) | to_entries[]
       | .key as $k | .value as $v
       | if ($v | test(exact)) and ($vals[($v | capture(exact).n)] == null) then empty
         else {k: $k, v: ($v | gsub(mark; $vals[.n].text // ""))} end
     ] | sort_by(.k)
       | map("\(.k | @uri | gsub("%20"; "+"))=\(.v | @uri | gsub("%20"; "+"))")
       | join("&")) as $query
  | (($d.base | rtrimstr("/")) + $path + (if $query == "" then "" else "?" + $query end)) as $url
  # body and headers
  | ($c.request.body | if . == null then null else fill($vals) end) as $body
  | ($d.credential.header | capture("^(?<k>[^:]+): (?<v>.*)$")) as $auth
  | ({"Accept": "application/json", "User-Agent": "yardr"}
     + (if $body != null then {"Content-Type": "application/json"} else {} end)
     + {($auth.k): ($auth.v | sub("\\{credential\\}"; "<token>"))}) as $headers
  # the answer
  | ({method: $c.request.method, url: $url, headers: $headers} + (if $body != null then {body: $body} else {} end)) as $request
  | if $c.answer.file == true then
      (if $c.answer | has("select") then error("a file call has no select: there is no JSON to keep keys of") else . end)
      | {request: $request, answer: "file"}
    else
      ($c.answer.select // []) as $keys
      | (.answer | if ($keys | length) > 0 and type == "object"
                   then with_entries(select(.key as $k | $keys | index($k) != null))
                   else . end) as $kept
      | ($c.answer.max // 65536) as $bound
      | ($kept | tojson | utf8bytelength) as $len
      | if $len > $bound then error("the answer is \($len) bytes, over the call's bound of \($bound)") else . end
      | {request: $request, kept: $kept, bound: $bound}
    end;

try render catch {error: .}
