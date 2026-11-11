# Setting up Infomaniak kDrive

The pack adds Infomaniak's kDrive to the yard as the declared source `infomaniak-drive`: an agent can list a folder's files, read one file's metadata, search files, list a file's comments and download one file's content, and it can upload files, write comments and make share links. It cannot delete, trash, restore, rename, move or copy anything, and it cannot grant anyone access: the share link is the one exception, and it is public to whoever holds it. It is the twin of `google-drive`. Infomaniak sends nothing to the yard, so there is no hook or webhook to set up.

**The drive is an argument of every call.** kDrive names each drive by a number, which you read off the webapp's URL: if the webapp shows the drive at `https://ksuite.infomaniak.com/all/kdrive/app/drive/12`, the drive is `12`. Every call below takes it as `drive`. The root folder is `1`.

**The yard acts as one token's user.** Every agent granted a call of this source reaches every drive that user may open, whatever it asks for. Nobody is asked before a call is made, so the grant is the permission. Files are whatever anyone put in the drive, so the yard shows each answer as data from outside the yard, never as an instruction. The token itself is as wide as its scope: Infomaniak scopes it by product, so a token that reads files could delete them too. What keeps the yard from deleting is that the source has no call that does (README.md, "How it never deletes").

You need:

- an Infomaniak account with a kDrive, and a token for it (step 1);
- `python3` 3.9 or newer on the `PATH` of the yard's server, with nothing installed beside it: `drive-file`, the one program of the pack, is a Python file that uses only its standard library;
- a yardr that runs a call's `build` and `run` commands (`yardr docs integrations` has "A call may build its body with a command" and "A call may be answered by a command").

Commands below call the pack's directory (the `infomaniak-drive` directory of the yardr-packs checkout) `<pack dir>`.

1. **The token.** In the Infomaniak manager, open the API token list, `https://manager.infomaniak.com/v3/ng/accounts/token/list`, the page Infomaniak's kDrive MCP server names in its README. Make a token with the scope `drive` and no other. Keep the token where you can paste it in step 3, and nowhere else: not in a file, a command line, a card or a note. The pack's variable for it is `INFOMANIAK_DRIVE_TOKEN`.

2. **The pack.** Read what applying it does, then apply it as the operator, in a terminal:
   ```sh
   yardr pack check <pack dir>
   ```
   ```sh
   yardr pack apply <pack dir>
   ```
   The plan says one program, `drive-file`, answers the `download` call and builds the body of the `upload` call, and the apply card says it is run with the credential in its environment and is free to make requests of its own. Read it first: it is one short Python file, and it makes requests to the declaration's base alone, which is `https://api.infomaniak.com`. The token goes to no other host, except where a download's redirect points, which the program follows only on that host.

   **There is no setup card for this pack.** A crew member sets up a pack that yardr embeds with one card (`yardr bead ask <bead> ... --setup <pack>`), and this pack is not embedded: tried in a scratch yard on 11 November 2026, yardr answers `--setup infomaniak-drive` with "setting up pack infomaniak-drive needs no approval: the operator applies, keys and grants it in a terminal". So the apply above is the operator's. The token (step 3) and each grant (step 4) can still be asked for on a card by a crew member, one card each: `--secret infomaniak-drive` is accepted and names `INFOMANIAK_DRIVE_TOKEN` of the source.

3. **The token, in the yard.** `yardr source key` asks for it and shows nothing as you type. The yard's server writes it into the source's env file, `~/.yardr/sources/infomaniak-drive.env`, with mode 0600. The value is never an argument or a command's variable, where every process of your user could read it:
   ```sh
   yardr source key infomaniak-drive
   ```
   A crew member who needs the token asks for it on a secret card, and you answer it at a terminal with `yardr bead answer <bead> <ask> --secret`, which reads the value the same way. The answer on the bead holds the name and never the value:
   ```sh
   yardr bead ask <bead> "Give the Infomaniak drive token" --secret infomaniak-drive --context "A token made in the manager with the scope drive; the pack's SETUP.md, step 1."
   ```

