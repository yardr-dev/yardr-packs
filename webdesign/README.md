# Webdesign

A pack for a yard that wants design direction from agents, not an
implementation. A brief goes in, three design directions come out as standalone
HTML mockups with a screenshot of each, and a person picks one. Nothing is built
for real and nothing lands. Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/webdesign --depot <depot>
```

`yardr pack check /path/to/yardr-packs/webdesign --depot <depot>` shows what the
import would do first, and writes nothing. SETUP.md is the operator's steps.

The pack adds the bead type `mockup` beside the flows a depot already follows.
A depot on the design pack's document flow keeps it. One type follows one flow,
and the design pack's flow is for the type `design`, so a pack that reused that
type would have its import re-point every depot on the document flow. The type
`mockup` is this pack's own, and an import leaves every other type's flow, routes
and groups as they are.

## How it hangs together

```
backlog -> mockups
mockups -> pick on done | pick on question | backlog
pick -> picked | mockups | backlog
picked terminal
```

| stage | worked by | what happens |
|---|---|---|
| `backlog` | `backlog`, people | the bead waits until its brief says the subject, the audience, the primary job, the page, the reference sites, what is fixed and what is not wanted |
| `mockups` | `designers` | an agent commits three standalone pages, `mockups/<n>-<name>.html`, on the bead's branch, shoots each at 1280x800 (an app screen also at 390 wide), and puts the shots on one note that names each direction's family, type pairing and palette |
| `pick` | `decisions`, people | a person reads the shots and moves the bead to `picked`, back to `mockups` with a note, or to `backlog`; the yard puts a card on the bead offering these moves, and the person's words with the pick name the direction |
| `picked` | | the end: the bead closes |

`question` also leads to `pick`. A designer that cannot start without an answer
(no subject it can identify) says what it needs on a note, and the person
answers there and sends the bead back to `mockups`.

There is no assembly stage. The mockups stay on the bead's branch `yard/<bead>`
and the shots on its note, and the words of the pick name the direction.
Landing all three pages would put throwaways on the base, and landing one would
need another agent to take the other two out. A build from the pick is a bead of
its own, filed by hand when someone asks for one.

**Three directions that differ.** The designer's role asks for three families
(editorial, grid, poster, specimen and so on), and for each a type pairing, a
palette and one idea taken from something that only this subject has. The rule
is that no two directions share all three of family, type pairing and palette. A
brief that fixes the brand's colours or typefaces keeps them in all three, and
the families carry the difference.

**The shots.** The designer serves the worktree on a free loopback port, shoots
each page with `contrib/shot/shot` from a yardr checkout, confirms each PNG is
1280 x 800 and not empty, and opens each one. That last step is not optional. In
24 shots of one throwaway page whose typeface came from a CDN (loaded two ways,
with `display=swap` and with `display=block`), two were wrong, one in a fallback
face and one blank, because Chrome took the shot before the font arrived. Both
passed the size check.

**App screens.** The designer first decides whether the brief is for a page,
which people read, or an app screen, which people work in: a dashboard, a
back-office or reporting view, settings or billing, an inbox. For an app screen
the role adds rules (the screen's question first, quiet panels, aligned figures,
colour spent on data, believable data, a phone layout where the navigation folds
away) beside its families and house style, and the three directions still differ
by family, type pairing and palette. An app screen is shot twice, always: at
1280x800 and, with `SHOT_WIDTH=390`, at phone width, so the note carries six
shots and the stage's exit does not depend on a judgement call.

## What it needs

- **An agent for `<depot>-designers`.** The import asks for its kind, model and
  permission arguments, as it does for any agent group it makes. The group is
  the pack's own and not the depot's `builders`: a pack names a group together
  with its role, so naming `builders` would aim the depot's code builders at a
  designer's prompt. One designer works at a time, and `yardr group set
  <depot>-designers --limit 2` allows more.
- **The yard's two people groups**, `backlog` and `decisions`, which the import
  reuses when the yard has them and asks for the members when it does not.
- **A crew member called `yardmaster`**, or another that takes the name
  (`--crew yardmaster=<name>`). It hears a bead enter `pick`, a bead close, and
  the events that need someone. The pack carries no role for it, so the
  yardmaster keeps its prompt.
- **On the yard's machine**, for the shots: headless Chrome (or `SHOT_CHROME`),
  `curl`, `python3` and a yardr checkout. An app screen's phone shots need a
  checkout whose `contrib/shot/shot` takes `SHOT_WIDTH` (yardr 9c94ab8, 4
  November 2026, and after); an older script ignores it and shoots 1280 wide. The
  mockups load their typefaces and libraries from CDNs, so the machine needs the
  network while a designer works.

## What the import asks

Beside a yard that has `backlog`, `decisions` and a `yardmaster`: the agent of
`<depot>-designers` (`--bind designers=<kind>[:<model>]`), or the group of the
yard that takes it (`--group designers=<group>`). Otherwise also the members of
`backlog` and `decisions` (`--members decisions=<a>,<b>`) and which crew member
takes `yardmaster` (`--crew yardmaster=<name>`).

## Files

- `pack.yaml`: the flow, the groups that work it and the crew member its role
  names.
- `flows/mockup/`: a stage file for each stage a bead waits or is worked in.
  What a stage needs to be true is here, and how a designer works is in the role.
- `roles/designer.md`: the designer's role. It holds the work in five steps,
  the families, the house style, the rules for an app screen, the shot
  mechanics, and the vendored baseline.
- `SETUP.md`: the operator's cards.
- `THIRD_PARTY_NOTICES.md`: the two projects the role draws on, their pins and
  copyright lines, and both licence texts in full.
- `test`: the pack's tests.

Files of a pack that `pack.yaml` does not name are not installed. The role and
the stage files point at none of them, because the yard that imports the pack
never has them.

## Vendored material

The role carries two pieces of other people's work, each opened by a one-line
notice of its name, URL, pin and licence.

- **frontend-design** from Anthropic's skills repository
  (`anthropics/skills@ca45fc4`, Apache-2.0): the body of its `SKILL.md`, whole
  and unmodified, as the baseline of the craft. Its frontmatter is left out.
- **taste-skill** by Leonxlnx (`Leonxlnx/taste-skill@12af471`, MIT): its method
  in this pack's own words, and the rules of its app-screens reference for
  dashboards, admin, settings and the like, also in this pack's own words, under
  a notice of their own. A device it bans outright stays allowed here when a
  direction chooses it, so that three directions keep their range. Its library,
  its other references and its scripts are not in this pack, and neither are the
  stylesheet and chart script the app-screens reference builds on
  (`assets/app.css`, `assets/charts.js`).

THIRD_PARTY_NOTICES.md has the rest.

## Runtimes

The pack has no program of its own beyond `test`, which needs `sh`, `grep`,
`awk` and `shasum` (or `sha256sum`). The designer's steps use `git`, `python3`
(for `python3 -m http.server`), `curl` and `file`, and the shot script uses
headless Chrome.

## Testing

`sh .yardr/test` at the root of the repository runs `yardr pack check` and then
`webdesign/test`. The test needs no network and no secret and takes well under a
second. It is text, so it pins what a later edit could lose without a sound:

- the role carries both one-line notices with their pins and licences, a third
  for the app-screen rules, and the rules and the phone shot themselves;
- the vendored frontend-design block is the upstream body, byte for byte, by its
  sha256;
- THIRD_PARTY_NOTICES.md holds both licence texts byte for byte, by their
  sha256, with the full commits and the copyright line;
- each stage file has its exit line, `mockups.md` names the phone shots, and
  `pick.md` has the card of its moves;
- the decisions of `pack.yaml`: the pack's own type and group, no script group,
  the yardmaster hearing `pick` and carrying no role;
- no role or stage file points at a file the import does not install.

Re-pinning a vendored file means changing its block, the hash in `test` and the
hash in THIRD_PARTY_NOTICES.md together.

## What was checked, and what was not

Checked, in a scratch yard under a short temp directory, with an environment of
nothing but `PATH` and no daemon, so that no agent could start:

- `yardr pack check` and `yardr pack apply` of this directory into a depot, with
  the answers on the command line as SETUP.md gives them. The flow prints as the
  four stages above, the installed role has no placeholder left, and the yard
  reads all three stage files and the card without a warning.
- Checked against a depot that already follows the design pack, the plan shows
  the design pointer, its routes and its groups as `not in the pack (would be
  left alone)`, and `backlog` and `decisions` as shared.
- A bead of type `mockup` walked through every move: advanced to `mockups`, a
  note with three images, `done`, the card put to a member of `decisions` with
  three options, the person's pick back to `mockups` with words, `question`,
  and the pick of `picked`, which closed the bead with the words kept.
- The role's shot mechanics, step by step as separate commands: a static server
  on port 0, three shots, `file` naming `PNG image data, 1280 x 800`, a note
  with three `--file`, the server stopped by its pid and the directory removed.
- The test breaks on each of 22 changes made to a copy, one at a time: a byte of
  the vendored block, a pin, a licence text, an exit line, the type, the group,
  an added script group, and others.

Checked for the app-screen rules, after those:

- The test breaks on each of 12 more changes made to a copy, one at a time: the
  URL in the app-screens notice, the section's heading, each of the six rules by
  its lead, the phone shot's width setting and its `file` line, the exit's 390
  shots, and the notices' record of the reference.
- The words are the pack's own. Everything the change added shares no run of more
  than six words with taste-skill's `SKILL.md` or `references/app-screens.md` at
  the pin, and what it does share is file names, a CSS property and the role's
  own earlier wording.
- On a throwaway page, with this machine's Chrome (156) and the `contrib/shot/shot`
  of yardr 9c94ab8: `SHOT_WIDTH=390` writes `PNG image data, 390 x 800`, a shot
  without it still writes 1280 x 800, and a width that is not a number is refused
  by name before Chrome runs.

Not checked:

- No designer agent has run this role, and none has run its app-screen rules.
  Whether one follows it to three pages that differ, or three screens that read
  as working product, and how good they are, is not known. The first real bead
  of each kind is that test.
- Shots on a machine other than a Mac with Google Chrome. `contrib/shot/shot`
  looks for Chrome and Chromium elsewhere, and the role has not been run there.
- A page at any viewport but 1280x800. The role asks for CSS that holds at phone
  width, as the baseline does, and says in the note that only the first screen at
  1280x800 was looked at. An app screen is shot at 390 as well.

## Left out

- **impeccable and ui-ux-pro-max.** Neither is vendored. They are a second slice
  if the range or the polish of the first proves thin. Their pins and licences
  are settled: `pbakaus/impeccable@9fadc41` is Apache-2.0 and
  `nextlevelbuilder/ui-ux-pro-max-skill@713eef5` is MIT.
- **The scripts and engines of taste-skill and impeccable.** They need Node 22,
  Chrome and the network, and a pack has no key to install them with. That is a
  change to yardr, and so a bead of the yardr depot.
- **The app-screen stylesheet and chart script of taste-skill** (`assets/app.css`,
  `assets/charts.js`), and its inspector (`scripts/inspect.mjs`). A pack installs
  roles, stage files, scripts for script groups and setup notes, and has no way
  to put a stylesheet or a script in a designer's worktree; the inspector needs
  Node and Chrome as well. The rules they serve are in the role in this pack's
  own words, and the designer draws its own panels and charts.
- **A bead type or a flow of its own for app screens.** An app screen is a
  mockup bead like a page: the designer decides which it is from the brief.
- **Landing the picked mockup.** There is no assembly by design.
- **A build bead filed from the pick.** It is filed by hand when asked for.
- **The type `design`.** One type follows one flow, so it stays the design
  pack's.
- **shadcn, 21st.dev Magic, Vercel's accessibility skill and superpowers
  brainstorming.** They belong to the build step, not to choosing a direction.
