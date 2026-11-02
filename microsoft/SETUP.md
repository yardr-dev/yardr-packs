# Setting up Microsoft

The pack wires SharePoint and OneDrive into the yard as the declared
source `microsoft`. An agent lists a tenant's sites, a site's document
libraries, and the folders and files of a library, reads one item's
metadata and its link, and searches documents by words. It only reads,
and it does not download full file bytes. Search hits may include short
text excerpts from matching documents.

Read this before the steps. The yard reads as one Microsoft Entra app,
an identity of its own with no person signed in. Whatever that app may
read, every agent the operator grants this source reads, and the yard
does not narrow it per person. Where different people may see different
documents, this source does not fit: a folder per group of people,
synced by IT, is the safer route. Choose the app's permission with that
in mind.

The steps are for whoever runs Microsoft 365 for the team. They follow
Microsoft's Graph and Entra documentation as of 2 November 2026, and
none was run against a tenant when the pack was written.

Which application permission? Each is added in step 3, and each gives
the app what Microsoft's own words say:

- **Sites.Selected.** "Allow the application to access a subset of site
  collections without a signed in user. The specific site collections
  and the permissions granted will be configured in SharePoint Online."
  It reads nothing until step 4 grants it a site, and then only that
  site. Microsoft says site search does not support it, and its Search
  API page does not list it. So with it `drives`, `root`, `children` and
  `item` should work (as the documentation reads, not as tried) and
  `sites` and `search` will not. This is the narrow choice, and the one
  to prefer.
- **Files.Read.All.** "Allows the app to read all files in all site
  collections without a signed in user." Every file in the tenant. It
  adds `search` to the four above.
- **Sites.Read.All.** "Allows the app to read documents and list items
  in all site collections without a signed in user." Every document and
  list item in the tenant. It adds `sites` to what Files.Read.All gives.

If the team wants search, one of the last two is the narrowest Microsoft
lists for it, and the app then reads the whole tenant.

