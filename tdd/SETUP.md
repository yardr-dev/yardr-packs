# Setting up the tdd pack

The pack changes how a depot's beads are built. A builder writes a test that
fails for the bead's reason, commits it alone and then makes it pass, and a
reviewer checks in the branch's history that the test came first. It adds two
roles and no flow. This file is the operator's steps.

The commands call the depot `<depot>` and the pack's directory (the `tdd`
directory of the yardr-packs checkout) `/path/to/yardr-packs/tdd`. Change both
to yours. They write the yard's home as `$HOME/.yardr`, which is where it is
unless `--home` or `YARDR_HOME` says otherwise; the import prints the directory
it copied the roles to. If the yard uses another home, replace `$HOME/.yardr` in
the group-setting commands below with the matching path from that output.

The pack is for a depot the starter set up. Its builders and reviewers exist
already, and its flow has the stages the roles work in.

1. **What the import would do.** Nothing is written:
   ```sh
   yardr pack check /path/to/yardr-packs/tdd --depot <depot>
   ```
   It lists the two role files, and under `<depot>-builders` and
   `<depot>-reviewers` a line that starts `kept: prompt` and says the group was
   made by pack starter. An import never takes over a group another pack made,
   so the import alone changes nobody's prompt. Step 3 does.
2. **Import it.** The roles are copied under the yard's home with the operator's
   and the yardmaster's names filled in. A depot the starter set up has the
   groups and the crew member already, so the import asks only for a yes, or
   takes `--yes` where there is no terminal:
   ```sh
   yardr pack apply /path/to/yardr-packs/tdd --depot <depot>
   ```
3. **Point the groups at the roles.** One command for each group, run by the
   operator. A group that other depots share changes for them too, and a depot
   whose `new` and `review` stages go to groups with other names points those:
   ```sh
   yardr group set <depot>-builders prompt=$HOME/.yardr/packs/tdd/roles/tdd-builder.md
   ```
   ```sh
   yardr group set <depot>-reviewers prompt=$HOME/.yardr/packs/tdd/roles/tdd-reviewer.md
   ```
   A session reads its prompt when it starts, so a builder already at work keeps
   the role it began with.
4. **Check.** The lines for the two groups read `pack tdd`, and the line for the
   security reviewers still reads `pack starter`:
   ```sh
   yardr depot sources <depot>
   ```
5. **Going back.** Point the groups at the starter's roles again:
   ```sh
   yardr group set <depot>-builders prompt=$HOME/.yardr/packs/starter/roles/builder.md
   ```
   ```sh
   yardr group set <depot>-reviewers prompt=$HOME/.yardr/packs/starter/roles/reviewer.md
   ```

Importing the pack again after its roles change brings the installed copies up
to date, and the groups keep reading them.
