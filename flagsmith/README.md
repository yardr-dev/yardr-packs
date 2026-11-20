# Flagsmith

Flagsmith feature flags through the Management API, read with one
organisation API token. As the declared source `flagsmith`, an agent
lists the organisations the token sees, the projects, a project's
environments and a project's flags, and reads an environment's flag
states: whether each flag is on and what value it carries. Calls are
read-only. Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /Users/mckean/projects/repos/yardr-packs/flagsmith
```

from main of this repository. SETUP.md is the operator's steps, written
for whoever runs Flagsmith for the team.

**Not tried against Flagsmith.** The pack was built from Flagsmith's
docs and the live Management API swagger and run against a stand-in.
No request has been made to api.flagsmith.com, because there is no
Flagsmith organisation in the yard yet. "What was checked" lists what
that leaves open, and the first call against a live organisation is the
real check.

## One identity for the yard

The yard reads as one organisation API token. Whatever the token may
read, every agent granted a call of this source reads, and the yard
does not narrow it per person. SETUP.md says this before its first
step and again at the grant, and sets a token with RBAC roles beside
a full organisation admin.

## The calls

All of kind read, and one preset, `read`, grants them.

| call | Flagsmith request | parameters | answers |
|---|---|---|---|
| `organisations` | `GET /organisations/` | none | `count`, `next`, `results`: each organisation with its `id`. The source's check call. |
| `projects` | `GET /projects/` | none | each project with its `id`, `uuid`, `name` and `organisation`. |
| `environments` | `GET /environments/?project={id}` | `project` | `count`, `next`, `results`: each environment with its `id` and `api_key`. |
| `features` | `GET /projects/{id}/features/` | `project`; `search`, `is_archived` | `count`, `next`, `results`: each flag with its `id`. |
| `featurestates` | `GET /environments/{api_key}/featurestates/` | `environment`; `feature`, `feature_name` | `count`, `next`, `results`: each state with its `enabled`, `feature_state_value`, `feature` and `identity`. |

What is behind the table:

- `projects` is the bare list, which takes no parameter, because the
  nested `GET /organisations/{id}/projects/` answers an organisation
  object in the swagger and its shape stays unclear. Each project
  carries its `organisation` id, which matches the id `organisations`
  gave.
- `environments` filters the bare list by `project` for the same
  reason: the nested `GET /projects/{id}/environments/` answers a
  project in the swagger.
- `featurestates` is addressed by the environment's `api_key`, not its
  integer id: `environment` takes the key `environments` answers.
  The swagger holds it to a string of at most 100 characters and gives
  no pattern or example for it, so the call holds it to that alone.
- Integer ids take `^[0-9]+$` and are logged; `is_archived` is a
  strict `true` or `false`; `search` and `feature_name` are free text
  and their values are in no event.
- There is no paging. Every list answers its first page alone, keeps
  `next` as the sign of more and follows none, and drops `previous`,
  which is always null on page one. `count` says how many there are.
- A call's `select` keeps top-level keys only and cannot reach into
  `results[]`, so a paginated answer keeps its items whole within the
  call's bound, 64 KB. The bare-array `projects` keeps `id`, `uuid`,
  `name` and `organisation` of each entry. An answer over the bound is
  refused, not cut: narrow with `search`, `is_archived`, `feature` or
  `feature_name`.
- yardr hands an agent the status of a failed call and not
  Flagsmith's error body.

## What was checked

- Flagsmith's docs at docs.flagsmith.com, read on 20 November 2026:
  the Management API page (the API Explorer, the rate limit), the
  Authentication page (the organisation token from Organisation
  Settings, API Access; `Authorization: Api-Key <token>`; the SaaS
  base and self-hosted URLs; OIDC trust tokens), the Code Examples
  page (the header again, on a curl call), and the System Limits page
  (500 requests a minute on Management API endpoints,
  `USER_THROTTLE_RATE` self-hosted).
- The live Management API swagger,
  `https://api.flagsmith.com/api/v1/swagger.json` (346 paths), read
  on 20 November 2026: the five endpoints' paths, parameters and
  answer refs; the paginated `{count, next, previous, results}`
  shape; the organisation, project, environment (with `api_key`),
  flag and flag-state item shapes; and the two nested answer refs
  that are wrong (an organisation for a project list, a project for
  an environment list), which the declaration's head comment names.
- The declaration through the real yardr in a scratch yard against a
  stand-in (not committed): the pack applies, `source check` makes
  the check call with the token, and each of the five calls is made
  with `yardr call`, with and without its optional filters. The
  stand-in saw the five requests with the header, the sorted and
  escaped query and the trailing slashes the fixtures pin, and
  yardr's kept answers matched the fixtures' `kept`.

**Not checked: a live Flagsmith.** The stand-in follows the docs and
the swagger, not the service's answers. The first call against a live
organisation is the real check. Look at:

- whether the token is accepted and what status a wrong one gets.
- whether the five lists answer in the swagger's shapes, and what
  page size the first page holds: a wide page can come near the 64
  KB bound.
- the throttle: 500 requests a minute by default. From the docs;
  nothing here spent one.

## Limits

Flagsmith takes 500 requests a minute of its Management API
endpoints by default. A self-hoster changes it with the
`USER_THROTTLE_RATE` variable. yardr's own limit is per caller: one
caller makes 60 calls of a source in an hour, and the operator raises
it with `yardr source set flagsmith calls_per_hour=<n>`.

## Files

- `pack.yaml`, `flagsmith.yaml`: the pack, its one preset and its
  declaration. The declaration's header says what was checked against
  Flagsmith's docs and swagger and what was not.
- `SETUP.md`: the token, the host, the grants and the first calls.
- `test`, `testdata/`: the tests. `calls/` holds a fixture for each
  call (parameters, the request it must make, a recorded Flagsmith
  answer, what the call keeps, and parameters it must refuse);
  `render.jq` builds the request from the declaration. Ids and keys
  in the fixtures are made up, in the swagger's shapes.

## Runtimes

- The pack itself wants nothing installed: it carries no program.
- The test wants jq 1.6 or later, and ruby, python3 with PyYAML, or yq
  to read `flagsmith.yaml` as data. With none of them it fails and says
  so, since a skip would leave the requests unpinned. It wants no
  network and no secret, and runs in a few seconds.

## Testing

```sh
./test
```

in this directory. For each call, `render.jq` builds from the
declaration the request yardr sends for the fixture's parameters, the
way yardr's `internal/source/call.go` builds it, and what the call keeps
of the recorded answer, and the test compares both with the fixture,
which was written from Flagsmith's docs and swagger and not from the
declaration. It then compares the call names, kinds and base with what
`yardr pack check` reads of the same file.

For the grant, the test reads the `source grant` commands SETUP.md
teaches (step 4's, and the `--run` of its card) and runs each as written
against the yardr on PATH, in a scratch yard of its own with the pack
applied from its directory, as step 2 says. Each must be accepted. yardr
takes `--preset` only for a pack inside its own binary, so a SETUP that
teaches it fails there, with yardr's reason. Without a yardr the test
says so and goes on.

`render.jq` follows `call.go` as read, and its requests, queries,
headers and kept answers were confirmed with the real yardr against a
stand-in when the pack was written (see "What was checked"). The first
live run is the check on the rest.

## Left out

Switching a flag, changing a value and creating a flag (the second
bead, on mckean's word); segments, identities, edge, audit and
everything else in the swagger; paging past page one; OIDC trust
tokens (the organisation token alone). Each is a later bead, on
mckean's word.
