# Snowflake

Snowflake as a pack of kind source, for a yard that answers a data question from
a warehouse. An agent runs a SELECT through Snowflake's SQL API and reads its
first page of rows, lists the databases, schemas and tables, and reads a
statement back by its handle. One call, kept apart, runs any other statement.
The yard acts as one Snowflake user, signed in with a key pair. Nothing here is
compiled into yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/snowflake
```

SETUP.md is the operator's steps, including the SQL that makes the user and the
role. `jira` in this repository is the pattern (a minted credential, a
placeholder base), and this file says where Snowflake differs.

## How it hangs together

**The calls.** All six go to one path of the account, `/api/v2/statements`, and
are declared in `snowflake.yaml`.

| call | kind | request | what it sends |
|---|---|---|---|
| `query` | read | `POST` | `statement`, which must begin with `SELECT` (case and leading space free); `timeout`, 60 s unless given; `database`, `schema`, `warehouse`, `role`, each optional; `async` |
| `databases` | read | `POST` | `SHOW DATABASES`; `warehouse`, `role` optional. The check call |
| `schemas` | read | `POST` | `SHOW SCHEMAS IN DATABASE {database}` |
| `tables` | read | `POST` | `SHOW TABLES IN SCHEMA {database}.{schema}` |
| `status` | read | `GET /api/v2/statements/{handle}` | the handle, a UUID |
| `execute` | update | `POST` | any one `statement`, with the options of `query` |

`database`, `schema`, `warehouse` and `role` are plain identifiers
(`^[A-Za-z_][A-Za-z0-9_$]*$`, 255 characters at most), which is also what keeps
`schemas` and `tables` from writing anything but a name into the statement they
build. A name that needs quotes is not accepted there; `query` on the database's
`INFORMATION_SCHEMA` reaches it. Left out, the options are the user's own
defaults, since Snowflake falls back to them and the file gives none.

**The answer.** `statementHandle`, `resultSetMetaData` (the columns in
`rowType`, `numRows`, `partitionInfo`) and `data`, the rows, every value a
string whatever its type, as Snowflake writes them. Only the first partition of
a result comes back: Snowflake splits a large result into partitions of its own
size, and the others are fetched with `?partition=N`, which no call here makes.
The metadata says when there is more (`numRows` is the whole result, the first
`partitionInfo` the part that came), so a statement is written with a `LIMIT`,
and an answer over 256 KB is refused, not cut. The code, message and times a
ResultSet also carries are left out; `status` keeps them.

**A statement that runs long.** A call ends after 30 seconds, and Snowflake
hands back a statement's handle (a 202) only after 45. So a statement that takes
30 to 45 seconds ends its call with a timeout and no handle, and Snowflake runs
it on, up to its `timeout` (60 s unless given). `async=true` on `query` or
`execute` is the way out: the request answers its handle at once, and `status`
polls it. A running statement answers with a code, a message and no data; a
finished one answers with its rows, as `query` does; a failed one is refused as
422, and a statement cut by its timeout as 408, on the request that made it and
on `status` after it. `async` is optional and left out of the request unless it
is given. It is there because without it the 202 that `status` exists to follow
could never be seen.

**The credential.** Snowflake takes a key-pair login as a JWT signed with the
user's private key, which lives an hour at most. `snowflake/mint` makes one from
three names that are no secret, the account identifier, the user and the path of
the key file, and the key itself is no variable and in no file the yard writes.

| claim | value |
|---|---|
| header | `{"alg":"RS256","typ":"JWT"}` |
| `iss` | `<ACCOUNT>.<USER>.SHA256:<fingerprint>`, the fingerprint the base64 of the SHA-256 of the public key's DER: the `RSA_PUBLIC_KEY_FP` of `DESCRIBE USER` |
| `sub` | `<ACCOUNT>.<USER>` |
| `iat`, `exp` | now, and 59 minutes on |

`ACCOUNT` and `USER` are uppercase. The account is written as Snowflake's
page on the token says: a period of `organization.account` becomes a hyphen
(`myorg-acct1` and `myorg.acct1` are the same), and a locator loses its region
(`xy12345.us-east-2.aws` is `XY12345`). The page's Python sample treats a
period differently, by cutting the identifier at the first one; the page's
prose is what is followed here. The core stops
using a token five minutes before it expires, so the mint is run about once an
hour. Header `X-Snowflake-Authorization-Token-Type` is not sent: the pages say
Snowflake examines the token when it is left out, and a declared header takes
one value.

The mint refuses with one fixed line that quotes no input, and nothing on
stdout, for a missing or malformed name, a key path that is not absolute, or is
no readable regular file, a key that has a passphrase (it is refused, and not
asked for), is not RSA or is no key, and a PATH without `jq` or `openssl`.

**The base.** An account is per operator, so the declaration ships the
placeholder `https://example.snowflakecomputing.com` and SETUP.md has the
operator write their own into the yard's copy, as jira's does. A pack applied
again puts the placeholder back; the credential is held back from it, so
nothing is sent to a host nobody owns, and SETUP.md step 7 says how to notice.

