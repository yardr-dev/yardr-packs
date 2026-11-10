# Infomaniak Calendar

Infomaniak Calendar as a pack of kind source, for a yard whose crew reads and
writes a calendar there. An agent lists the calendars, lists a calendar's events
in a window, reads one event, and creates and edits timed events without
inviting anyone. It is the twin of `google-calendar` (in the yardr repository):
the same call names, and the same arguments where Infomaniak has a counterpart.
The yard acts as one Infomaniak user, with a token made in the manager and typed
unseen. Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/infomaniak-calendar
```

SETUP.md is the operator's steps. **Nothing in this pack has been tried against
Infomaniak's service**: there was no account to try it on. "What was checked, and
what was not" says what the tests hold and what is left for the first live run.

## The calls

All five are declared in `infomaniak-calendar.yaml`, against
`https://api.infomaniak.com`. The routes are those of Infomaniak's own MCP server
for its calendar, which is the only place they are written down: they are not in
developer.infomaniak.com.

| call | kind | request | arguments |
|---|---|---|---|
| `calendars` | read | `GET /1/calendar/pim/calendar` | none. The check call |
| `events` | read | `GET /1/calendar/pim/event?calendar_id&from&to` | `calendarId`, `timeMin`, `timeMax` |
| `event` | read | `GET /1/calendar/pim/event/{eventId}` | `eventId` |
| `create` | update | `POST /1/calendar/pim/event` | `calendarId`, `summary`, `start`, `end`, `timezone`; `description`, `location` optional |
| `edit` | update | `GET`, then `PUT /1/calendar/pim/event/{eventId}` | `eventId`; any of `summary`, `start`, `end`, `description`, `location` |

Every answer keeps the service's `result` and `data`, and its `error` where it
sends one, so that a failure it answers with a 200 is seen and no write reads as
done with an empty answer (a 4xx or 5xx is refused by the yard, which shows the
status alone). `data` is, for `calendars`, `{calendars: [{id, name, default}]}`;
for `events` the list of events; for the others one event or what the service
answered. An event is the service's own, with the fields its client
names: `id`, `calendar_id`, `title`, `description`, `start` and `end` as text,
`timezone_start` and `timezone_end`, `location`, `color`, `freebusy`, `type`,
`fullday`, `private`, `attendees` (each with `address`, `name`, `state`,
`organizer`), `alarms`, `attachments`, `rrule`, `meet_room_url` and
`bookable_resource_id`. A title, a description or a location is text somebody
else may have written (an invitation is one), so `yardr call` prints each
answer as data from outside the yard, not as instructions.

**Times.** The service takes a wall clock, `YYYY-MM-DD HH:MM:SS`, and what it
means is the account's profile timezone. Its client turns any value with an
offset into that wall clock first, from the profile (`GET /2/profile`), and a
declared call cannot. So `timeMin`, `timeMax`, `start` and `end` take that form
alone: no `T`, no offset. An RFC 3339 value is refused before anything is sent,
with the pattern in the refusal. `events` reads the window in the account's own
timezone. `create` takes `timezone`, an IANA name such as `Europe/Zurich`,
because the body names the zone (`timezone_start` and `timezone_end`); the
account's own zone is in its profile, and any event's `timezone_start` shows it.
`edit` keeps the zones the event has, and the wall clock it is given is in them.

**`edit`.** The service's update is a PUT of the whole event, and no patch: its
client reads the event, changes it, and sends every field back, and its tests say
that a PUT without `location` and `color` lost them. A declared body cannot read
first, so `edit` names a build command, `infomaniak-calendar/build-edit`, as
`google-mail`'s drafts name `build-draft`. It reads the event with the token,
changes only the fields the call gave, sends the attendees, the alarms, the
location, the colour and the rest back as they were, and sets `notifyAttendees`
and `imip_request` false, so no mail goes about the change. An edit is therefore
two requests to Infomaniak. It refuses, in words and with nothing sent:

