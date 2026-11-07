# Tdd

A pack for a depot that wants its beads built by test-driven development. A
builder writes a test that fails for the bead's reason and commits it alone,
makes it pass, and cleans up last. A reviewer checks in the branch's history
that the test came first and failed before the change. The pack adds those two
roles and nothing else. Nothing here is compiled into yardr; apply it with:

```sh
yardr pack apply /path/to/yardr-packs/tdd --depot <depot>
```

`yardr pack check` with the same arguments shows what the import would do and
writes nothing. In a depot the starter set up the import alone does not change
who builds: SETUP.md has the two commands that do, and
[Applying it](#applying-it-to-a-depot) says why.

There is no flow. Red, green and clean-up all happen in `new`, and a branch
whose test came after its code goes back from `review` with the outcome
`changes`, which the starter's flow already has. A flow would add stages the
depot has. There is no script either: `roles/` holds the two role files,
`pack.yaml` maps the groups to them, and nothing runs.

## What the builder does

Red, then green, then clean-up, inside `new`:

1. List the behaviours the bead asks for in the plan note, and take them one at
   a time, or together when one change will plainly cover them: their rows then
   share a test commit, and a row that your own fix happens to cover moves ahead
   of that fix.
2. Write the test and run it. It has to fail for the bead's reason: the test ran,
   its assertion failed, and the failure says what was expected and what came
   out. A test that does not compile, stops before its assertion, or fails on
   something the base already had broken is not red yet. A test that passes on
   its first run shows nothing. Where a language cannot run a test against code
   that is not there, the test commit holds the smallest stub.
3. Commit the test alone, with a subject that starts `test:`.
4. Write the least code that passes it, and commit.
5. Clean up in commits of their own, with the tests as they were at green.

The note carries what the reviewer needs to believe the order, above the usual
`test:` line, once for each test commit:

```
red: <command> @ <short sha>: fail, <n> failed
<the failure as printed, cut to the lines that name the test, what it
expected and what it got>
```

The role also says what a test is made of here, which kinds of change have
nothing to pin and so need no test commit (documentation, a refactor that tests
already cover, configuration no test reads, a dependency bump), and how to
rebuild a branch that was sent back for its order.

## What the reviewer does

The reviewer reads the history before the diff. `git log --reverse --stat` shows
a commit that adds the tests and, only where needed to run them, the smallest
stub or fixture; then the commit that makes them pass, then clean-up. The
reviewer checks that the sha in the note's red line is that test commit, that the
failure is the bead's reason, that the tests have only been added to since red,
and that no behaviour in the diff lacks a test. A test that came after its code
goes back with `changes`, naming the commits in the order the reviewer saw
them. The reviewer does not fix that forward: it cannot supply the builder's
red run, and rewriting the builder's history is not forward. It can tell the
builder whether the test would have failed, by running the branch's tests over
the base's code in a throwaway worktree, as its own probe and not as the builder's
red. Documentation or prose, comments, a refactor that tests already cover,
generated files, configuration no test reads and a dependency bump have nothing
to pin; the reviewer checks that claim against the diff and requires no red
line. The starter's limit on rounds applies, three back to `new` and then
`decide`. The reviewer's own fixes follow the same order, and one `tdd:` line in
its note says what it checked.

## Why a note and a history are the proof

Nothing is re-run as routine. The note shows the red, and the history shows where
it came. Re-running every test commit would cost a checkout and a run for each
bead, against a risk this yard does not have: a builder who skips the order shows
it in the history, which the reviewer reads anyway. It would also cut against the
reviewer role's rule not to run the suite as a matter of course, since the
landing tests once more. A red the reviewer doubts is run, under that role's
existing rule on the tests of what you doubt.

## Applying it to a depot

A depot the starter set up has `<depot>-builders` and `<depot>-reviewers`. The
import finds them, installs the roles, and keeps the groups' prompts: an import
never takes over a group another pack made, and `pack check` says `kept: prompt`
for each. The prompt is a path, so SETUP.md gives the two `yardr group set`
commands that point the groups at these roles, and the two that point them back.
The security reviewers keep the starter's role.

Each role is the starter's builder or reviewer in full with one section added
after its intro, because a group's prompt is one file and holds no include.
Nothing of the starter's text is removed, so the test-line, Friction-line,
fix-forward and hand-over rules all hold. They were copied from yardr 470c61cf.
When the starter's roles change, these copies need the same change, and
`tdd/test` fails when a line of the starter's rules goes missing from either.

The pack names the crew member `yardmaster`, because the roles tell an agent to
mail it, and carries no role for it: the yardmaster keeps the prompt it has.
It sets the kinds of event the yardmaster hears to the starter's `attention`, and
names no stage, since the pack has none. No group has a limit, so a depot's own
stay. In a depot with no builders and reviewers the import asks for their agent
as it does for any new group, but this pack has no flow that would send them
work, so set the depot up from the starter first.

## Left out

Planning and brainstorming skills, dispatching sub-agents and working in
worktrees, because the yard has its own for each. Making test-first the default
anywhere: a person opts a depot in. Re-running test commits as routine.

## Sources

The role text is written in yardr's own words from these. Nothing is copied from
any of them.

- Kent Beck, *Test-Driven Development: By Example* (Addison-Wesley, 2002). The
  red, green and refactor cycle, small steps, and a list of tests kept aside
  while you work on one.
- Kent Beck, "Canon TDD" (Software Design: Tidy First?, 11 December 2023),
  https://newsletter.kentbeck.com/p/canon-tdd. The workflow and its listed
  mistakes, among them pasting computed values in as the expected ones, deleting
  an assertion so a test passes, mixing clean-up into getting to green, and
  turning the whole list into tests at once.
- Martin Fowler, "Test Driven Development" (2005, updated 2023),
  https://martinfowler.com/bliki/TestDrivenDevelopment.html. Clean-up belongs to
  the cycle, and skipping it is the usual way the practice goes wrong.
- Steve Freeman and Nat Pryce (Addison-Wesley, 2009),
  *Growing Object-Oriented Software, Guided by Tests*. The section "Watch the
  Test Fail".
- Gerard Meszaros, *xUnit Test Patterns* (Addison-Wesley, 2007), and its site
  http://xunitpatterns.com. Conditional test logic, tests that say how the code
  works and not what it achieves, and when a mock object earns its place.
- James Carr, "TDD Anti-Patterns" (3 November 2006). A test written to pass
  first, a test that checks only its mocks, and an assertion that rides along in
  a test about something else. The post is gone from blog.james-carr.org; a copy
  is at
  http://web.archive.org/web/2013/http://blog.james-carr.org/2006/11/03/tdd-anti-patterns/.
