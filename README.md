# CopyQ Command Suite

Make your clipboard easier to use: keep logs and code out of the way, find text you copy often, recover deleted items, read text from images, and keep detected secrets out of saved history.

This is a collection of optional commands for [CopyQ](https://github.com/hluk/CopyQ), a clipboard manager that remembers what you copy. It is made for **Windows and CopyQ 16**. Choose the commands you want; you do not need to install everything.

There are **18 commands**, available separately or in bundles, plus a secret-protection-only alternative. Most work entirely on your PC. Translation is optional and uses Azure; web search opens the website you choose.

- [Install with the setup assistant](#install-with-the-setup-assistant)
- [Install commands manually](#install-commands-manually)
- [What each command does](#what-each-command-does)
- [How secret protection works](#how-secret-protection-works)
- [Extra software for optional features](#extra-software-for-optional-features)
- [Credits](#credits-and-license)

## Install with the setup assistant

This is the easiest way to choose commands, update an existing setup, and check that installation succeeded.

You need **CopyQ 16.0.0** running and [PowerShell 7.2 or newer](https://github.com/PowerShell/PowerShell). Run setup from your normal Windows account, without administrator mode.

1. Download this repository using GitHub's **Code → Download ZIP**, then extract it. A complete Git checkout also works. Keep the folder together: the launcher needs the files beside it.
2. Double-click **[CopyQ-Setup.cmd](CopyQ-Setup.cmd)** in that folder.
3. Choose a preset or check individual commands. **Essentials** is a useful starting point. Features such as OCR and highlighting need the extra software listed [below](#extra-software-for-optional-features).
4. Click **Preview changes**. It lists additions, updates, shortcut conflicts, and missing tools. Install those tools or uncheck the affected commands before continuing.
5. Click **Install selected** and approve the displayed changes. Setup saves a private backup of your command definitions before applying them.
6. If asked to restart CopyQ, exit it completely and start it again. This is needed when the undo listener changes.
7. Click **Verify**, then try the features you chose with disposable text or images.

**Unchecked commands stay as they are.** Unchecking a box does not uninstall or disable an existing command. Setup updates selected commands; a conflicting protection command is removed only when that change is disclosed in the confirmation.

### Updating one command

Click **Uncheck all**, check the command you want, then use **Preview changes → Install selected → Verify**.

**Read installed selection** is optional. It selects the suite commands you already have and loads their current shortcuts. Use it when updating several commands or preserving customized shortcuts. You can then use **Uncheck all** without losing those loaded shortcut values.

For a secret-protection update, select whichever option you use: **Clipboard Router** or **Secret Protection (Standalone)**. Both include the notification and save-to-history features.

### What setup checks and backs up

Verify checks installed command definitions, runs selected small helper checks, and reports missing dependencies. It does not test real pasting, your mouse or keyboard, OCR accuracy, or your Azure account. Try those features yourself afterward.

Setup installs commands. It does not install CopyQ or other software, change startup settings, or back up clipboard history. Private command backups and receipts are stored under `%LOCALAPPDATA%\CopyQCommandSuite\setup`. Use **Restore commands** with the receipt to undo an installation; it refuses to overwrite later command edits.

**Save profile** remembers your chosen commands and shortcuts for another installation. A profile contains choices, not API keys or clipboard contents. For a complete personal backup including your own and community commands, use CopyQ's **F6 → select all → Save Commands** and keep that file privately.

See the [setup and recovery guide](docs/SETUP.md) for profiles, troubleshooting, and recovery details.

## Install commands manually

Manual imports need CopyQ 16. Commands without extra dependencies do not need PowerShell, Node.js, or the setup assistant.

1. Pick an individual command from the links [below](#what-each-command-does), or choose a bundle:

   | Bundle | Contents |
   |---|---|
   | [General tools](commands/bundles/canonical.ini) | All 15 general-purpose commands, including optional translation, OCR, and rendering tools. |
   | [Moonlander tools](commands/bundles/moonlander.ini) | The three selected-text commands for the companion Moonlander setup. |
   | [Everything](commands/bundles/all.ini) | All 18 commands. |

2. On the command file's GitHub page, choose **Download raw file**. Save the `.ini` file itself, not the webpage.
3. Open CopyQ and press **F6**. Choose **Load Commands**, select the downloaded file, review the imported commands, and apply.
4. Put **Clipboard Router** or **Secret Protection (Standalone)** first in the command list, before other automatic commands. Choose one protection option, not both.
5. If you imported **Move to Trash (Undoable)**, also import **Undo Delete**, then exit CopyQ completely and restart it.
6. Install any extra software needed by your chosen commands and try them on disposable text or images.

For an update, save your current commands first, then **replace the old version of the selected command**. Loading a file can append a second copy: remove the old command and check the order before applying. Avoid importing a whole bundle over an existing setup unless you intend to replace its matching commands yourself. The setup assistant handles these updates for you.

Older installations call Clipboard Router **Canonical Dispatcher**. It is the same command; the download filename remains `canonical-dispatcher.ini` for compatibility.

## What each command does

Commands marked **automatic** run when you copy. Most others appear when you right-click a suitable item in CopyQ. The basic case-changing and web-search tools act on text selected in another application; the Moonlander tools are designed for that selected-text workflow too.

On Windows, **Meta** in CopyQ's shortcut settings means the **Windows key**.

### Clipboard Router or Secret Protection (Standalone)?

**Clipboard Router** is the automatic clipboard organizer. It protects saved history from detected secrets, puts different kinds of text into suitable tabs, and builds the `Frequent` list. “Router” means choosing a clipboard tab; it does not mean a network connection.

**Secret Protection (Standalone)** provides the same secret protection on its own. Choose it if you want to keep your current tab organization and do not want sorting or copy counting.

| What you want | Choose |
|---|---|
| Secret protection, automatic sorting, and a Frequent list | [Clipboard Router](commands/individual/canonical-dispatcher.ini) |
| Secret protection without changing how text is organized | [Secret Protection (Standalone)](commands/alternatives/secret-protection.ini) |

Use **one**. The router already includes protection, so an unchecked standalone option is expected. Enabling both stops normal processing with `SECRET_HANDLER_CONFLICT` until you remove the extra handler.

OCR, rendering, translation, and undo are separate commands you can add as needed.

#### Where Clipboard Router puts things

| Copied content | Saved in |
|---|---|
| Text of 5,000 characters or more | `BIG` |
| A standalone web, FTP, or file URL below that size limit | `&URLs` |
| Structured JSON, logs, stack traces, command transcripts, multiline operational commands, diffs, or configuration blocks | `Artifacts` |
| Recognized source code | `Code` |
| Ordinary text, Markdown prose, a single path, or a short command such as `git status` | Your normal clipboard tab |

These categories use recognizable patterns, so classification can occasionally be imperfect. For example, a JSON object needs at least two properties to qualify as an artifact. Markdown headings and quotations alone do not make a document an artifact. URLs are saved without visiting the address. Images retain their existing handling; this suite does not include a separate image-tab organizer.

If you have an older **Copy URL (web address) to other tab** command that creates `&web`, disable it when using the router: it duplicates URL storage. The community **Tab for URLs with Title and Icon** command can run afterward if you want it, but it visits copied addresses. See the [catalogue](docs/commands/COMMANDS.md) for its filter and ordering.

#### How Frequent works

Copy the same eligible text **six times**, and the router adds a second copy to `Frequent`. The original stays in its usual tab, whether that is normal history, URLs, Code, Artifacts, or BIG. Later copies move the Frequent entry to the top without adding duplicates.

Leading and trailing spaces are ignored when counting: `hello there` and ` hello there ` share a count. The Frequent entry uses trimmed text; the original item keeps its spacing. Secrets, redacted documents, images, and CopyQ's internal items are not counted. Counter settings store hashes and counts rather than copies of your text.

Deleting an entry from Frequent dismisses it: it needs six fresh copies to return. Undoing that deletion restores its previous count and adds any copies made since deletion.

### Recover deleted items

**[Move to Trash (Undoable)](commands/individual/move-to-trash-undoable.ini)** — automatic after a CopyQ restart. Deleted items go to `(trash)` with their text, images, formatting, and other stored data intact. There is no separate menu action for this command.

**[Undo Delete](commands/individual/undo-delete.ini)** — press **Ctrl+Z inside CopyQ**, or use its item menu, to restore the latest removal batch to its original tab and position. It restores a deleted Frequent entry's saved count too. Install both undo commands together.

Trash is cleaned at startup and before another deletion: entries at least **30 days old** are permanently removed. Your CopyQ tab item limit can remove them sooner. Undo covers automatic history-limit removals too, so the latest batch may be an automatic removal. To permanently delete something immediately, delete it again from `(trash)`.

### Make copied text easier to read

**[Remove Background and Text Colors](commands/individual/remove-background-and-text-colors.ini)** — automatic for copied HTML, and also available in the menu. Removes inline color styling so copied rich text can use the destination's colors. It keeps text and HTML structure; it is not a general HTML security filter.

**[Render Markdown](commands/individual/render-markdown.ini)** — automatically displays recognizable Markdown as formatted text: headings, lists, links, tables, quotations, and fenced code. You can also run it manually from the item menu. The original plain text remains available. Requires **marked**.

**[Highlight Code](commands/individual/highlight-code.ini)** — select a text item and run it from the item menu to add colored syntax highlighting, a monospace font, and wrapping for long lines. It recognizes common Python declarations and otherwise guesses the language, so ambiguous snippets may get the wrong colors. Requires **Python 3 and Pygments**.

### Get text from an image

**[Copy Text in Image](commands/individual/copy-text-in-image.ini)** — select a **PNG image** in CopyQ, then run the command from its right-click menu or press **Win+Ctrl+T**. It reads English and Hebrew text from that image and puts the result on the clipboard, ready to paste. The original image stays in history.

This uses **Tesseract OCR on your PC**. It does not need Azure, an account, or an internet connection, and it does not open a screenshot-selection crosshair. Small, blurry, or stylized text can be misread.

### Translate text

**[Translate to English](commands/individual/translate-to-english.ini)** — select a text item and run the command from its right-click menu. It sends the text to Azure Translator and puts the English result on your clipboard. It supports Hebrew and other Unicode text without opening a translation webpage.

Requires **PowerShell 7 and a configured, active Azure Translator account**. Azure may require billing; this repository does not provide a free translation service. Leave the command unchecked if you do not want it. Nothing else here depends on Azure.

### Move and find clipboard items

**[Copy Items as JSON](commands/individual/copy-items-as-json.ini)** — select one or more CopyQ items and run it from the item menu. Copies them as JSON, including their text, formatting, images, and other data. Useful for transferring selected items or inspecting what an item contains. The exported JSON can include private content.

**[Paste Items from JSON](commands/individual/paste-items-from-json.ini)** — rebuilds CopyQ items from JSON produced by **Copy Items as JSON**. It checks the format before importing. It is for this collection's item-export format, not arbitrary JSON from a website.

**[Search All Tabs](commands/individual/search-all-tabs.ini)** — asks for a search pattern and gathers matching items from all tabs into `Search`. Enter a plain word or a regular expression for a more precise match. It replaces the previous Search results each time; the source items remain in their original tabs.

**[Show Frequent](commands/individual/show-frequent.ini)** — opens the Frequent menu. Use the menu command or **Win+Shift+F**. Clipboard Router must be installed to populate the list automatically.

**[Copy and Search on Web](commands/individual/copy-and-search-on-web.ini)** — copies text selected in another application, lets you choose **DuckDuckGo or GitHub**, then opens a search for it. The chosen website receives the search text. No global shortcut is assigned by default.

### Change capitalization

**[To Title Case](commands/individual/to-title-case.ini)** — changes selected text in another application into an English-style title and pastes it back. For example, `a guide to clipboard tools` becomes `A Guide to Clipboard Tools`. Small connecting words stay lowercase where appropriate. It does not remember or restore the original capitalization.

**[Toggle Upper/Lower Case](commands/individual/toggle-upper-lower-case.ini)** — changes selected text to uppercase; if it is already entirely uppercase, changes it to lowercase. It pastes the result back into the application. These basic text tools have no global shortcuts assigned by default.

### Moonlander selected-text tools

These use the separate **[Moonlander Custom Config](https://github.com/YiftahCooper/Moonlander-Custom-Config)** project. Install that companion first: it supplies the scripts and helper that transform selected text, handle reselection, and restore the previous clipboard. The commands here connect to it.

| Command | Default shortcut | What it does |
|---|---|---|
| [Moonlander: Smart Title Case](commands/individual/moonlander-smart-title-case.ini) | **F13** | Applies smart title capitalization to selected text. |
| [Moonlander: Cycle Case](commands/individual/moonlander-cycle-case.ini) | **F19** | Cycles selected text between lower and upper case and reselects the result. |
| [Moonlander: Transplant Hebrew-English](commands/individual/moonlander-transplant-hebrew-english.ini) | **F22** | Repairs text typed with the wrong Hebrew/English keyboard layout. It maps the keys you pressed; it does not translate the meaning. |

The companion runtime is expected under `%LOCALAPPDATA%\MoonlanderTextTools`. Keep F13, F19, and F22 free of conflicting CopyQ shortcuts.

## How secret protection works

Both protection options check new copies before saving them to CopyQ history.

- **A detected secret on its own:** it is left out of history, with a `SECRET_IGNORED` notification.
- **Text containing a recognized secret:** the text is saved with that part replaced by `[REDACTED]`, with a `SECRET_REDACTED` notification.
- **Text with nothing detected:** it is saved normally, without a secret notification.

For example, a block containing `"api_key":"..."` can be saved with the key redacted while an ordinary `"fixtureId":"..."` value stays intact. Password-manager instructions to hide a copied value are also respected.

### Original paste versus redacted paste

**Pasting straight after copying uses the original Windows clipboard.** Secret protection changes what CopyQ saves, not the clipboard you just copied.

Selecting the redacted entry in CopyQ pastes the redacted version instead. Once you copy something else, the old secret cannot be recovered from that entry. CopyQ does not keep a hidden original. Redacted history keeps only sanitized text and any formatting freshly generated from it; original HTML and other formats are discarded so they cannot retain a secret behind the visible text.

### Save an ignored item or redacted original once

Sometimes an ordinary identifier looks like a secret. Eligible ignored items and redacted text show a **clickable Windows notification with the CopyQ icon**.

1. While the same original is still on the clipboard, click the notification's main body.
2. Confirm that you want to save the original **without redaction**.
3. It is added to history as a normal plain-text item. You can select and paste it later without confirming again.

With Clipboard Router, the original of a redacted block goes to the same destination as its redacted copy. Ignored standalone values and the standalone protection option save into main history. The redacted entry remains alongside the saved original.

This saves the item **once**. It does not permanently exempt that value: a later external copy is checked again, and the manual save does not contribute to Frequent. The already-saved item remains in history.

Closing or ignoring the notification does nothing. Copying something else invalidates the action; old Notification Centre entries and a CopyQ restart cannot recover it. Certain exclusions cannot be overridden, including password-manager concealment and recognized standalone credentials such as provider-prefixed API keys. A mixed block containing such a key can still offer a confirmed save of its original.

The clickable notification uses **SnoreToast**, already bundled with official Windows CopyQ. No extra notification software or icon download is required. It works independently of CopyQ's notification-style preference. A newer actionable notification invalidates the previous save action. If the helper is unavailable, filtering still works but reports `SAVE_UNAVAILABLE` without a save action.

### Detection limits and false positives

Secret detection uses patterns, not knowledge of which values really grant access. It can miss unfamiliar secrets or mistake an identifier for one.

Bare UUIDs and hexadecimal strings of 32–128 characters are treated as possible keys and excluded. A password-shaped standalone string of **10–150 characters**, with no spaces and a mix of letter cases or digits, can also be excluded. Ordinary words such as `Collegiate`, paths, and version numbers have exceptions. The length limit applies to password guessing; recognized token formats and labelled secrets can be longer.

Inside larger documents, UUIDs and hashes are kept unless they appear in a recognized credential field or format. Normal URLs are also kept, including random-looking IDs. Recognizable URL credentials—such as a password in the address, an `api_key` or `access_token` parameter, or a private Google Calendar feed token—are redacted. A redacted link may no longer work.

Protection applies to **new copies**. It does not clean old history, trash, exports, or backups, and it does not control Windows clipboard history or other clipboard managers. A confirmed unredacted save has the same lifetime as any other stored item and can enter trash or backups. To remove a sensitive stored item immediately, delete it from its tab and from `(trash)` too.

See the [command catalogue](docs/commands/COMMANDS.md) for exact rules, failure messages, and limitations.

## Extra software for optional features

Only install the dependencies for the commands you want.

| Feature | What you need |
|---|---|
| Core sorting, protection, undo, search, and text tools | CopyQ 16. Official Windows CopyQ includes the notification helper. |
| Setup assistant | PowerShell 7.2 or newer. No Node.js or Pester needed. |
| Markdown rendering | [Node.js](https://nodejs.org/) and the [marked](https://github.com/markedjs/marked) command-line tool. |
| Code highlighting | [Python 3](https://www.python.org/downloads/windows/) with [Pygments](https://pygments.org/). |
| Image text recognition | [Tesseract OCR](https://tesseract-ocr.github.io/tessdoc/Installation.html), including English (`eng`) and Hebrew (`heb`) language data. |
| Translation | PowerShell 7 and Azure Translator configuration. |
| Moonlander commands | [Moonlander Custom Config](https://github.com/YiftahCooper/Moonlander-Custom-Config). |

If Node.js or Python is already installed, these are the usual commands to add the corresponding tool:

```powershell
npm install -g marked
python -m pip install Pygments
```

Run the command for the feature you want in your normal terminal. Pygments must be installed in the Python interpreter used by `py -3` or `python.exe`. OCR looks for Tesseract in its standard Program Files location or on `PATH`.

From the repository folder, this optional report checks the installed tools without changing anything:

```powershell
pwsh -NoProfile -File .\scripts\Test-Dependencies.ps1
```

### Optional Azure setup

Create an Azure Translator resource and note its region. In the setup assistant, use **Configure Azure**, or run this from the repository folder, replacing the example region with yours:

```powershell
pwsh -NoProfile -File .\scripts\Install-CopyQTranslation.ps1 -Region germanywestcentral
```

The helper asks for your key securely and stores it encrypted for your Windows account under `%LOCALAPPDATA%\CopyQCommandSuite\translation`. Keep keys out of this repository. On another PC or Windows account, configure the key again. The service must be active; a stored key does not mean Azure will accept it.

## Credits and license

This collection builds on **CopyQ**, created and maintained by **Lukáš Holecek (`hluk`) and its contributors**, and ideas from the official [CopyQ commands repository](https://github.com/hluk/copyq-commands).

Distributed commands are original work or independent rewrites. In particular, the undo pair was inspired by `hluk`'s [Undoable Move to Trash](https://github.com/hluk/copyq-commands/blob/master/commands/undoable-move-to-trash.ini). Other community commands used alongside this setup are linked to their original sources rather than copied here.

The [credits page](docs/CREDITS.md) lists original command links, known contributors, notification tooling, and the Moonlander companion. This repository is licensed under **GPL-3.0-only**; see [LICENSE](LICENSE).

## For contributors

Each command has its own source file. The ready-to-import `.ini` files include the code they need, so installed core commands do not depend on this checkout. External tools and the Moonlander companion are still needed for their respective features.

Normal users can use the committed command files without building anything. To build or test changes, see the [architecture and contribution guide](docs/ARCHITECTURE.md). Builds require Windows, CopyQ **16.0.0**, PowerShell 7, Node.js with npm, and the documented test dependencies, including Pester **3.4.0** for PowerShell tests. Use the [documented scratch layout](docs/ARCHITECTURE.md#disposable-verification-storage) for disposable verification files.

Further reading: [command catalogue](docs/commands/COMMANDS.md) · [setup and recovery](docs/SETUP.md) · [credits](docs/CREDITS.md) · [architecture](docs/ARCHITECTURE.md) · [changelog](CHANGELOG.md).
