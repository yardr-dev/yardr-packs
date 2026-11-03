# Setting up Snowflake

The pack wires a Snowflake account into the yard as the declared source
`snowflake`. An agent may run a SELECT and read its first page of rows, list
the databases, schemas and tables, and read a statement back by its handle.
One call, kept apart, runs any other statement. Snowflake sends nothing in, so
there is no hook and no webhook to set up.

**The yard acts as one Snowflake user.** Every agent granted a call of this
source is that user to Snowflake, with that user's role. `query` accepts a
SELECT and nothing else, which catches a mistaken statement and fences
nothing: a SELECT reads all that the role may read. What the role is granted in
Snowflake is the bound. Make the user for the yard alone, and give its role the
databases the yard should read and no others. Nobody is asked before a call is
made; the grant is the permission.

This file uses the names of the trial account the pack was proved on: the user
`YARDR`, the role `YARDR_READ`, the warehouse `YARDR_WH` (a small one that step 2
makes), the shared database `SNOWFLAKE_SAMPLE_DATA` and the key file
`~/.yardr/keys/snowflake_rsa_key.p8`. Change them where yours differ.

You need a Snowflake account and `ACCOUNTADMIN` on it for step 2. The pack's
mint needs `openssl` and `jq` on the yard's machine. Commands below call the
pack's directory (the `snowflake` directory of the yardr-packs checkout)
`<pack dir>`.

1. **The key pair, on the yard's machine.** Snowflake takes a key-pair login:
   the yard signs a short-lived token with the user's private key, and
   Snowflake checks it against the public key it was given. The private key
   stays in a file that only you can read. It is never pasted into a command,
   a card or a note: the yard is given its path, and the mint reads it from
   there. Skip this step if the key already exists. A new file takes its mode
   from the shell's umask, so narrow it first. Each command below is one thing
   to type, in a block of its own:
   ```sh
   umask 077
   ```
   ```sh
   mkdir -p ~/.yardr/keys
   ```
   ```sh
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -nocrypt -out ~/.yardr/keys/snowflake_rsa_key.p8
   ```
   ```sh
   openssl rsa -in ~/.yardr/keys/snowflake_rsa_key.p8 -pubout -out ~/.yardr/keys/snowflake_rsa_key.pub
   ```
   ```sh
   chmod 600 ~/.yardr/keys/snowflake_rsa_key.p8
   ```
   The key must be RSA, in PEM, and without a passphrase (`-nocrypt`): the mint
   refuses an encrypted key rather than ask for its passphrase. The `.pub` file
   is the public key and is no secret.

2. **The role and the user, in Snowflake.** In a worksheet, as `ACCOUNTADMIN`.
   The role reads the sample data and nothing else, so `execute` fails on this
   account until you grant it more (step 5 says when that is wanted). The
   warehouse is the compute a SELECT runs on and is billed while it runs; this
   one is the smallest size and suspends after a minute. An account that
   already has a warehouse the yard may use can name that one instead. The
   sample database is in most accounts; the `CREATE DATABASE` statement makes it
   from Snowflake's share where it is missing, and does nothing where it is
   there:
   ```sql
   USE ROLE ACCOUNTADMIN;
   CREATE WAREHOUSE IF NOT EXISTS YARDR_WH WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
   CREATE DATABASE IF NOT EXISTS SNOWFLAKE_SAMPLE_DATA FROM SHARE SFC_SAMPLES.SAMPLE_DATA;
   CREATE ROLE IF NOT EXISTS YARDR_READ;
   GRANT USAGE ON WAREHOUSE YARDR_WH TO ROLE YARDR_READ;
   GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE YARDR_READ;
   CREATE USER IF NOT EXISTS YARDR TYPE = SERVICE DEFAULT_ROLE = YARDR_READ DEFAULT_WAREHOUSE = YARDR_WH;
   GRANT ROLE YARDR_READ TO USER YARDR;
   ```
   A worksheet may run only the statement the cursor is in: select all of them
   before you run, or run them one at a time. Give the user its public key: the
   body of the `.pub` file on one line,
   without the `-----BEGIN PUBLIC KEY-----` and `-----END PUBLIC KEY-----`
   lines. This prints it:
   ```sh
   grep -v -e '-----' ~/.yardr/keys/snowflake_rsa_key.pub | tr -d '\n'; echo
   ```
   ```sql
   ALTER USER YARDR SET RSA_PUBLIC_KEY = '<the line above>';
   ```
   Snowflake names the key by its fingerprint, and the token the mint signs
   names the same one. Check that they agree. In the worksheet,
   ```sql
   DESCRIBE USER YARDR;
   ```
   shows `RSA_PUBLIC_KEY_FP`, a `SHA256:` and a string of letters. This prints
   the string for the key file, which must be the same after the `SHA256:`:
   ```sh
   openssl rsa -in ~/.yardr/keys/snowflake_rsa_key.p8 -pubout -outform DER 2>/dev/null | openssl dgst -sha256 -binary | openssl base64
   ```
   If Snowflake says the user does not exist, the statements above did not run:
   run them again. If `RSA_PUBLIC_KEY_FP` is empty or is another string, the user
   does not have this key. `CREATE USER IF NOT EXISTS` leaves a user that was
   already there as it was, so run the `ALTER USER` above again, and describe the
   user again. Snowflake answers every token it cannot match to a user and a key
   in the same way, with a 401 and `JWT token is invalid`, whichever of them is
   missing, so this check is how you tell.

