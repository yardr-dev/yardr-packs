# Setting up the visuals pack

The pack adds the bead type `visual` to a git depot. A brief goes in: what the
visual is and how big. A designer agent composes three directions at that exact
size, shoots them, and puts the shots on a note, and a person picks one and
holds the finished file. Nothing lands. This file is the operator's steps.

The commands call the depot `studio` and the pack's directory (the `visuals`
directory of the yardr-packs checkout) `<pack dir>`. Change both to yours.

The designer's shots need two things on the yard's machine: headless Chrome
(Google Chrome in `/Applications`, `google-chrome` or `chromium` on the PATH, or
a path in `SHOT_CHROME`), run directly at the brief's exact size, and `python3`.
The directions load their typefaces from CDNs, so the machine needs the network
while a designer works.

A designer starts a watch on the directions while it builds
(`yardr preview watch`, in yardr from 4 November 2026), so that a person can
open the files in a browser as they take shape. The designer's notes give the
address of each file: the address the command prints, followed by the file's
name. The command prints the host the yard's edge gave the watch where the yard
is linked to an edge that gives one, and the path `/preview/<app>/` on the yard
otherwise.

1. **The machine.** Each command below is one thing to type, in a block of its
   own. The first finds Chrome. The second prints the first line of the page on
   the watch, and on a yardr that has no watch says `no doc named "watch"`. Its
   designers get no `opens at` line from the command, and put what it printed
   on their notes in place of the addresses:
   ```sh
   command -v google-chrome google-chrome-stable chromium chromium-browser; ls "/Applications/Google Chrome.app" >/dev/null && echo macOS Chrome
   ```
   ```sh
   yardr docs watch | head -1
   ```
2. **What the import would do.** Nothing is written:
   ```sh
   yardr pack check <pack dir> --depot studio
   ```
   It lists the flow `visuals.visual`, the pointer that makes it the flow of
   type `visual`, the routes of its stages, the group `studio-visual-designers`
   and the questions the next step asks. A depot that follows the webdesign
   pack's mockup flow keeps it: that flow is for the type `mockup`, and this
   one is for `visual`. Read the `crew` lines too: the `yardmaster` itself is
   unchanged, and the plan creates its two subscriptions, a bead entering
   `pick` and a bead closing.
3. **Import it.** The import asks which agent runs `studio-visual-designers`:
   its kind, its model and its permission arguments. A designer runs shell
   commands (git, Chrome, yardr) and opens PNGs to look at its own work, so
   pick a kind and model that read images, and the permission arguments your
   builders have. With none, it stops at every permission prompt.
   ```sh
   yardr pack apply <pack dir> --depot studio
   ```
   To answer on the command line instead of at the prompts (the kind and model
   are an example):
   ```sh
   yardr pack apply <pack dir> --depot studio --yes --bind visual-designers=claude:opus
   ```
   The groups `backlog` and `decisions` are the yard's two people groups, and the
   import reuses a yard's own. They hold the people who ready a brief and who
   pick. A yard without them is asked for their members, and `--members
   backlog= --members decisions=mckean` answers (empty means anyone). A yard
   whose crew member is not called `yardmaster` says which one takes it, with
   `--crew yardmaster=<name>`. An agent group the yard already has can take the
   designers' place, with `--group visual-designers=<group>`: its own prompt
   stays, and the pack's role is installed and read by nobody.
4. **Make a bead.** The brief is the bead's body: the format, the size (exact
   pixels for screen, the trim size for print), the subject, the audience, the
   job, the words, what the brief fixes, reference work and what is not wanted.
   The stage file of `backlog` lists them and is shown to whoever opens the
   bead. The type `visual` follows this pack's flow, which starts in
   `backlog`:
   ```sh
   yardr bead create "Three directions for the fete poster" --depot studio --type visual -b "<the brief>"
   ```
   `-b -` reads the body from standard input instead. When the brief is ready,
   send the bead to the designers:
   ```sh
   yardr bead advance <id> --to directions
   ```
5. **Watch it built.** Once the designer has written its first file it starts
   the watch and puts the three addresses on a note, which appears on the bead
   as any note does:
   ```sh
   yardr prime --bead <id>
   ```
   Open the addresses in a browser; one that starts with a slash is a path on the
   yard's web view, so put the view's address in front of it. A file reloads
   when it changes, and a file the designer has not built yet answers 404 until
   it has. The Previews page of the web view lists the watch as well, but its
   Open button opens the folder, which answers 404: the files are at the
   addresses in the note. The watch ends when the bead leaves `directions`, and
   the shots on the last note are the record.
6. **The pick.** When the designer is done the bead waits in `pick`, and the yard
   puts a card on it that offers the moves. The person reads the shots on the
   designer's note (`yardr prime --bead <id>` prints it, and the web view shows
   the images), then picks. The same move by hand, with the pick in words:
   ```sh
   yardr bead advance <id> --to picked --note "2, with the type of 3"
   ```
   The other two moves are `--to directions`, for another round with a note that
   says what to change, and `--to backlog`, to park the bead or reshape its
   brief.
7. **After the pick.** The bead is closed at `picked`. The directions stay on the
   branch `yard/<id>`, under `directions/`, and the shots on the note. Nothing
   lands on the base. What you hold is the picked file with its PNG at the
   exact size (and its PDF where the brief is for print), on the branch.

One designer works at a time, because each runs headless Chrome. To allow more,
raise the limit of the group the import made:

```sh
yardr group set studio-visual-designers --limit 2
```