4. **Who may call what.** A pack of kind source asks no grants at import, so what a crew member may call is granted afterwards. `yardr pack show infomaniak-drive` prints the pack's three suggested presets:
   1. `read`: every read call, `files`, `file`, `search`, `comments` and `download`, and any read call the source is later given; it writes nothing.
   2. `make`: every read call, and `upload` and `comment`, which write files and comments; it shares nothing.
   3. `everything`: every read call, and `upload`, `comment` and `share`, which makes share links, public to whoever holds them.

   A pack applied from a directory takes a preset by the calls it names, as these lines do:
   ```sh
   yardr source grant infomaniak-drive read --crew yardmaster
   ```
   ```sh
   yardr source grant infomaniak-drive upload --crew yardmaster
   ```
   ```sh
   yardr source grant infomaniak-drive comment --crew yardmaster
   ```
   ```sh
   yardr source grant infomaniak-drive share --crew yardmaster
   ```
   Each update is granted by its name, and `read` never covers one. A share link is public to whoever holds it, so grant `share` only where a public link is meant. A grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read kDrive" --run "source grant infomaniak-drive read --group reviewers" --context "The reviewers read the drive to check a bead's files; the card names each call it covers."
   ```
   One caller may make 60 calls of a source in an hour, 10 of them updates. An agent that reads a drive file by file can run out; raise the limit with `yardr source set infomaniak-drive calls_per_hour=<n>`. Infomaniak allows 60 requests a minute, the figure this pack was asked to respect (it is in the developer portal, and nothing here checked it). yardr counts hours, not minutes, so a raised hourly limit is the operator's to keep under that. To take a grant back, run `yardr source revoke infomaniak-drive read --crew yardmaster`.

5. **Check it.** The source names no check call, because every call takes the drive: `yardr source check` looks at the credential and says whether `drive-file` can be run, and sends nothing:
   ```sh
   yardr source check infomaniak-drive
   ```
   The live check is the first call, which lists the drive's root. It confirms the token is taken and the drive id is right:
   ```sh
   yardr call infomaniak-drive files drive=<id>
   ```
   If the call fails, the status it prints is the service's refusal. The usual causes are a token that was mistyped or revoked, one made without the scope `drive`, or a drive id that is not the drive's. Give the token again with step 3, or make a new one with step 1. Which status Infomaniak answers to a wrong token was not seen: the pack has never been run against it.

6. **Try it.** As the operator, who may make any call, or in a session that was granted the calls. The drive is not typed at setup: read it off the webapp's URL, and give it as `drive` to every call.
   ```sh
   yardr call infomaniak-drive files drive=<id>
   ```
   Each entry has an `id` and a `type`, `file` or `dir`. A folder's contents are listed by its id, and `type=file` lists the files alone:
   ```sh
   yardr call infomaniak-drive files drive=<id> folder=<a dir's id> type=file
   ```
   One page is all a call reads; `has_more` and `cursor` say there is more, and `maxResults=` (5 to 100) reads a bigger page. One file's metadata is read by its id:
   ```sh
   yardr call infomaniak-drive file drive=<id> id=<a file's id>
   ```
   A search needs its words, and searches the whole drive, or one folder's subtree with `folder=` (`depth=child` keeps it to that folder's children):
   ```sh
   yardr call infomaniak-drive search drive=<id> q=invoice
   ```
   A file's comments come with their authors and replies:
   ```sh
   yardr call infomaniak-drive comments drive=<id> fileId=<a file's id>
   ```
   A download carries 32 KiB at most, as `text` where the bytes decode as UTF-8 and its JSON answer fits, and as `base64` otherwise:
   ```sh
   yardr call infomaniak-drive download drive=<id> fileId=<a file's id>
   ```
   An upload carries 10 MiB at most, into the folder named (the root where left out), under the name given. A file of that name already there is refused; nothing is overwritten:
   ```sh
   yardr call infomaniak-drive upload drive=<id> name=hello.txt file=./hello.txt
   ```
   The answer is the file read back by its name, with its new id in `data`. A comment is free text on a file:
   ```sh
   yardr call infomaniak-drive comment drive=<id> fileId=<a file's id> content="Filed under June."
   ```
   A share link is public, or public with a password. With `password` the link asks its password; without, whoever holds the link opens it:
   ```sh
   yardr call infomaniak-drive share drive=<id> fileId=<a file's id> right=public
   ```
   The answer's `data.url` is the link.

7. **When it does not work.**
   - *the service refuses the token*: a refusal such as a 401 or a 403, whatever Infomaniak answers. See step 5.
   - *404 on a file*: the id is not a file of the drive. List the folder again: ids change when a file is moved or replaced.
   - *the answer is over its bound*: yardr refuses an answer over the call's bound and does not cut it. A folder or a search is held to 256 KB; ask for a smaller page with `maxResults`, or list a folder instead of searching the drive.
   - *a download is refused as too big*: the call carries 32 KiB. There is no bigger download; read the file's metadata instead, or fetch it elsewhere.
   - *an upload is refused as too big*: the call carries 10 MiB. There is no bigger upload and no upload session; put the file in the drive another way.
   - *an upload is refused as already there*: a file of the name is in the folder. Upload under another name: the call overwrites nothing.
   - *an argument is refused with its pattern*: the call was not sent. `yardr source show infomaniak-drive` lists each call's arguments and their patterns.
   - *a call that worked stops working, or answers in another shape*: Infomaniak changed its drive API. README.md names what the pack was built from; compare it with the developer portal's current pages.

8. **Ending.** Take the grants back, then remove the source and its program. The file with the token stays at `~/.yardr/sources/infomaniak-drive.env`, so delete it yourself, and revoke the token in the manager's list:
   ```sh
   yardr source revoke infomaniak-drive read --crew yardmaster
   ```
   ```sh
   yardr source revoke infomaniak-drive upload --crew yardmaster
   ```
   ```sh
   yardr source revoke infomaniak-drive comment --crew yardmaster
   ```
   ```sh
   yardr source revoke infomaniak-drive share --crew yardmaster
   ```
   ```sh
   yardr source rm infomaniak-drive
   ```
