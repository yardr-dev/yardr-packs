# Setting up the webdesign pack

The pack adds the bead type `mockup` to a git depot. A brief goes in. A designer
agent makes three standalone HTML pages in three different directions, shoots
them, and puts the shots on a note, and a person picks one. Nothing is built for
real and nothing lands. This file is the operator's steps.

The commands call the depot `web` and the pack's directory (the `webdesign`
directory of the yardr-packs checkout) `<pack dir>`. Change both to yours.

The designer's shots need four things on the yard's machine: headless Chrome
(Google Chrome in `/Applications`, `google-chrome` or `chromium` on the PATH, or
a path in `SHOT_CHROME`), `curl` and `python3`, which check and serve the pages,
and a yardr checkout, whose `contrib/shot/shot` takes the shots. The pages load
their typefaces and libraries from CDNs, so the machine needs the network while
a designer works.

A brief for an app screen (a dashboard, an admin view, settings, an inbox) is
shot a second time at phone width, which needs a shot script that takes a width
(`SHOT_WIDTH`, in yardr from 4 November 2026).

1. **The machine.** Each command below is one thing to type, in a block of its
   own. The first prints the yardr checkout's path, which holds
   `contrib/shot/shot`. The second finds the two programs. The third, with that
   path put in, counts the lines of the shot script that name `SHOT_WIDTH`: 0
   means an older script, whose phone shots would come out 1280 wide:
   ```sh
   yardr depot show yardr
   ```
   ```sh
   command -v curl python3
   ```
   ```sh
   grep -c SHOT_WIDTH <yardr checkout>/contrib/shot/shot
   ```
2. **What the import would do.** Nothing is written:
   ```sh
   yardr pack check <pack dir> --depot web
   ```
   It lists the flow `webdesign.mockup`, the pointer that makes it the flow of
   type `mockup`, the routes of its stages, the group `web-designers` and the
   questions the next step asks. A depot that follows the design pack's document
   flow keeps it: that flow is for the type `design`, and this one is for
   `mockup`. Read the `crew` lines too. The pack sets the kinds of event the
   yardmaster hears to `attention` and replaces a longer list it had, and the
   plan shows that as a change of `on`.
3. **Import it.** The import asks which agent runs `web-designers`: its kind, its
   model and its permission arguments. A designer runs shell commands (git,
   python3, Chrome, yardr) and opens PNGs to look at its own work, so pick a kind
   and model that read images, and the permission arguments your builders have.
   With none, it stops at every permission prompt.
   ```sh
   yardr pack apply <pack dir> --depot web
   ```
   To answer on the command line instead of at the prompts (the kind and model
   are an example):
   ```sh
   yardr pack apply <pack dir> --depot web --yes --bind designers=claude:opus
   ```
   The groups `backlog` and `decisions` are the yard's two people groups, and the
   import reuses a yard's own. They hold the people who ready a brief and who
   pick. A yard without them is asked for their members, and `--members
   backlog= --members decisions=mckean` answers (empty means anyone). A yard
   whose crew member is not called `yardmaster` says which one takes it, with
   `--crew yardmaster=<name>`. An agent group the yard already has can take the
   designers' place, with `--group designers=<group>`: its own prompt stays, and
   the pack's role is installed and read by nobody.
4. **Make a bead.** The brief is the bead's body: the subject, the audience, the
   primary job, the page, reference sites, what the brief fixes and what is not
   wanted. The stage file of `backlog` lists them and is shown to whoever opens
   the bead. The type `mockup` follows this pack's flow, which starts in
   `backlog`:
   ```sh
   yardr bead create "Three directions for the shop's landing page" --depot web --type mockup -b "<the brief>"
   ```
   `-b -` reads the body from standard input instead. When the brief is ready,
   send the bead to the designers:
   ```sh
   yardr bead advance <id> --to mockups
   ```
5. **The pick.** When the designer is done the bead waits in `pick`, and the yard
   puts a card on it that offers the moves. The person reads the shots on the
   designer's note (`yardr prime --bead <id>` prints it, and the web view shows
   the images), then picks. The same move by hand, with the pick in words:
   ```sh
   yardr bead advance <id> --to picked --note "2, with the type of 3"
   ```
   The other two moves are `--to mockups`, for another round with a note that
   says what to change, and `--to backlog`, to park the bead or reshape its
   brief.
6. **After the pick.** The bead is closed at `picked`. The mockups stay on the
   branch `yard/<id>`, under `mockups/`, and the shots on the note. Nothing lands
   on the base. A build from the pick is a bead of its own, filed by hand when
   someone asks for one.

One designer works at a time, because each runs headless Chrome. To allow more,
raise the limit of the group the import made:

```sh
yardr group set web-designers --limit 2
```
