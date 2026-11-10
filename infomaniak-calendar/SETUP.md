# Setting up Infomaniak Calendar

The pack wires Infomaniak Calendar into the yard as the declared source
`infomaniak-calendar`: the calendars listed, a calendar's events listed in a
window and read, and timed events created and edited without inviting anyone.
Each call goes out with a token you make in Infomaniak's manager and type
unseen, so nothing is minted and no new copy of a secret is stored beyond the
one file only you can read. It is the twin of `google-calendar`, with that
pack's call names and arguments where the service has a counterpart; README.md
says where it has none, and what was and was not tried against the live
service (nothing was).

Every crew member granted a call acts as the one Infomaniak user the token was
made for. The token can do more than the pack's five calls, whatever the
yard grants: make it for a user whose calendars the yard may touch.

1. **The token, in Infomaniak's manager.** Log in to the manager, open the
   token list, and create a token:
   - Where: the token link in [Infomaniak's guide to API tokens (FAQ 2582)](https://www.infomaniak.com/en/support/faq/2582)
     resolves to `https://manager.infomaniak.com/v3/ng/profile/user/token/list`.
     I checked the link on 10 November 2026; the manager requires a login, so
     its contents were not inspected. The calendar MCP server's README still
     names `https://manager.infomaniak.com/v3/ng/accounts/token/list`.
   - Name it for the yard, and choose the scopes `workspace:calendar` and
     `user_info`, the pair that MCP server's README asks for.
   - The validity is unlimited unless you set one. A token is switched off after
     a year unused, and is revoked from the same list.
   - The manager asks for your account password, then shows the token once.
     Copy it for step 4. It goes in no file, note or message.
2. **Apply the pack.** As the operator, in a terminal. It shows the plan, the
   digest and the one program the pack runs as you,
   `infomaniak-calendar/build-edit`, which needs `curl` and `jq`, and asks:
   ```sh
   yardr pack apply /Users/mckean/projects/repos/yardr-packs/infomaniak-calendar
   # applied pack infomaniak-calendar to the yard: 1 created, 0 changed, 0 unchanged
   # source infomaniak-calendar is declared: 5 calls under https://api.infomaniak.com (yardr source show infomaniak-calendar)
   ```
3. **The setup card.** There is none for this pack. `yardr bead ask <bead> -
   --setup <pack> --crew <name>` makes one card of the apply, the account and
   the grants, but only for a pack yardr carries in its binary, as it does
   `google-calendar`. For a pack that is a directory, as this one is, yardr
   answers `pack infomaniak-calendar: yardr embeds no pack of that name: a pack
   that is a directory, a URL or an earlier import's record is the operator's
   to apply in a terminal` (tried on 10 November 2026, with the yardr build
   f17535e92091). So the setup is the steps around this one: the apply above,
   the token (step 4) and the grants (step 5), which a crew member can ask for
   on a card each. A single card would need the pack embedded in yardr, which
   is a bead of the yardr depot.
4. **The token, given to the yard.** The operator types it unseen: the command
   asks for the value and shows nothing as it is typed or pasted, and the
   yard's server writes it to
   `~/.yardr/sources/infomaniak-calendar.env`, a file only you can read.
   ```sh
   yardr source key infomaniak-calendar
   # source infomaniak-calendar: INFOMANIAK_CALENDAR_TOKEN is set in ~/.yardr/sources/infomaniak-calendar.env
   ```
   Or have a crew member ask for it, and answer on its card, in footplate or in
   `yardr chat` (`ctrl+o`), where the field shows dots. The card names where
   the token goes, `https://api.infomaniak.com`, and the answer on the bead
   holds the name given and never the value:
   ```sh
   yardr bead ask <bead> "The Infomaniak token for the calendar" --secret infomaniak-calendar --context "In Infomaniak's manager, the token list: a token with the scopes workspace:calendar and user_info."
   ```
   The yard sends the token to the host it was given for and to no other: a
   copy of the declaration that names another base is refused before anything
   is sent, until the token is given again.
5. **The grants.** A pack of kind source asks none at import, so what a crew
   member may call is granted afterwards. `yardr pack show infomaniak-calendar`
   prints the sets the pack suggests: `read`, the three read calls (`calendars`,
   `events` and `event`, and any read call the source is later given);
   `create`, those and `create`; `everything`, those and `edit`. Those sets
   cannot be granted by name for a pack applied from a directory, so each
   call is granted by its own, and the operator types them:
   ```sh
   yardr source grant infomaniak-calendar read --crew yardmaster
   ```
   ```sh
   yardr source grant infomaniak-calendar create --crew yardmaster
   ```
   ```sh
   yardr source grant infomaniak-calendar edit --crew yardmaster
   ```
   `read` covers every read call and no update; `create` and `edit` each change
   something in the calendar and are granted by their names alone. A grantee
   who comes later gets one card for each grant, which a crew member asks
   for:
   ```sh
   yardr bead ask <bead> "Let the reviewers read Infomaniak Calendar" --run "source grant infomaniak-calendar read --group reviewers" --context "The reviewers list and read calendar events to check a bead's work; the card names each call it covers."
   ```
   `yardr source show infomaniak-calendar` lists each call with its kind and
   who may make it.
6. **The limits.** Infomaniak allows 60 requests a minute. The yard holds a
   caller to 60 calls an hour of a source and 10 of them updates, which is
   stricter; an `edit` is two requests to Infomaniak, the read and the write.
   If the crew needs more, the operator raises them:
   ```sh
   yardr source set infomaniak-calendar calls_per_hour=300
   ```
7. **Check it.** The source's check call lists the calendars with the token the
   yard was given, and the check says whether `edit`'s program can be run:
   ```sh
   yardr source check infomaniak-calendar
   # infomaniak-calendar: credential: INFOMANIAK_CALENDAR_TOKEN is set in ~/.yardr/sources/infomaniak-calendar.env
   # infomaniak-calendar: check call calendars (GET /1/calendar/pim/calendar): 200 in 412ms, 214 bytes
   # infomaniak-calendar: data: {"calendars":[{"id":41,"name":"Personal","default":true}]}
   # infomaniak-calendar: command call.edit.build (infomaniak-calendar/build-edit): can be run
   ```
   The listing is where the calendar ids are: every other call that names a
   calendar takes the number `id` shown there, and the calendar marked
   `default` is the account's own. A 401 or a 403 says the service did not
   take the token for the calendar: it was revoked, was made for another
   account, or lacks the scope `workspace:calendar`. (The lines above are the
   shape of an answer, not one the service gave: see README.md.)
8. **Try it.** As the operator, who may make any call: the calendars, a week's
   events, one event read, an event created:
   ```sh
   yardr call infomaniak-calendar calendars
   ```
   ```sh
   yardr call infomaniak-calendar events calendarId=<an id calendars showed> timeMin="2026-11-16 00:00:00" timeMax="2026-11-23 00:00:00"
   ```
   ```sh
   yardr call infomaniak-calendar event eventId=<an id the listing showed>
   ```
   ```sh
   yardr call infomaniak-calendar create calendarId=<an id> summary="Lunch with Ada" start="2026-11-20 12:00:00" end="2026-11-20 13:00:00" timezone=Europe/Zurich location="Cafe Roma"
   ```
   An edit changes only what it names; the event is read first and sent back
   whole, so what it leaves out stays, its attendees and alarms included:
   ```sh
   yardr call infomaniak-calendar edit eventId=<the id create answered with> location="Cafe Novo"
   ```
   A time is a wall clock, `YYYY-MM-DD HH:MM:SS`, with no offset: in the
   account's own timezone for `events`, in `timezone` (an IANA name) for
   `create`, and in the event's own timezone for `edit`. An event created or
   edited invites no one and notifies no one.

What is not there, on purpose: inviting anyone (no attendees, and
`notifyAttendees` is false); moving or deleting an event; all-day events and
recurrence (an edit refuses an event that recurs, and the times of an all-day
one); booking a room; the address book; searching or paging an events list;
the kMeet meeting call; the CalDAV fallback at `sync.infomaniak.com`; and any
call the pack does not list. The yard's source format cannot express what is not
listed, and the pack does not change yardr.
