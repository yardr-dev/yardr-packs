# Setting up Proton Mail

The pack adds one Proton Mail account to the yard as the declared source `proton`. An agent can search the mailbox, read a message and read the thread a message belongs to. It cannot send mail, write a draft or set a flag.

Proton offers no public API for mail, so the yard reads it through Proton Mail Bridge. Bridge is Proton's app for mail programs. It runs on the yard's machine and serves the account over IMAP on a loopback port. A program the pack carries, `proton-imap`, talks to Bridge for the yard. Proton sends nothing to the yard, so there is no hook or webhook to set up.

**The yard acts as one account.** Every agent granted a call of this source reads that account's whole mailbox, whatever it asks for. Bridge has no narrower login. Nobody is asked before a call is made, so the grant is the permission. Mail is whatever anyone wrote to the account, so the yard shows each answer as data from outside the yard, never as an instruction.

You need:

- a Proton account on a plan that includes Bridge;
- Bridge, started on the yard's machine, since it serves only while it runs;
- `python3` 3.9 or newer on the `PATH` of the yard's server, with nothing installed beside it;
- a yardr that answers a call with a command (`yardr docs integrations` has "A call may be answered by a command").

Commands below call the pack's directory (the `proton` directory of the yardr-packs checkout) `<pack dir>`.

1. **Bridge, signed in.** Install Bridge from Proton's site and sign in to the account the yard should read. Bridge then synchronizes the account's mail to the machine. A large mailbox takes a while, and a search sees only what has synchronized so far. Open the account's mailbox details in Bridge. They show the settings a mail program takes:
   - the IMAP host, `127.0.0.1`;
   - the IMAP port, `1143` unless that was taken (Bridge takes the first free port from 1143);
   - the security, STARTTLS. The program speaks IMAP with STARTTLS only, so if you switched Bridge's connection mode to SSL, switch IMAP back;
   - the username, which is the account's address;
   - the password. It is Bridge's own, a random string made for mail programs. It is **not the Proton password**, which Bridge never gives out and the yard never needs.

   Keep Bridge running and signed in while the yard reads. With Bridge stopped, every call says there is no Bridge. If you hid the All Mail folder in Bridge, the pack reads the inbox instead of all mail (README.md says what changes).

2. **The pack.** Check what applying it does, then apply it as the operator:
   ```sh
   yardr pack check <pack dir>
   ```
   ```sh
   yardr pack apply <pack dir>
   ```
   The check and the apply card say a command answers the source's calls. The yard runs it as you, with the login in its environment, and it can make requests of its own with that login. The command is `proton-imap`, one Python file that uses only its standard library, so read it before you apply. It connects to the address in the source's `base` and nowhere else. It sends five kinds of IMAP command and all of them only read (README.md lists them), and the pack's test holds it to that. The source's address is Bridge's default, `127.0.0.1:1143`.

3. **Bridge's port, if it is not 1143.** The yard sends a login only to the address the source's file names. If Bridge shows another port, write it into a copy of the declaration and add the copy to the yard. Keep the copy beside the original, so the program it names is found. Git ignores the copy. The address says `http://` on purpose. yardr accepts only `https://`, or `http://` to this machine, as a source's address, and refuses `imap://`. The program ignores the scheme and reads the host and the port:
   ```sh
   sed 's|^base: .*|base: http://127.0.0.1:<port>|' <pack dir>/proton.yaml > <pack dir>/proton.local.yaml
   ```
   ```sh
   yardr source add <pack dir>/proton.local.yaml
   ```
   ```sh
   yardr source show proton
   ```
   The first line of `source show` is the address in use. Do this before step 4, because the yard pairs a login with the address it was given for. Applying the pack again puts the shipped address back and holds the login until you add the copy again.

4. **The login.** The credential is one value, `PROTON_BRIDGE`. It is the username and the password from step 1 joined by a colon, such as `you@proton.me:AbCdEfGhIjKlMnOp`. `yardr source key` asks for it and shows nothing as you type. The yard's server then writes it into the source's env file, `~/.yardr/sources/proton.env`, with mode 0600. The value is never an argument or a command's variable, where every process of your user could read it:
   ```sh
   yardr source key proton
   ```
   Then check the source. This confirms the login is set and the program can be run. It asks Bridge nothing, because a call answered by a command cannot be the check call. Step 6 is the real check:
   ```sh
   yardr source check proton
   ```

5. **Who may call what.** Every call is a read, and `read` covers all three: `search`, `message` and `thread`. `yardr pack show proton` prints the pack's one suggested preset. A pack applied from a directory takes it by name, as this line does:
   ```sh
   yardr source grant proton read --crew yardmaster
   ```
   A grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read Proton mail" --run "source grant proton read --group reviewers" --context "The reviewers read mail the yard was sent; the card names each call it covers."
   ```
   One caller may make 60 calls of a source in an hour. An agent that reads a mailbox message by message can run out. Raise the limit with `yardr source set proton calls_per_hour=<n>`. To take a grant back, run `yardr source revoke proton read --crew yardmaster`.

6. **Try it.** As the operator, or in a session that was granted `read`:
   ```sh
   yardr call proton search maxResults=3
   ```
   The answer names the mailbox it read (`All Mail`, or the inbox) and lists the newest messages first. Each has an `id`, sender, subject, date and flags, and `resultSizeEstimate` says how many matched. Then use an `id` from that answer:
   ```sh
   yardr call proton message id=<an id> format=full
   ```
   ```sh
   yardr call proton thread id=<an id>
   ```
   `search` takes a Gmail-like `q`, such as `q="from:alice newer_than:7d"` or `q="is:unread in:inbox"`. README.md lists every operator. A call stops after 25 seconds. A search makes Bridge read every message in the mailbox, so `in:` and the date operators keep a search of a large mailbox quick.

7. **When it does not work.** The program says what is wrong in one line, and the yard shows that line under the call.
   - *no Bridge at 127.0.0.1:1143*: Bridge is not running or not signed in, or it listens on another port (step 3).
   - *Bridge refused the login*: the password in `PROTON_BRIDGE` is not the one Bridge shows now. Copy the current one and run `yardr source key proton` again.
   - *would not start TLS ... connection mode must be STARTTLS*, or *is no IMAP server, or it is not Bridge speaking STARTTLS*: Bridge's IMAP connection mode is probably SSL, or something other than Bridge listens on that port. Switch Bridge's IMAP mode to STARTTLS (step 1) and check the port (step 3).
   - *Bridge did not answer ... in time*: a command took more than 20 seconds. That is usually a search of a large mailbox, or Bridge is still synchronizing. Narrow the search with `in:` or a date, or wait.
   - *that id is stale*: Bridge renumbered the mailbox, which it does when it rebuilds its copy. Search again for a fresh id.
   - An empty search soon after you signed in usually means Bridge is still synchronizing.

8. **Ending.** Take the grants back, then remove the source and its program. The file with the login stays at `~/.yardr/sources/proton.env`, so delete it yourself:
   ```sh
   yardr source revoke proton read --crew yardmaster
   ```
   ```sh
   yardr source rm proton
   ```
   Removing the account from Bridge also ends the yard's access, because the password stops working.