**Writing, kept apart.** `execute` is the one update call. It is granted by its
name alone, which is how an update call is granted: `read` covers none. The pack
suggests two presets, `read` (`[read]`) and `write` (`[execute]`), and a grantee
who needs both is given both. A preset names `read` or a call, and `update` is
no word of either, so `write` grants `execute` by its name. A pack applied from
a directory takes the grants by name (`yardr source grant snowflake execute
...`), since `--preset` is for a pack inside yardr's binary.

What the user's role may do is the bound. `query` accepts a SELECT only, which
catches a mistaken `INSERT` and stops nothing a SELECT can do; it does not stop
`SELECT 1; SELECT 2` either, but Snowflake takes one statement to a request
unless the request sets a statement count, and the file never does. A role that
cannot write answers `execute` with 422. The trial account's role is read-only,
so `execute` is tested against fixtures and has never been called live.

**No idempotency key.** Snowflake takes one as the `requestId` of the request's
query (with `retry=true`), and a declared source's idempotency header cannot
carry a query, so a call tried again after a lost answer may run twice. Do not
retry an `execute`: pass `async=true`, and read what became of it from `status`.

**What a refusal shows.** The core keeps no body of a request the service
refused, in case the body repeats the request. For Snowflake that is the reason
a statement failed: a SQL error comes back as 422 and the call says "the service
answered 422", with the error text lost. An agent that writes SQL has the
columns from `resultSetMetaData` and the tables from `tables`, and has to guess
at a mistake. It is the core's rule and not this pack's to change.

## Files

- `pack.yaml`, `snowflake.yaml`: the pack with its `read` and `write` presets,
  and the declaration.
- `snowflake/mint`: POSIX sh, `openssl` and `jq`, the token from the key. The key
  is read by `openssl` from its path. The token is built by the shell and printed
  by `printf`, a builtin, so it is on no argument list, and nothing but a fixed
  line reaches stderr.
- `live-check`: the pack against a real account, in a scratch yard of its own,
  by hand: see below. It is not part of `test`.
