# CopyQ Command Suite

A curated Windows command collection for [CopyQ](https://github.com/hluk/CopyQ) 16. It combines privacy-aware clipboard routing, automatic Markdown rendering, OCR, code highlighting, translation, text utilities, and optional Moonlander selected-text commands.

The repository distributes eighteen original or independently rewritten commands, plus an optional protection-only alternative. Community commands used in the author's personal setup are credited and linked, but their source is not republished here.

## Clipboard Router or Secret Protection (Standalone)?

**For the suite's automatic sorting and Frequent index, choose Clipboard Router.
It already includes secret protection. You do not need both commands.**

Clipboard Router is an automatic command that decides what happens to each new
copy **in CopyQ history**. "Router" means sorting copied text into the appropriate
tab; it has nothing to do with a network router. It combines three jobs:

1. **Protect history:** exclude detected standalone secrets and redact recognized
   secrets inside documents, while leaving immediate ordinary paste unchanged.
2. **Sort text:** send URLs, code, substantial technical artifacts and large text
   to their appropriate tabs; leave ordinary text in the normal clipboard tab.
3. **Build a Frequent index:** count eligible copies and add a secondary entry in
   `Frequent` after six copies, without taking it out of its primary destination.

**Secret Protection (Standalone)** is the same first job packaged on its own. It
is for someone who wants secret filtering but wants to keep their existing tab
organisation, or does not want the suite's automatic sorting and copy counting.
"Standalone" means it works without Clipboard Router, not that it adds another
layer of protection to it.

| Feature | Clipboard Router | Secret Protection (Standalone) |
|---|---|---|
| Exclude detected standalone secrets from history | Yes | Yes, same rules |
| Redact recognized secrets inside saved documents | Yes | Yes, same rules |
| Leave the current clipboard unchanged for immediate paste | Yes | Yes |
| Sort eligible text into URLs, Code, Artifacts and BIG tabs | Yes | No; other commands may still sort it |
| Count copies and maintain the Frequent index | Yes | No |
| Included in the general-purpose and complete bundles | Yes | No; optional alternative |

Both run automatically when you copy; neither is a command you must invoke for
each item. Enable **one**, and put it first among automatic commands. Enabling
both causes `SECRET_HANDLER_CONFLICT`, not stronger protection. Leaving the
standalone option unchecked when the router is installed is therefore correct.

Neither command includes OCR, translation, Markdown rendering, code highlighting,
undoable deletion or Moonlander transformations: those are separate commands you
can choose independently, subject to their documented dependencies. Secret
detection remains heuristic; neither option guarantees that every secret is found.

## Quick start

For a guided Windows setup, extract the complete package and open **CopyQ-Setup.cmd**
as your normal user with CopyQ 16.0.0 already running. The PowerShell 7.2+ wizard
lets you select commands, load/save a nonsecret profile, resolve shortcuts,
preview changes, install with a command-only rollback backup, and verify the
installed definitions. It does not download dependencies or back up clipboard
history. See the [setup and recovery guide](docs/SETUP.md). No Node.js or Pester
is required to use the wizard or prebuilt imports.

You can also open `CopyQ-Setup.cmd` directly from a complete repository checkout.
For one-command updates, click **Uncheck all**, then select only the command you
want. Shortcut edits remain intact. **Read installed selection** is optional and
also recognizes the three original Moonlander wrappers without suite IDs; it
does not modify them. Installation changes only the selected commands.
To update without Azure, read the installed selection and uncheck **Translate to
English** before previewing. Unchecked commands stay unchanged; translation is
optional and does not block installation of the other tools.

Manual installation remains available:

1. Install CopyQ 16.
2. Download an individual command from the [command catalogue](docs/commands/COMMANDS.md), or choose a bundle:
   - [`commands/bundles/canonical.ini`](commands/bundles/canonical.ini) — fifteen general-purpose commands.
   - [`commands/bundles/moonlander.ini`](commands/bundles/moonlander.ini) — three Moonlander integrations.
   - [`commands/bundles/all.ini`](commands/bundles/all.ini) — all eighteen commands.
3. Open CopyQ, press `F6`, choose **Load Commands**, select the downloaded INI (not a saved GitHub HTML page), review the command list, and confirm. For undoable deletion, import both **Move to Trash (Undoable)** and **Undo Delete**, then exit and restart CopyQ so the listener loads.
4. Run the optional dependency report when using rendering, highlighting, OCR, translation, or Moonlander features:

   ```powershell
   pwsh -NoProfile -File .\scripts\Test-Dependencies.ps1
   ```

Importing a command file does not install external programs or migrate existing history. Once enabled, automatic commands can route new copies, and the undo listener can prune expired `(trash)` entries. Existing CopyQ settings are retained; the suite does not set your item limit, encryption or autostart preferences.

Put **Clipboard Router first in the command list**, ahead of all automatic commands, including community image and URL handlers. Importing a replacement can append it at the bottom: move it back to the top before applying. Earlier commands can store or fetch data before a later `ignore()` call.

**Clipboard Router is the new display name for Canonical Dispatcher.** It retains the same internal identity and import filename. Replace the old command; do not keep both.

### Installing the protection-only alternative

Import [`commands/alternatives/secret-protection.ini`](commands/alternatives/secret-protection.ini) instead of Clipboard Router. **Secret Protection (Standalone)** provides the same exclusion/redaction behaviour, but does not route items to tabs or count copies. Put it first, followed by whichever other commands you use.

Do not enable it alongside Clipboard Router/Canonical Dispatcher. An enabled duplicate or conflicting handler stops processing with `SECRET_HANDLER_CONFLICT` until the extra handler is removed. This optional alternative is deliberately excluded from all three standard bundles.

### Modular source, self-contained imports

Each suite command now has its own source file under `src/runtime/`. Secret detection, URL rules, artifact detection, routing, frequency state and utility helpers have separate implementations under `src/core/`. Generated commands embed only their required modules: title case no longer includes secret detection, for example. See [source architecture and contribution guide](docs/ARCHITECTURE.md).

This source refactor does not require you to reinstall a working setup. To adopt a newer generated command, replace that command alone. Do not import a full bundle over an existing installation.

### Updating an existing setup: secret redaction and URL routing

1. In `F6`, select all current commands and save a command backup outside the checkout.
2. Replace only **Canonical Dispatcher / Clipboard Router** with `commands/individual/canonical-dispatcher.ini` and move it to the top. Leave its Format field empty so concealment metadata is checked even without plain text.
3. Disable **Copy URL (web address) to other tab** if it targets `&web`. The dispatcher now routes standalone HTTP(S), FTP(S), and file URLs into `&URLs` without requiring an HTML response or a network connection.
4. If retaining **Tab for URLs with Title and Icon**, keep it after the dispatcher and set its Content filter to `^https?://\S+$`. It is optional enrichment, not the storage gate. That upstream command fetches copied addresses and can log URLs; disable it if automatic fetching is unwanted.
5. Apply once. Existing history is not migrated or deleted by this update. Keep the old `web` tab until its unique items are safely preserved; blindly combining two full tabs can exceed CopyQ's item limit. Do not bulk-copy known credentials into `URLs`.

To roll back the commands, replace the command list with the saved backup (do not append the backup to the existing commands). History is unaffected by this command-only update.

### Original paste versus redacted paste

For newly copied text containing a recognized embedded credential:

| Action | Result |
|---|---|
| Copy, then paste normally with Ctrl+V | Original text from the current Windows clipboard, including the credential. |
| Select/paste the saved item from CopyQ | Text with the credential permanently replaced by `[REDACTED]`. |
| Copy something else, then return to the older CopyQ item | Only the redacted version is available; CopyQ has no hidden original to restore. |

Selecting the saved item is also the way to share the redacted version immediately. It replaces the current clipboard with that safe history item. There is no new shortcut, vault, timeout, or recover-original command. The original can remain on the current Windows clipboard until something replaces it; this feature does not securely erase process memory or control Windows clipboard history/cloud sync, other clipboard tools, or the source application.

Whole standalone keys and password-manager concealment metadata continue to be **excluded** from history, with `SECRET_IGNORED`. Mixed documents instead receive `SECRET_REDACTED`. Recognized embedded forms include supported provider-prefixed tokens, structurally valid JWTs, private-key PEM blocks, authorization headers, and explicit password/token/secret/API-key assignments. Generic mixed-case words and unlabeled hashes inside documents are not guessed to be secrets.

Generic standalone-password guessing applies only to 10–150 characters without whitespace and with at least two of lowercase letters, uppercase letters and digits, subject to the existing URL/path/UUID/version exceptions. Bare hexadecimal strings of 32–128 characters are also excluded: this intentionally favours protection over retaining an ambiguous standalone checksum. Valid JSON objects and arrays are not treated as one password, even when compact; their contents are still scanned for recognized embedded credentials. The 150-character cap does not disable recognition of longer provider tokens, private keys or explicitly labelled credentials. Unchanged documents produce no secret notification; `SECRET_REDACTED` reports a replacement, not a guarantee that every possible secret was found.

Ordinary URLs remain intact, including random-looking paths, IDs, and query values. Exceptions are recognizable credential forms: a password in URL user information, explicitly named `access_token`, `api_key`/`apikey`/`api-key`, `password`, `secret`, or `token` parameters, and private Google Calendar ICS feed tokens. Only the credential component is replaced. A redacted credential URL is for reference/sharing and may no longer work.

When redaction is needed, the history payload discards **all original alternate formats**, including HTML, RTF, image and custom data, not just the visible secret. Later renderers may generate fresh HTML from the sanitized text. The original rich formatting remains available through immediate ordinary paste, but it cannot be recovered from the saved history item. Redacted items are excluded from frequency counting. Undo can restore the redacted item, never its removed credential.

For a harmless acceptance test, copy `Please use ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa for this request`. Paste directly into a disposable editor: expect the original. Then choose the new item from CopyQ: expect `Please use [REDACTED] for this request`. Repeat using the mouse copy action and a website copy button with **synthetic data only**. A browser/mouse-specific live result still needs this check; automated tests do not operate your physical devices.

## What is included

| Area | Commands |
|---|---|
| Clipboard automation | Clipboard Router; Move to Trash (Undoable); Undo Delete; Remove Background and Text Colors |
| Rendering and extraction | Render Markdown; Highlight Code; Copy Text in Image |
| Translation | Translate to English |
| Data and search | Copy Items as JSON; Paste Items from JSON; Search All Tabs; Copy and Search on Web |
| Text tools | To Title Case; Toggle Upper/Lower Case; Show Frequent |
| Moonlander | Moonlander: Smart Title Case; Moonlander: Cycle Case; Moonlander: Transplant Hebrew-English |

The [full catalogue](docs/commands/COMMANDS.md) explains activation, dependencies, privacy, strengths, and limitations for every command and links every individual INI.

## Optional dependencies

| Feature | Dependency |
|---|---|
| Core commands | CopyQ 16 |
| Render Markdown | `marked` (`npm install -g marked`) |
| Highlight Code | Python 3 and Pygments (`python -m pip install Pygments`) |
| Copy Text in Image | Tesseract OCR with Tesseract eng and Tesseract heb language data |
| Translate to English | PowerShell 7 and Azure Translator |
| Moonlander commands | [Moonlander Custom Config](https://github.com/YiftahCooper/Moonlander-Custom-Config) |

`Test-Dependencies.ps1` is read-only. It reports what is available but never installs packages, changes `PATH`, requests elevation, or reads an Azure key.

OCR is entirely local and does not require Azure. It finds Tesseract in its
standard Program Files location or an existing executable in `PATH`. Select a
PNG and run **Copy Text in Image**, then paste into a text editor: the image stays
in history while recognized text replaces the clipboard. Code highlighting uses
an explicit Python lexer for recognizable Python declarations and language
guessing for other snippets; ambiguous snippets can still be misidentified.

## Azure translation setup

Translation is optional and sends selected text to Azure. Separately installed community URL enrichment can fetch copied addresses automatically. Create an Azure Translator resource, note its region, then run:

```powershell
pwsh -NoProfile -File .\scripts\Install-CopyQTranslation.ps1 -Region germanywestcentral
```

The script copies three helper files beneath `%LOCALAPPDATA%\CopyQCommandSuite\translation`, prompts for the key using a secure input field, protects it for the current Windows user with DPAPI, and stores the non-secret region separately. The key, source text, translation, and Azure response are not logged or placed in this repository.

After configuration, select a text item in CopyQ and run **Translate to English** from the context menu. The translated English text becomes the clipboard content.

## Moonlander integration

The three CopyQ command wrappers are included here, but their transaction scripts and reselection helper belong to [YiftahCooper/Moonlander-Custom-Config](https://github.com/YiftahCooper/Moonlander-Custom-Config). Install that companion project first. The wrappers resolve it from `%LOCALAPPDATA%\MoonlanderTextTools` and retain exclusive ownership of:

- F13 — Moonlander: Smart Title Case
- F19 — Moonlander: Cycle Case
- F22 — Moonlander: Transplant Hebrew-English

If those keys are already assigned to other CopyQ commands, resolve the collision before importing the Moonlander bundle.

## Privacy and failure behaviour

- Clipboard Router excludes standalone secrets (`SECRET_IGNORED`) and permanently redacts recognized credentials in mixed text (`SECRET_REDACTED`) before saving it. Notifications contain reason codes, not copied content.
- Secret checks precede image/owner passthrough, and a notification failure cannot skip suppression. Private Google Calendar ICS capability links are sensitive URLs; public feeds, normal addresses, and local/file URLs are not automatically secrets.
- Detection is heuristic: unfamiliar, unlabeled or encoded secrets can still escape it, and explicit credential-like labels can produce false positives. This is not encryption, a guaranteed secret detector, or retroactive cleanup of old history, trash, exports or backups. If rewriting the history payload fails, the item is excluded and `SECRET_REDACTION_FAILED` is reported.
- Substantial JSON, command blocks, transcripts, logs, stack traces, diffs, and configuration blocks route to `Artifacts`; short commands, standalone paths, `git status`, and ordinary prose stay in the normal history.
- Eligible text from normal history, `&URLs`, `BIG`, `Artifacts`, and `Code` is counted independently of its primary tab. On copy six, a trimmed text-only copy is added to `Frequent`; the primary item remains where it belongs.
- Frequency state stores at most 4,096 dual-hash counters and recency values, not copied text. Leading and trailing whitespace do not create separate counters.
- Deletion moves complete items into `(trash)` and `Ctrl+Z` in the CopyQ window restores the newest removal batch. Entries at least 30 days old are pruned at startup and before another deletion, not by a timer; they can remain longer while CopyQ is idle. Trash also inherits your configured tab item limit (110 in the author's setup), which can evict entries sooner. Delete sensitive material from `(trash)` as well when immediate permanent removal is required.
- Markdown, highlighting, and OCR run locally.
- Azure receives only text explicitly sent through Translate to English.
- Missing tools leave the current clipboard item intact and report bounded codes such as `MARKDOWN_FAILED`, `PYGMENTS_FAILED`, `OCR_FAILED`, or `TRANSLATE_NOT_CONFIGURED`.
- Generated exports and public files are scanned for local home paths, credentials, backups, and private configuration.

## Build and test

Building is optional: normal users can import the committed INIs. To build and test, use Windows, a normal-user **PowerShell 7** session in the repository root, Node.js with npm, Git for Windows, and **CopyQ 16.0.0**. The exporter deliberately requires that exact CopyQ version for repeatable output. Verification for this refactor used Node 24 and Pester **3.4.0**; the Pester 5 assertion syntax is not interchangeable. Install or make Pester 3.4.0 available before running the test block. OCR/Pygments tests also require the dependencies listed above; Azure tests use synthetic credentials and mocked HTTP responses, not a live subscription.

The committed INI files are generated from the JavaScript command model through one isolated CopyQ session. Run each step only if the preceding step succeeds:

```powershell
npm test
npm run build
Import-Module Pester -RequiredVersion 3.4.0
$copyqTests = Invoke-Pester .\tests -PassThru
if ($copyqTests.FailedCount) { throw 'CopyQ tests failed' }
```

Expect zero failures. The build creates eighteen integrated individual exports, one standalone protection alternative, and three bundles; it imports every result back into the isolated session and never connects to or modifies the normal CopyQ session. Tests use disposable settings and item storage. A failed test is a stop condition, not permission to activate the candidate; after correcting its cause, rerun the failed test step. Rebuilding rewrites generated INIs and is safe to repeat; it does not install commands into your live setup.

## Community commands

Several excellent commands used alongside this collection come from [`hluk/copyq-commands`](https://github.com/hluk/copyq-commands). They are not distributed here. See [credits and recommended community commands](docs/CREDITS.md) for direct source links and contributor attribution.

In particular, **Move to Trash (Undoable)** and **Undo Delete** are independent implementations inspired by `hluk`'s maintained [Undoable Move to Trash](https://github.com/hluk/copyq-commands/blob/master/commands/undoable-move-to-trash.ini). This suite adds private batch metadata, lazy 30-day cleanup, complete-item restoration, and integration with the Frequent counter; it does not republish the upstream command body.

## License

This project is licensed under `GPL-3.0-only`; see [LICENSE](LICENSE). CopyQ is a separate GPL-licensed project. Referenced community commands remain governed by their respective upstream repositories and are not included here.
