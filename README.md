# CopyQ Command Suite

A curated Windows command collection for [CopyQ](https://github.com/hluk/CopyQ) 16. It combines privacy-aware clipboard routing, automatic Markdown rendering, OCR, code highlighting, translation, text utilities, and optional Moonlander selected-text commands.

The repository distributes sixteen original or independently rewritten commands. Community commands used in the author's personal setup are credited and linked, but their source is not republished here.

## Quick start

1. Install CopyQ 16.
2. Download an individual command from the [command catalogue](docs/commands/COMMANDS.md), or choose a bundle:
   - [`commands/bundles/canonical.ini`](commands/bundles/canonical.ini) — thirteen general-purpose commands.
   - [`commands/bundles/moonlander.ini`](commands/bundles/moonlander.ini) — three Moonlander integrations.
   - [`commands/bundles/all.ini`](commands/bundles/all.ini) — all sixteen commands.
3. Open CopyQ, press `F6`, choose **Load Commands**, select the INI, review the command list, and confirm.
4. Run the optional dependency report when using rendering, highlighting, OCR, translation, or Moonlander features:

   ```powershell
   pwsh -NoProfile -File .\scripts\Test-Dependencies.ps1
   ```

Importing a command file does not install external programs and does not change CopyQ clipboard history or tabs.

## What is included

| Area | Commands |
|---|---|
| Clipboard automation | Canonical Dispatcher; Remove Background and Text Colors |
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

## Azure translation setup

Translation is optional and is the only feature that sends selected content to a network service. Create an Azure Translator resource, note its region, then run:

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

- Canonical Dispatcher keeps high-confidence secrets out of CopyQ history and shows the content-free reason `SECRET_IGNORED`.
- Frequency state stores bounded dual hashes and counts, not copied text.
- Markdown, highlighting, and OCR run locally.
- Azure receives only text explicitly sent through Translate to English.
- Missing tools leave the current clipboard item intact and report bounded codes such as `MARKDOWN_FAILED`, `PYGMENTS_FAILED`, `OCR_FAILED`, or `TRANSLATE_NOT_CONFIGURED`.
- Generated exports and public files are scanned for local home paths, credentials, backups, and private configuration.

## Build and test

The committed INI files are generated from the canonical JavaScript command model through one isolated CopyQ 16 session:

```powershell
npm test
npm run build
Invoke-Pester .\tests\*.Tests.ps1 -Output Detailed
```

The build creates sixteen individual files and the three bundles, imports every result back into the isolated session, and never connects to or modifies the normal CopyQ session.

## Community commands

Several excellent commands used alongside this collection come from [`hluk/copyq-commands`](https://github.com/hluk/copyq-commands). They are not distributed here. See [credits and recommended community commands](docs/CREDITS.md) for direct source links and contributor attribution.

## License

This project is licensed under `GPL-3.0-only`; see [LICENSE](LICENSE). CopyQ is a separate GPL-licensed project. Referenced community commands remain governed by their respective upstream repositories and are not included here.
