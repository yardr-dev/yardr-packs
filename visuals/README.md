# Visuals

A pack for a yard that wants finished visuals from agents: posters, social
cards, covers, slides. A brief goes in, three directions come out, each
composed at the brief's exact size with a picture of it, and a person picks
one and holds the finished file. Nothing lands. Nothing here is compiled into
yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/visuals --depot <depot>
```

`yardr pack check /path/to/yardr-packs/visuals --depot <depot>` shows what the
import would do first, and writes nothing. SETUP.md is the operator's steps.

The pack adds the bead type `visual` beside the flows a depot already follows.
A depot on the webdesign pack's mockup flow keeps it. One type follows one
flow, and the webdesign pack's flow is for the type `mockup`, so a pack that
reused that type would have its import re-point every depot on the mockup flow.
The type `visual` is this pack's own, and an import leaves every other type's
flow, routes and groups as they are.

## How it hangs together

```
backlog -> directions
directions -> pick on done | pick on question | backlog
pick -> picked | directions | backlog
picked terminal
```

| stage | worked by | what happens |
|---|---|---|
| `backlog` | `backlog`, people | the bead waits until its brief says the format, the size, the subject, the audience, the job, the words, what is fixed, reference work and what is not wanted |
| `directions` | `visual-designers` | an agent commits three direction files, `directions/<n>-<name>.svg` or `.html`, each composed at the brief's exact size, starts a watch on the folder so the person can open the files while they are built, shoots each at that size (and prints a PDF where the brief is for print), and puts the shots on one note that names each direction's idea, type pairing and palette and each file's address on the watch |
| `pick` | `decisions`, people | a person reads the shots and moves the bead to `picked`, back to `directions` with a note, or to `backlog`; the yard puts a card on the bead offering these moves, and the person's words with the pick name the direction |
| `picked` | | the end: the bead closes, and the person holds the picked file with its PNG (and its PDF for print) from the branch |

`question` also leads to `pick`. A designer that cannot start without an answer
(a brief that names no size) says what it needs on a note, and the person
answers there and sends the bead back to `directions`.

There is no assembly stage. The directions stay on the bead's branch
`yard/<bead>` and the shots on its note, and the words of the pick name the
direction to hold. Landing all three files would put throwaways on the base,
and landing one would need another agent to take the other two out. What the
person holds is the picked file with its finished PNG at the exact size (and
its PDF where the brief is for print), on the branch under `directions/`.

**Three directions that differ in idea.** The designer's role asks for three
ideas, each a composition built around something that only this subject has,
and for each a type pairing and a palette. The rule is that no two directions
share the same idea, and a palette alone never carries the difference: one
layout in three tints fails it. A brief that fixes the brand's colours or
typefaces keeps them in all three, and the ideas carry the difference.

**The exact size.** The designer shoots each file with headless Chrome run
directly, at the brief's exact pixels (`--window-size`, `--screenshot`), and
checks each PNG with `file`. The shot script yardr carries (`contrib/shot`)
takes a width only and keeps the height at 800, which is why the role runs
Chrome itself. For a print brief the PNG is the trim size at 96 CSS pixels to
the inch (A4 is 794x1123), and the PDF, printed with `--print-to-pdf` from a
page that carries the trim size, is the print master. A file narrower than 500
pixels is shot through a frame of its exact size, since Chrome on macOS lays
narrower windows out 500 wide.

**The watch.** Once the first file exists the designer starts
`yardr preview watch $YARDR_BEAD directions`. The yard serves the folder's
files read-only through its preview endpoint, and a file reloads in the
browser whenever it changes, so the person sees the three directions take
shape. The command prints the address they open at on its `opens at` line: the
host the yard's edge gave the watch, or the path `/preview/<app>/` on the yard
where the edge gives none. `directions/` holds no `index.html`, so the folder's
own address answers 404, and so does the Open button of the watch's card on the
Previews page. The designer therefore names each file's address, the printed
address followed by the file name, and puts the three on a note as soon as the
watch is up, so the person has them while the designer builds. The note with
the shots gives them again. The watch ends by itself when the bead leaves
`directions`, so the shots are the record of what the person picks from.

## What it needs

- **An agent for `<depot>-visual-designers`.** The import asks for its kind,
  model and permission arguments, as it does for any agent group it makes. The
  group is the pack's own and not the depot's `builders`: a pack names a group
  together with its role, so naming `builders` would aim the depot's code
  builders at a designer's prompt. One designer works at a time, and
  `yardr group set <depot>-visual-designers --limit 2` allows more.
- **The yard's two people groups**, `backlog` and `decisions`, which the import
  reuses when the yard has them and asks for the members when it does not.
- **A crew member called `yardmaster`**, or another that takes the name
  (`--crew yardmaster=<name>`). It hears a bead enter `pick`, a bead close, and
  the events that need someone. The pack carries no role for it, so the
  yardmaster keeps its prompt.
- **On the yard's machine**, for the shots: headless Chrome (Google Chrome in
  `/Applications`, `google-chrome` or `chromium` on the PATH, or a path in
  `SHOT_CHROME`), `python3` and a yardr checkout to read. The directions load
  their typefaces from CDNs, so the machine needs the network while a designer
  works.
- **A yardr with `yardr preview watch`**, for the watch (yardr 26b2a52, 4
  November 2026, and after). `yardr docs watch` prints its page on a yardr that
  has the command and names the pages it has on one that does not. On an older
  yardr `yardr preview watch` prints the help of `preview` and ends 0, so the
  designer goes by the `opens at` line: with none, it puts what the command
  printed on its note and goes on, and the shots are as before. The address is
  the path on the yard until the yard is linked to an edge that gives the watch
  a host (yardr ec29917, 4 November 2026, and after). Where the yard is linked
  and the edge refuses, the command prints the edge's words under the path.

## What the import asks

Beside a yard that has `backlog`, `decisions` and a `yardmaster`: the agent of
`<depot>-visual-designers` (`--bind visual-designers=<kind>[:<model>]`), or the
group of the yard that takes it (`--group visual-designers=<group>`). Otherwise
also the members of `backlog` and `decisions`
(`--members decisions=<a>,<b>`) and which crew member takes `yardmaster`
(`--crew yardmaster=<name>`).

## Files

- `pack.yaml`: the flow, the groups that work it and the crew member its role
  names.
- `flows/visual/`: a stage file for each stage a bead waits or is worked in.
  What a stage needs to be true is here, and how a designer works is in the role.
- `roles/visual-designer.md`: the designer's role. It holds the work in five
  steps, the house style for composed stills, and the exact-size mechanics.
- `SETUP.md`: the operator's cards.
- `test`: the pack's tests.

Files of a pack that `pack.yaml` does not name are not installed. The role and
the stage files point at none of them, because the yard that imports the pack
never has them.

## Runtimes

The pack has no program of its own beyond `test`, which needs `sh` and `grep`.
The designer's steps use `git`, `file` and headless Chrome run directly.

## Testing

`sh .yardr/test` at the root of the repository runs `yardr pack check` and then
`visuals/test`. The test needs no network and no secret and takes well under a
second. It is text, so it pins what a later edit could lose without a sound:

- the role carries the distinctness rule, the exact-size mechanics (Chrome run
  directly, the PNG shot and its check, the print PDF and its check, the frame
  under 500 wide) and the watch (the command with the bead's id, how a file's
  address is made, and the two notes that carry the addresses);
- each stage file has its exit line, `directions.md` names the finished PNG and
  PDF, the role's distinctness rule and the address of each file on the watch,
  `backlog.md` names the size, and `pick.md` has the card of its moves;
- the decisions of `pack.yaml`: the pack's own type and group, no script group,
  the yardmaster hearing `pick` and carrying no role;
- no role or stage file points at a file the import does not install.

## What was checked, and what was not

Checked, in a scratch yard under a short temp directory, with an environment of
nothing but `HOME` and `PATH`, hand-walked throughout so that no agent started
(the trial played designer and person by hand):

- `yardr pack check` and `yardr pack apply` of this directory into a depot, with
  the answers on the command line as SETUP.md gives them. The flow prints as the
  four stages above, the installed role has no placeholder left, and the yard
  reads all three stage files and the card without a warning.
- Checked against a depot that already follows the webdesign pack, the plan
  shows the mockup pointer, its routes and its groups as
  `not in the pack (would be left alone)`, and `backlog` and `decisions` as
  `unchanged`. Against a fresh yard the plan instead creates `backlog` and
  `decisions` and asks for their members, and creates the yardmaster's two
  subscriptions with the `yardmaster` itself `unchanged`.
- Two beads of type `visual` walked from a brief to three direction files with
  shots on a note to picked: one for screen (1080x1350) and one for print
  (A4). Each held PNG is byte-exact to the brief's size (`file` names its
  pixels), with a PDF at the trim size for the print one. A third bead walked
  the `question` outcome to `pick` and back to `directions` with words, and the
  pick card rendered on it with its question and moves.
- The role's exact-size mechanics, step by step as separate commands: the PNG of
  an HTML file and of an SVG file at 1080x1350, `file` naming
  `PNG image data, 1080 x 1350`; the PDF of a print page, `file` naming one
  page and `MediaBox` the trim size; a width under 500 shot through a frame at
  its exact width; a note with three `--file`; and the temp directory removed.
- The test breaks on each of 26 changes made to a copy, one at a time: the
  distinctness rule, each mechanics flag and check, the watch command and its
  address rules, the type, the group, the limit, an added script group, a crew
  role, an exit line, the pick card, and a link to a file the import leaves
  behind.

Not checked:

- No designer agent has run this role or started its watch. Whether one follows
  it to three directions that differ in idea, and how good they are, is not
  known. The first real bead is that test. The watch command was read and not
  run against a bead, so what a person sees in a browser, and whether the
  addresses reach the person in time, is as the docs describe.
- Shots on a machine other than a Mac with Google Chrome. The role looks for
  Chrome and Chromium elsewhere, and has not been run there.

## Left out

- **Generated images and any image model.** A picture the machine dreams up is a
  source pack of its own, later, added on without changing this one. This pack
  composes: type, layout, shapes, charts.
- **A dir depot version**, for people with no repository.
- **Brand kits kept between beads.** Each bead carries what its brief fixes.
- **Video and motion.** A still is what this pack holds.
- **Landing anything on a base.** There is no assembly by design.
- **A printer's bleed past trim.** The file is the trim size exactly; full-bleed
  art runs to its edge.
- **The type `mockup`.** One type follows one flow, so it stays webdesign's.