1. **Register the app.** In the Microsoft Entra admin center
   (https://entra.microsoft.com), signed in as at least an Application
   Developer: Entra ID, App registrations, New registration. Name it for
   what it does, such as "yardr documents". Under Supported account
   types choose "Single tenant only". Register. On the app's Overview
   page copy the Application (client) ID and the Directory (tenant) ID.
2. **Make a client secret.** Certificates & secrets, Client secrets, New
   client secret. Microsoft limits a secret to 24 months. Copy the
   Value at once, since the page never shows it again, and not the
   Secret ID beside it. Microsoft's own page says a client secret
   "should not be used" in production and prefers a certificate or a
   federated credential. This pack takes a secret, and a certificate
   mint would be a later bead. Put the expiry date in a calendar,
   because on that day every call fails with AADSTS7000222 until step 7
   is done again with a new secret.
3. **Give the app its permission.** API permissions, Add a permission,
   Microsoft Graph, Application permissions (not Delegated), then the
   one chosen above. Add permissions, then "Grant admin consent for" the
   tenant, which takes an administrator who may consent to application
   permissions. A delegated permission such as User.Read on the list is
   not used and can go.
4. **Sites.Selected only: grant the app each site.** The permission
   reads nothing until a site is granted it. Per Microsoft, the caller
   needs the permission Sites.FullControl.All, either as an application
   or as a delegated user who holds a SharePoint administrator role or
   higher and is a member of the site. First the site's id, from its
   address (`contoso.sharepoint.com` and `/sites/Marketing` here). The
   `id` in the answer, `contoso.sharepoint.com,<guid>,<guid>`, is what
   the yard is given later:
   ```http
   GET https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com:/sites/Marketing
   ```
   Then the grant, with the role `read` and no other (the roles Microsoft
   lists are read, write, owner and fullcontrol), and the Application
   (client) ID of step 1:
   ```http
   POST https://graph.microsoft.com/v1.0/sites/{site id}/permissions
   Content-Type: application/json

   {"roles": ["read"], "grantedToIdentities": [{"application": {"id": "<Application (client) ID>", "displayName": "yardr documents"}}]}
   ```
   `GET` on the same address lists what a site has granted, and `DELETE`
   on `/permissions/{permission id}` takes a grant back.
5. **Search only: the region.** App-only search must say where the
   tenant's data lives, and the call takes it as `region`: the
   PreferredDataLocation code of Microsoft's Multi-Geo page, three
   capitals. `NAM` is the United States, `GBR` the United Kingdom, `CAN`
   Canada, `AUS` Australia, `IND` India and `JPN` Japan. `EUR` covers a
   group of European countries and `APC` a group of Asia-Pacific ones.
   The page lists the rest
   (https://learn.microsoft.com/microsoft-365/enterprise/microsoft-365-multi-geo).
   Graph answers the code as `dataLocationCode` for a Multi-Geo tenant
   and for no other. Tell the agents the code, in the yardmaster's
   instructions or the grant's context, since the declaration cannot
   hold it. Search finds shared content only. A file only its owner's
   OneDrive holds privately is not found.
6. **Apply the pack.** As the operator, from main of a checkout of the
   yardr-packs repository:
   ```sh
   yardr pack apply <checkout>/microsoft
   ```
7. **Give the yard the three values.** The tenant (the Directory ID or
   a domain such as `contoso.onmicrosoft.com`), the Application ID and
   the secret's Value. The command asks for each and shows nothing as
   it is typed:
   ```sh
   yardr source key microsoft
   ```
   A crew member who needs them asks on a card instead, and the
   operator answers it at a terminal:
   ```sh
   yardr bead ask <bead> "Give the yard its Microsoft app?" --secret microsoft --context "The tenant ID, the app's client ID and a client secret's Value, from the app registration in the Entra admin center."
   ```
   The values reach `microsoft-mint`, the program the pack brings, on
   its standard input and nowhere else. It sends them to
   login.microsoftonline.com, through the proxy and company CA
   variables the yard hands on, and answers a token good for about an
   hour that the yard keeps in memory alone. When the secret is
   replaced, give the new Value alone:
   ```sh
   yardr source key microsoft MICROSOFT_CLIENT_SECRET
   ```
8. **The grant.** A pack of kind source asks none at import, so what a
   crew member may call is granted afterwards. The pack's one preset,
   as `yardr pack show microsoft` prints it:
   1. `read`: every call, which lists, searches and reads and changes
      nothing, and it covers any read call the source is later given.
   The app is one identity, so a grant of `read` lets that crew member
   or group read everything the app may read. Grant it to those who need
   it:
   ```sh
   yardr source grant microsoft --preset read --crew yardmaster
   ```
   A grantee who comes later gets one card:
   ```sh
   yardr bead ask <bead> "Let the reviewers read Microsoft documents" --run "source grant microsoft --preset read --group reviewers" --context "The reviewers read the team's documents to check a bead's work; the card names each call it covers."
   ```
   One caller may make 60 calls of a source in an hour, and an agent
   that walks a library folder by folder uses them quickly. The
   operator raises the limit where the work needs it:
   ```sh
   yardr source set microsoft calls_per_hour=300
   ```
9. **Try it.** The file names no check call, because which call works
   depends on the permission (`sites` and `search` fail under
   Sites.Selected), so `yardr source check microsoft` reports where the
   three values are set and sends nothing. The first call is the test.
   With Sites.Read.All:
   ```sh
   yardr call microsoft sites query=Marketing
   ```
   With Sites.Selected, from step 4's site id:
   ```sh
   yardr call microsoft drives site=contoso.sharepoint.com,<guid>,<guid>
   ```
   A call that stops before it reaches Graph is the mint, and its error
   names the code Entra gave. AADSTS7000215 is an invalid client secret:
   check that the Value was typed and not the Secret ID. AADSTS7000222
   is an expired secret. AADSTS700016 is an Application ID the tenant
   does not know, and AADSTS90002 a tenant it cannot find. A 401 or 403
   from Graph itself points at the app's permission, the admin consent
   or, under Sites.Selected, the grant on that site.
10. **What an agent does with it.** Ids come from the call before. From
    a site's id to its libraries, from a library's id to its top level,
    from a folder's id to what is in it, and from an item's id to its
    link:
    ```sh
    yardr call microsoft drives site=<site id>
    ```
    ```sh
    yardr call microsoft root drive=<drive id>
    ```
    ```sh
    yardr call microsoft children drive=<drive id> item=<folder id>
    ```
    ```sh
    yardr call microsoft item drive=<drive id> item=<item id>
    ```
    `webUrl` in the answer is the link a person opens. Search answers hits
    with the same `webUrl` and a `parentReference` that carries the
    `driveId` and `siteId`; Graph may also return a short matching text
    excerpt in each hit's `summary`. `size` and `from` page through them:
    ```sh
    yardr call microsoft search query="budget 2026" region=NAM
    ```
    `root` and `children` answer one page of 50 items, and `top` asks for
    another size. An answer that has more keeps `@odata.nextLink` and
    follows none.

What is not there, on purpose: downloading full file contents (no call
here downloads a file's bytes, and every driveItem request leaves out
the download link Graph would otherwise add; search results may include
short text excerpts); any write; Outlook, Teams, mail and calendar;
reading as each person, with their own sign-in, which the yard does not
build yet; delta sync; paging past the first page; private OneDrive
content in search; and the national clouds, since the pack speaks to
login.microsoftonline.com and graph.microsoft.com alone. The yard's
source format cannot express what is not listed, and the pack does not
change yardr.