3. **The pack and the account's address.** Apply the pack as the operator:
   ```sh
   yardr pack apply <pack dir>
   ```
   The declaration it installs gives the source a placeholder address,
   `https://example.snowflakecomputing.com`. A source's credential goes only to
   the hosts its file names, so the yard's copy of the file must name yours.
   Your account identifier is the organization's name and the account's, joined
   by a hyphen. Snowsight shows it in the details of the account, and a
   worksheet prints it:
   ```sql
   SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();
   ```
   An older account is known by its locator and region instead, such as
   `xy12345.us-east-2.aws`, and the address and the next step use that. Write
   the address into a copy of the declaration, beside the original so that the
   program it names is found, and add the copy to the yard. The copy is ignored
   by git.
   ```sh
   sed 's|^base: .*|base: https://<account identifier>.snowflakecomputing.com|' <pack dir>/snowflake.yaml > <pack dir>/snowflake.local.yaml
   ```
   ```sh
   yardr source add <pack dir>/snowflake.local.yaml
   ```
   ```sh
   yardr source show snowflake
   ```
   The first line of `source show` is the address in use. Until it is yours,
   `yardr source check snowflake` calls the placeholder and fails.

4. **The three names, in the yard.** The credential is three names, none of them
   a secret: `SNOWFLAKE_ACCOUNT`, the account identifier of step 3, written the
   way you gave it there (the mint turns it into what Snowflake wants in a
   token: capitals, and no region on a locator); `SNOWFLAKE_USER`, the user's
   name, `YARDR`; and `SNOWFLAKE_KEY_FILE`, the key's whole path, with no `~`
   since nothing expands it. The pack's `snowflake/mint` signs a token from the
   key at that path, once an hour. The key itself is not a variable and is in
   no file the yard writes. The three names go in the source's env file, mode
   0600, which `yardr source key` writes from lines on its standard input:
   ```sh
   printf 'SNOWFLAKE_ACCOUNT=%s\nSNOWFLAKE_USER=%s\nSNOWFLAKE_KEY_FILE=%s\n' '<account identifier>' 'YARDR' "$HOME/.yardr/keys/snowflake_rsa_key.p8" | yardr source key snowflake
   ```
   Then check the source:
   ```sh
   yardr source check snowflake
   ```
   The check mints a token, runs `SHOW DATABASES` and prints what the role can
   see. An answer of 401 means Snowflake did not take the token. The usual
   causes are a user that has no public key, or one that is not this key's
   (compare the fingerprints in step 2), an account identifier that is not the
   one the address uses, and a machine whose clock is wrong, since the token is
   dated by it.