- `testdata/`: the answers (`answers/*.json`, ResultSet, QueryStatus and error
  bodies written from the reference's shapes, not recorded from an account), the
  cases (`calls/*.case`) and their goldens, a stand-in for Snowflake
  (`standin.py`), the scratch-yard part of the test (`core.sh`), and the
  declaration's and the check's goldens.
- `.gitignore`: the operator's copy of the declaration, `snowflake.local.yaml`.

## Runtimes

`snowflake/mint` needs `sh`, `openssl` and `jq` 1.6 or later, on the PATH the
yard's server has. The whole test passes with the `openssl` macOS ships
(LibreSSL 3.3), with OpenSSL 3.6 and with OpenSSL 4.0, and the mint runs under
macOS's `sh` and under `dash`. The test needs those tools, and `yardr` and
`python3`; without one it fails and says which, since a skipped part would leave
the calls unpinned.

## Testing

```sh
./test
```

in this directory, about five seconds, no network and no secret. The gate
(`.yardr/test`) runs `yardr pack check` first.

- `mint`: eight forms of account identifier against a key pair made for the
  run and thrown away (the claims, the header, the fingerprint worked out
  apart in python, iat now and exp 59 minutes on, the signature verified
  against the public key with `openssl`, `expires_at`), and the refusals above,
  each with its one fixed line. No run writes a file, and no key byte, key path
  or input reaches an output.
- the declaration as the yard reads it, against `testdata/declaration.golden`;
  the kinds (five reads, `execute` the update); `pack show`'s two presets; the
  grants SETUP.md teaches, read out of it and run as written.
- `testdata/calls/*.case`, each one `yardr call` made by the real yardr against
  the stand-in, which answers the case's recorded-style body and status. A
  golden holds the request the stand-in saw (method, path and query, headers, the
  body), the exit status, what the call kept of the answer, and what it said.
  The cases are the six calls with their options, the first partition of a
  larger result, the 202 of a running statement, the 422, 408, 401 and 404 a
  refused request shows, and the values a call turns away before sending: a
  statement that is no SELECT, a comment or a `WITH` in front, an identifier
  with a dot, a space or a quote, a handle that is no UUID.
- the check call, and that the token the yard sent was made by `snowflake/mint`
  from the env file's names, is signed by the key and claims the account and
  user; and that the key's bytes are in no file of the yard and no token is.

`UPDATE_GOLDEN=1 ./test` writes the goldens again. Read the diff before you
commit it.

`./live-check <account identifier> [user [key file]]` is the pack against a real
account, and the one thing here that needs the network, the account and the key.
It runs the real yardr in a scratch yard of its own, applies the pack from its
directory, gives the three names as SETUP.md does, and makes the check call and
these reads: the databases, the schemas and tables of `SNOWFLAKE_SAMPLE_DATA`, a
SELECT of three rows, the status of that statement, the same SELECT with
`async=true` polled through `status`, and two statements Snowflake should
refuse. Every one is a SELECT or a SHOW; `execute` is never called. It prints
counts, column names and statuses, and never a token, a key or a row, and it
exits 1 if anything that should work did not.

## What was checked, and what was not

Checked on 3 November 2026 against Snowflake's pages (authenticating,
submitting requests, handling responses, handling errors and the reference): the
claims and the fingerprint, the header and the token-type header, the body of a
statement and the meaning of `timeout`, the `async` parameter and the 45 seconds,
the 200, 202, 408 and 422 answers and their fields, `GET` of a handle, and
partitions.

Checked the same day against a Snowflake trial account (an organization-account
identifier, a service user with a key pair, a role that only reads), by
`./live-check` through the real yardr in a scratch yard, and once more by hand
for the long statement below. Everything it made was a SELECT or a SHOW:

- the token is taken: the claims `<ORGANIZATION>-<ACCOUNT>.<USER>` and the key's
  fingerprint, signed RS256, with no token-type header and with the
  `User-Agent: yardr` that is all the core sends;
- `SHOW DATABASES`, `SHOW SCHEMAS IN DATABASE` and `SHOW TABLES IN SCHEMA` are
  taken as statements of the API, and answer their columns and rows (`databases`
  is the check call, and answered 200);
- `query` answers a SELECT's columns and rows, and `status` of its handle
  answers the same rows with the code `090001`;
- a second statement in a request is refused (422), as the pages' default of one
  statement says, and so is a mistake in a statement, with the reason not shown;
- a statement that runs past a call's 30 seconds ends the call with "nothing
  within 30s" and no handle (`SELECT SYSTEM$WAIT(35)` was the statement). With
  `async=true` the handle comes back at once; `status` then answers `333334`,
  "Asynchronous execution in progress", and no data while the statement runs,
  and its rows once it is done;
- a statement cut by its own `timeout` (a 10 second wait with `timeout=3`) is
  refused as 408 on the request that made it, and with `async=true` the
  `status` that follows it answers 408 too. The pages say that of the request
  only.

Not checked:

- `execute`, which has only been run against the stand-in: the trial's role
  grants no writes, and nothing is to be written there;
- an account named by its locator (`xy12345.us-east-2.aws`): the mint's reading
  of the forms is the pages' prose, tried offline on all of them;
- an account whose name has an underscore: the pages say nothing, and the mint
  leaves it as given.

## Left out

The metrics-report flow and a dbt depot (the demo's other pieces), cancelling a
statement, the other partitions of a large result, multi-statement requests and
transactions, the `requestId` that would make a retried write safe (nothing in a
declared source carries it), and the token-type header. A table's columns are
`query` on the database's `INFORMATION_SCHEMA`, so there is no call for them.
