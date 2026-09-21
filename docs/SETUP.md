# CopyQ Setup: choose, install and verify

CopyQ Setup is an inspectable PowerShell 7 script with a Windows Forms interface.
It installs command definitions using CopyQ's native API. It is not an MSI,
application upgrader, background service, package manager or clipboard backup.
No Node.js, npm or Pester is needed to run the setup assistant.

## Which protection option should I select?

- **Clipboard Router** is the combined automatic command: it protects history,
  sorts copied text into appropriate tabs, and maintains the Frequent index. Its
  name describes tab sorting, not networking. This is the option for the suite's
  integrated clipboard workflow.
- **Secret Protection (Standalone)** provides the same secret filtering and
  redaction without sorting or frequency counting. Choose it only if you want
  protection without the router's other features. It is an alternative, not an
  extra component needed to complete a router installation.
- **Select one, not both.** With Clipboard Router installed, an unchecked
  standalone-protection row is expected. Both leave immediate ordinary paste
  unchanged; filtering applies to what CopyQ retains in history.

OCR, translation, rendering and Moonlander commands are separate from either
option. See the [feature comparison](../README.md#clipboard-router-or-secret-protection-standalone).

## Before opening it

- Windows and **CopyQ 16.0.0**, running as your normal Windows user.
- [PowerShell 7.2 or newer](https://github.com/PowerShell/PowerShell), available as `pwsh.exe`.
- Extract the complete downloaded ZIP to a folder; do not run from inside it.
  A complete repository checkout also works: open its `CopyQ-Setup.cmd` directly;
  downloading or building a ZIP is not required.
- Do not run as administrator. The assistant refuses an elevated session.
- Windows may mark a downloaded script as untrusted. Review its source first. If
  Windows blocks the ZIP, use its Properties > Unblock before extracting, where
  available. The launcher does not change execution policy or disable security.
  Organisation-managed execution restrictions must be respected.

The ZIP is unsigned. A published SHA-256 helps check that a file matches the
release, but is not a publisher signature. Download only from the intended
repository/release. There is no download-and-execute pipeline or telemetry.

## Normal setup

1. Double-click **CopyQ-Setup.cmd**. The console remains available for secure
   Azure input if you explicitly choose that operation.
2. Choose Essentials, All general tools, Protection only, or individual checkboxes.
   Undo automatically includes its partner. Show Frequent requires the router.
   Router and standalone protection are mutually exclusive.
   For a single-command update, click **Uncheck all**, then check only that
   command. This clears selection, not installed commands or shortcut edits.
3. Optionally load a saved JSON profile. Profiles from another package can be
   loaded, but preview warns that this package's commands will be used.
4. Edit shortcuts only if needed. Blank keeps the packaged default, `-` clears
   it, and semicolons separate multiple shortcuts. `Meta` means the Windows key.
5. Click **Preview changes**. Same-identity selected commands are replaced,
   including local edits; the preview names the affected identities. Unselected
   existing commands remain installed. This is not an uninstall selector.
   `missingDependencies` lists any prerequisites that still need attention.
   Installation is blocked until these are prepared or their commands are
   deselected. Dependencies are checked again immediately before mutation.
6. Click **Install selected**, read the confirmation and approve it. The assistant
   backs up command definitions only, applies the selected updates, and reads
   the installed definitions back. A conflicting protection handler is removed
   only as disclosed in the confirmation. Protection is placed first.
7. If script commands such as the undo listener changed, exit CopyQ completely
   and start it again. Click **Verify** afterward. This restart is explicit: the
   installer does not interrupt an active CopyQ editor or unsaved work.

Each operation normally takes seconds. Errors stop the operation and appear in
the status area; do not interpret a missing dependency as a working feature.
Each process input/response wait is limited to 20 seconds. Start CopyQ in the same Windows
account before retrying a connection failure.

### Update other commands while leaving translation alone

For a router-only update, **Uncheck all** → **Clipboard Router** → **Preview
changes** → **Install selected** is sufficient. **Read installed selection** is
optional; use it first if you want to retain installed shortcut customizations,
then use **Uncheck all** without losing the loaded shortcut values.

Click **Read installed selection**, then uncheck **Translate to English** before
previewing. Alternatively, load a profile that excludes `canonical.translate-en`.
Leave **Configure Azure** alone. An unchecked translation command is preserved
exactly as installed; it is not updated, disabled or removed. Its credentials and
region are not changed, and missing Azure prerequisites do not block the other
selected commands. This does not repair an unavailable translation service.

Keep existing working Moonlander commands unchecked too if you only want to
update the general tools. Their command definitions and shortcuts are preserved.

## What verification proves

- `definitionsVerified`: selected command bodies, fields, shortcuts, ordering
  and preservation of unselected commands match the planned native export.
- `helperChecks`: selected embedded classifiers/validators execute on harmless
  fixed inputs. These checks do not copy anything to the Windows clipboard.
  If installed definitions differ, helper execution is skipped and reported as
  not verified. The command snapshot is checked again before helper execution.
- `missingDependencies`: required tools or Azure helper/credential files that
  were not found. Python/Pygments import and Tesseract language availability are
  checked by the existing dependency report.
- It does **not** automatically send text to Azure, exercise your physical
  copy/paste shortcuts, or prove every renderer works in every application.
  `externalServicesTested` and `clipboardPasteTested` explicitly remain false.

After configuring a feature, try one disposable item: translate `hello`, render
a Markdown heading, highlight a short program, or OCR a nonprivate test image.
Use the existing [command catalogue](commands/COMMANDS.md) for activation details.

## Dependencies and Azure

The assistant does not install third-party software or upgrade CopyQ. This first
version uses official guidance, not hardcoded download URLs or silent WinGet
transactions. You can use your normal package manager, including Microsoft's
open-source [WinGet](https://github.com/microsoft/winget-cli), independently.

| Feature | Official source / requirement |
|---|---|
| CopyQ | [CopyQ releases](https://github.com/hluk/CopyQ/releases); this package targets 16.0.0 |
| Markdown | [marked](https://github.com/markedjs/marked), Node.js and its CLI (`marked.cmd`) |
| Highlighting | [Python](https://www.python.org/downloads/windows/) and [Pygments](https://pygments.org/) in the interpreter used by `py -3` or `python.exe` |
| OCR | [Tesseract installation guidance](https://tesseract-ocr.github.io/tessdoc/Installation.html), including `eng` and `heb` data |
| Translation | PowerShell 7 and your Azure Translator resource |
| Moonlander | [Moonlander Custom Config](https://github.com/YiftahCooper/Moonlander-Custom-Config) |

**Configure Azure** is a separate, confirmed operation. If an encrypted key
already exists, it reuses that key without replacing its bytes or requesting
it again. The existing region configuration is reused unless a region override
is supplied; if missing, the console asks for the resource region. If no key
exists, secure key entry is requested. The operation prepares helper files and
configuration independently of command installation. A command rollback does not revert credentials. On another
Windows account or machine, configure the key again; do not assume a copied
DPAPI file will be decryptable. Keys never enter the profile.

The script also exposes `-ReuseExistingCredential` for an explicit migration
without key replacement. File/dependency checks do not prove the key can be
decrypted by the current account or that Azure accepts it; test translation
from your normal Windows account using disposable text.

## Your reusable profile and personal command backup

**Save profile** saves the selected suite identities, shortcut overrides, package
digest and optional nonsecret Azure region. **Read installed selection** loads
the suite commands and shortcuts actually present in CopyQ; then save the profile.
The three original Moonlander wrappers without suite IDs are recognized by their
exact names, expected F13/F19/F22 shortcuts and known wrapper code. Discovery is
read-only: their script bodies and IDs are not rewritten. Selecting one and
confirming installation explicitly updates that existing command to the packaged
version rather than adding a duplicate. Leave them unchecked to preserve them.
Modified or ambiguous legacy wrappers are not silently adopted; duplicate
Moonlander identities stop discovery/preview with `DUPLICATE_IDENTITY`.
Profiles do not contain command bodies, API keys, clipboard items or arbitrary
application preferences. They cannot reproduce unrelated community commands or
custom script edits. Identities not present in the current package are
refused when loading in the wizard (or during CLI preview), never silently discarded.

For your complete personal command selection, use CopyQ F6 > select all > Save
Commands, and store that native INI privately. A command may contain a personal
path or embedded credential even though this export contains no clipboard history.
Keep API keys separately in a password manager. Reinstall external tools normally.

## Failure, interruption and command-only rollback

Each changed installation creates a fresh private directory beneath
`%LOCALAPPDATA%\CopyQCommandSuite\setup`, containing `before.ini`, `candidate.ini`
and `receipt.json`. Native exports may contain personal command code; keep these
private. Receipts contain IDs, hashes and status, not clipboard content or keys.

- `prepared`: backup and candidate are durable; interruption may have happened
  before or after applying commands. Use Verify, or Restore commands with that receipt.
- `installed`: native readback matched; dependencies or manual feature checks
  may still need attention. Repeating the same install produces `unchanged`.
- `failed`: the receipt records whether restoration succeeded, was unnecessary,
  could not be verified, or was refused because commands changed independently.
- `restored`: the pre-installation native command set was read back successfully.

**Restore commands** restores the pre-installation set only if the current set
still matches the recorded candidate (or already matches the backup). It refuses
to overwrite later edits or a changed backup. On refusal, use F6 to inspect and
save the current commands before choosing a manual restoration. There is no force
button. Restart CopyQ after restoring script commands.

The installation never exports clipboard history, changes CopyQ preferences,
installs autostart, or removes tabs. Enabling the existing undo listener can prune
expired trash during normal script loading; this is its documented behaviour,
not a setup backup/migration operation.

## Build a distributable ZIP

Maintainers can run `scripts/Build-SetupPackage.ps1` in PowerShell 7.2 or newer. It packages
exactly `PUBLIC-FILES.txt`, including source, licence, docs and generated INIs,
with stable ZIP timestamps and a SHA-256 sidecar. Output goes into ignored `dist/`.
It does not commit, push or create a GitHub release. The package tests extract a
fresh ZIP and verify inventory and command discovery without Node at runtime.