5. **Who may call what.** The reads are granted by `read`, which covers
   `query`, `databases`, `schemas`, `tables` and `status`. `execute` is the one
   call that changes anything and is granted by its name alone, to each group or
   crew member that needs it. `yardr pack show snowflake` prints the two presets
   the pack suggests, `read` and `write`, and a pack applied from a directory
   takes them by name, as these lines give them:
   ```sh
   yardr source grant snowflake read --crew yardmaster
   ```
   A grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers query Snowflake" --run "source grant snowflake read --group reviewers" --context "The reviewers check an answer that was read from Snowflake; the card names each call it covers."
   ```
   `execute` is granted separately, and only where the role may change data. On
   the trial account it may not, so granting it only makes it answer 422:
   ```sh
   yardr source grant snowflake execute --crew yardmaster
   ```
   A grantee reads with the role the user has, and a call may name another with
   its `role` option. Give the user one role. A user given a second, wider role
   makes that role open to everyone who may `query`, who can then read with it.
   One caller may make 60 calls of a source in an hour, 10 of them updates; if
   an agent that explores a schema runs out, raise it with `yardr source set
   snowflake calls_per_hour=<n>`.

6. **Try it.** In a session that was granted `read`, or as the operator:
   ```sh
   yardr call snowflake databases
   ```
   ```sh
   yardr call snowflake query statement="SELECT C_CUSTKEY, C_NAME, C_ACCTBAL FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER ORDER BY C_ACCTBAL DESC LIMIT 5"
   ```
   The answer is the statement's handle, the columns (`resultSetMetaData`) and
   the first page of the rows (`data`), every value a string. The call ends
   after 30 seconds; for a statement that may take longer, add `async=true` to
   get its handle at once, then read it from `status`, which answers a running
   statement with a code and a message and no data:
   ```sh
   yardr call snowflake status handle=<the statementHandle of the answer>
   ```
   To see the whole pack work against the account without touching your yard,
   run `live-check` of the pack's directory. It makes a scratch yard of its own,
   gives it the three names of step 4, and reads: the databases, the schemas and
   tables of the sample data, a SELECT, its status, and the same SELECT as an
   async statement. It makes only SELECTs and SHOWs, prints counts and column
   names and no row, and removes the scratch yard. A user other than `YARDR`, or
   a key file other than step 1's, follows as the next arguments:
   ```sh
   <pack dir>/live-check <account identifier>
   ```

7. **Updating the pack, and a key that changes.** A pack applied again replaces
   the source's declaration whole, and the placeholder address comes back with
   it. Your env file and the grants stay. After pulling the checkout, read what
   would change:
   ```sh
   yardr pack check <pack dir>
   ```
   If you apply the pack, the plan lists the address as `base: <your address> ->
   https://example.snowflakecomputing.com`. That line is how you notice. Until
   you add your copy again, the credential is held back from the placeholder,
   and `yardr source check snowflake` says so. The shorter way skips the apply:
   make the copy again from the new `snowflake.yaml` with step 3's `sed` and add
   it with `yardr source add`.

   To change the key, give the user the new public key as a second one, switch
   the file the yard names, and then take the old one away:
   ```sql
   ALTER USER YARDR SET RSA_PUBLIC_KEY_2 = '<the new public key>';
   ```
   Put the new private key at the path of `SNOWFLAKE_KEY_FILE`, or give the new
   path as in step 4, and check the source. A token already minted lives until
   its hour ends, an hour at most. Then
   ```sql
   ALTER USER YARDR UNSET RSA_PUBLIC_KEY;
   ```

8. **Ending.** Remove the source, which takes its grants with it, and the
   files:
   ```sh
   yardr source rm snowflake
   ```
   ```sh
   rm ~/.yardr/sources/snowflake.env ~/.yardr/keys/snowflake_rsa_key.p8 ~/.yardr/keys/snowflake_rsa_key.pub
   ```
   In Snowflake, `DROP USER YARDR;` and `DROP ROLE YARDR_READ;` end the access.