- a call that gives nothing to change;
- an event it cannot read (the service's reason is shown when it gives one);
- an event with no timezone, because the body needs one and the profile's is not
  read here;
- the times of an all-day event, whose start and end are the service's other
  shape: its title, description and location can still be changed;
- an event that recurs, because a PUT of it would change the series where
  `google-calendar`'s patch changes one occurrence, and no call here names an
  occurrence.

## Against google-calendar

Where the twin has no counterpart here, the declaration leaves it out and says so
in its head comment. A role written for `google-calendar` needs these changes:

| `google-calendar` | here |
|---|---|
| `calendarId=primary`, or a calendar's address | the id `calendars` lists, which has a digit in it; the calendar marked `default` there is the account's own, and `primary` is refused |
| `calendarId` on `event` and `edit` | not taken: their routes name the event alone, and `edit` never moves an event to another calendar |
| `timeMin`, `timeMax` as RFC 3339 with a zone | `YYYY-MM-DD HH:MM:SS`, in the account's timezone |
| `start`, `end` as RFC 3339 with a zone | `YYYY-MM-DD HH:MM:SS`, with `timezone` on `create`, and the event's own zone on `edit` |
| `q`, `maxResults` on `events`, and a page of at most 50 | not there: the client sends neither and reads the one answer the service gives, so no paging is declared. A window too big for the answer's bound (256 KB) is refused, not cut: ask for less |
| an answer of `{items, nextPageToken}`, and events with `summary`, `start.dateTime`, `attendees[].email`, `htmlLink` | `{result, data}`, and the service's own events: `title`, `start` as text, `attendees[].address` and `state`; no link to the event |
| `edit` patches the fields given | `edit` reads the event and sends it whole, changed in the fields given |
| `sendUpdates=none` | no attendees on a created event, `notifyAttendees` false, and `imip_request` false on an edit |
| recurring events listed as instances | the service's events as it answers them; a recurring event is read and never edited here |

## What it never does

Invite anyone: `create` sends `attendees: []` and `notifyAttendees: false`, and
names no parameter for either, and `edit` sends no mail. Delete or move an event,
share a calendar, book a room, set a recurrence, create an all-day event, search,
page past one answer, or read the address book. The declaration's calls are the
five above; the yard's source format cannot express a call it does not list, and
the pack does not change yardr. The tests hold the five as data: no `DELETE`, no
`PATCH`, nothing outside `/1/calendar/pim`.

## Files

- `pack.yaml`: the pack, kind source, and the presets `read`, `create` and
  `everything`, as the twin has them. A pack applied from a directory takes no
  `--preset` grant, so SETUP.md grants each call by its name and the presets only
  show in `yardr pack show`.
- `infomaniak-calendar.yaml`: the declaration, and the record of what was read and
  when.
- `infomaniak-calendar/build-edit`: the program `edit` names.
- `SETUP.md`: the operator's steps, from the token to a first call.
- `test` and `testdata/`: see Testing.

## Runtimes

`edit` runs `infomaniak-calendar/build-edit` as the yard's user, with `bash`,
`curl` and `jq` on the daemon's `PATH`. The token reaches curl as a config line on
its stdin, never in an argument. Nothing else in the pack is a program: the other
four calls are declared requests, which the yard makes itself.

## Testing

`./test` needs `jq`, `curl`, `python3` and `yardr`, no network and no secret, and
takes a few seconds. The gate runs it beside `yardr pack check`.

- `build`: `build-edit` by itself against a stand-in for the service on a
  loopback port (`testdata/standin.py`), one `testdata/build/*.case` each: the
  event it reads, the body it prints, and each refusal. It never makes a request
  but a GET, and the token is in no output of it.
- `core`: the real yardr in a scratch yard. The declaration as the yard reads it,
  the grants SETUP.md teaches (read out of SETUP.md and run as written), the check
  call, and one `yardr call` for each `testdata/calls/*.case` against the same
  stand-in. A golden holds the requests the stand-in saw (method, path and query
  as they arrived, and the body of a write), the status, what the call kept of
  the answer, and what it said on stderr.
- The token is made for the run, from random bytes, and thrown away: the stand-in
  says only whether a request carried it, and the test checks that it is in the
  env file the yard wrote and in no other file or output.

`UPDATE_GOLDEN=1 ./test` writes the goldens again from what the programs print;
read the diff before keeping it.

## What was checked, and what was not

Read on 10 November 2026: Infomaniak's MCP server for its calendar
(`github.com/Infomaniak/mcp-server-calendar`, main at `358a61c`, whose last
commit is of 3 November 2026), namely `src/calendar-client.ts`, `src/index.ts`, `README.md`,
`tests/verify.mjs`, `tests/timezone.test.mjs` and `tests/fixtures/timezone-probe.mjs`;
and Infomaniak's guide to API tokens (FAQ 2582). Nothing was sent to the service.

Checked offline, by `./test` and the gate:

- that the declaration reads, applies, and sends what it says: the method, the path,
  the query (the wall clock as `from=2026-10-20+00%3A00%3A00`) and the body of each
  call, with the token as a bearer, and refuses what its patterns refuse before
  anything is sent (an RFC 3339 time, `primary`, an attendee, a delete);
- that `edit` reads and then writes, and what it writes: only the given fields
  changed, the event's attendees, alarms, location, colour and zones sent back, and
  nobody notified;
- the grants SETUP.md teaches, the check call, and `source check` finding
  `edit`'s program;
- that `yardr bead ask ... --secret infomaniak-calendar` and the grant card
  `--run "source grant infomaniak-calendar ..."` are taken, and that
  `--setup infomaniak-calendar` is refused, with yardr build `f17535e92091` in a
  scratch yard (SETUP.md step 3 says why).

The fixtures in `testdata/answers` are shaped after that client's code and tests,
and are **not recorded from the service**. The client shows the fields it reads and
sends, so those are in them; what it does not show is made up where a test needs a
value (an alarm's members, the answer of a POST and of a PUT, the shape of an
error). The test therefore holds the pack to the client's reading of the service,
not to the service.

Not tried, and what to look at in the first live run with a token, in the order
of what would break most:

- **`edit`.** That the service takes the PUT body `build-edit` makes, and keeps
  what the body sends back; that `notifyAttendees: false` and `imip_request: false`
  send nothing to an event's attendees; what it answers; and what an event of
  another account's, or a read-only calendar's, does to it.
- **Times.** That `from` and `to` as `YYYY-MM-DD HH:MM:SS` are read in the profile
  timezone as the client's README says, and that a created event shows at the time
  and in the zone given. Whether the service would take an RFC 3339 value, which
  would let the pack take the twin's form.
- **The shapes.** Calendar ids (the client's delete handles one that is a number or a
  text; the pattern takes both, with a digit in it), the fields of an event, what `calendars`
  answers beyond `id`, `name` and `default`, whether `location` is taken on a create
  (the client's create never sends one and its update does), and the error body
  (`build-edit` reads `error.description`, which is Infomaniak's usual shape and
  not one the client shows).
- **Windows.** Whether a long window is cut or paged, and how recurring events are
  listed: as instances or as their parent.
- **The token.** That `workspace:calendar` alone is enough or `user_info` is needed
  (no call here reads the profile; both are asked for, as the MCP server's README
  says); and what a 401 and a 403 look like. The manager link in [Infomaniak's
  FAQ 2582](https://www.infomaniak.com/en/support/faq/2582) resolves to
  `https://manager.infomaniak.com/v3/ng/profile/user/token/list` (checked
  10 November 2026); the manager's contents require a login. The MCP server's
  README names `.../accounts/token/list` instead, which was not reachable without
  signing in.
- **The limit.** 60 requests a minute is the figure of the proposal these packs come
  from, which read it in the developer portal; the portal needs a script to show its
  pages, and was not read again here.

## Left out

On purpose: kMeet's call that schedules a meeting with its calendar event (later,
one more update); the CalDAV fallback at `sync.infomaniak.com` (a bead of its own,
only if these calls prove unstable); a mint (the token lasts until it is revoked
and is switched off after a year unused); a delete; attendees; rooms; the address
book; the profile; a webhook, which the service has none of for the calendar; and
the single setup card, which yardr gives only to a pack it embeds.
