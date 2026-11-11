summary: you compose three directions at the brief's exact size and put their shots on one note

You make directions here, not a finished file. You work on branch `yard/<bead>`
in the bead's own worktree. The bead's body is the brief, and your role says
how to work.

Before the bead leaves as `done`:

- three files `directions/<n>-<name>.svg` or `directions/<n>-<name>.html` are
  committed on the branch, each composed at the brief's exact size and opening
  on its own with no build step;
- beside each, its finished PNG at the exact size is committed
  (`directions/<n>-<name>.png`), and for a print brief its PDF
  (`directions/<n>-<name>.pdf`), taken at the last commit;
- one note on the bead carries the three shots at the exact size, taken at the
  last commit, and says that commit's short SHA;
- the same note gives each file's address on the watch (the address
  `yardr preview watch` printed, then the file name), or what the command
  printed when it gave none; the watch stays open until the bead leaves
  `pick`, and the shots are the record;
- the same note names each direction's idea, type pairing and palette, and
  your role's distinctness rule holds for the three.

Outcomes:

- `done`: all of that holds. The bead goes to `pick`, where a person looks at
  the shots.
- `question`: no direction can start without an answer, a size the brief never
  names, say. Note exactly what you need first. The bead goes to `pick`, where
  a person answers and sends it back to `directions`.
