# Source layout and independent commands

The suite separates **feature implementations**, **CopyQ command bodies**, and
**distributable INI files**. A command can be a standalone import without carrying
every feature in the suite. No extra runtime module installation is required.

## Where to make a change

| Concern | Source |
|---|---|
| Secret detection, redaction and safety decisions | `src/core/secrets.js` |
| Shared protection notifications and filtering | `src/runtime/secret-protection-fragment.js` |
| Confirmed one-time save notification action | `src/runtime/secret-save-once.js` |
| Native Windows notification transport | `src/runtime/secret-native-notification.js` |
| URL recognition and credential URL rules | `src/core/urls.js` |
| Technical artifact detection | `src/core/artifacts.js` |
| Source-code detection | `src/core/code.js` |
| Destination precedence | `src/core/routing.js` |
| Frequency identity, migration, counts and dismissal | `src/core/frequency.js` |
| Trash expiry | `src/core/trash.js` |
| Markdown detection | `src/core/markdown.js` |
| Title/upper/lower casing | `src/core/casing.js` |
| HTML colour cleanup | `src/core/html.js` |
| JSON and regex validation | `src/core/json.js`, `src/core/regex.js` |
| Individual CopyQ command bodies | One file per command under `src/runtime/` |
| Command identities, names, shortcuts and activation flags | `src/commands.js` |
| Published source/output map and compatibility metadata | `manifest/public-commands.json` |

Core modules are ordinary JavaScript modules: they can be imported directly in
Node and have no dependency on a running CopyQ server. The `core-node.js`,
`runtime.js`, `secrets.js`, `routing.js`, and `frequency.js` entry points retain
compatibility for existing repository consumers; they are not duplicate
implementations. The old `shared-core.js` implementation monolith is gone.

## Building an independent import

`src/bundle-core.js` declares a small, explicit dependency graph. At build time it
embeds only the requested core modules and their dependencies. For example:

- Title case includes casing, not secret detection or frequency tracking.
- Markdown includes Markdown detection, not the router.
- Undo includes frequency-state recovery, not secret detection or text routing.
- Protection-only includes secrets and their common/URL helpers, not routing or
  frequency tracking.
- Clipboard Router includes safety, routing and frequency modules.

The one-time save action belongs to protection, not routing. Both variants embed
`secret-save-once.js` and `secret-native-notification.js` with only their secret
core dependencies. An asynchronous `action()` receives generated code containing
a fingerprint, random notice IDs and an optional router destination, never
original text or event MIME data.
The builder forbids CopyQ's percent-1 substitution placeholder in that worker so
`action()` cannot implicitly inject clipboard text. Routing is not blocked while
the toast waits. SnoreToast has its own bounded activation wait; no resident
service or polling timer is added.

The worker resolves `snoretoast.exe` beside `info('exe')`, uses the existing
`copyq` app identity and a short toast, and accepts only body-click exit code 0.
It reads CopyQ's embedded `:/images/logo.png` into a unique temporary PNG and
passes that file with SnoreToast's `-p` option. Only public icon bytes are written,
never clipboard content. The file is closed before delivery and removed after
the helper returns, including dismissal, expiry or failure; Qt also provides
automatic removal when the temporary-file object is destroyed. If extracting
the icon fails, the native notification still works with the helper's default
image. The standalone and integrated commands share this implementation.
Codes 1/2/3 do nothing. Missing helpers and errors leave protection intact and
report `SAVE_UNAVAILABLE`. Only generic notification text and a random ID reach
the helper. `secret_notification_current` holds only the latest random ID:
new workers attempt to close a predecessor, callbacks check ownership, and
cleanup targets only their own toast. A queued supersession can leave an older
toast visible until expiry, without authorizing its callback. The single ID
remains until the next dispatch replaces it;
there is no non-atomic check-then-clear that could erase a newer request. No
secret, fingerprint, or allowlist is persisted there.

After a click, the save action reads the current clipboard, revalidates its
fingerprint, metadata and notification ownership before and after confirmation,
then inserts plain text without rerunning classification or frequency counting.
The router supplies the same destination used for the redacted item, from one
shared destination map in its runtime builder. Standalone protection and ignored
values supply no routed destination and use configured main history instead.
A removed routed tab fails the save rather than silently changing destination.
Mixed originals are added separately; sanitized history is
not modified. There is no extra command object or runtime source file to install.
Old Notification Centre entries and restarts are not durable callbacks.
See the [user contract](../README.md#save-an-ignored-item-or-redacted-original-once).

Each runtime command declares its required modules. `src/runtime/command-source.js`
combines them with its body. The existing PowerShell builder exports the result
through an isolated CopyQ 16 session. The final INI contains all required code:
CopyQ does not need Node, these source files, `require()` from disk, or the checkout
to run a core command. Optional external tools for OCR, translation and rendering
are unchanged.

The small generated module shim resolves embedded modules only; it cannot load
files or packages. It is generated deterministically, without a new build-tool
dependency. Edit source files, not generated INIs.

## Why keep a combined Clipboard Router?

For users, this is one automatic command combining **history protection, tab
sorting and Frequent indexing**. "Router" describes choosing a destination tab,
not networking. The protection-only alternative contains the first feature on
its own, with the same detection rules; it is not an add-on to the router.

The combined setup still needs one agreed order: safety, frequency eligibility,
index updates, and primary destination. Separate source modules provide clarity
without making users manually coordinate several competing automatic handlers.

The display name **Clipboard Router** replaces **Canonical Dispatcher**. Its
internal identity remains `canonical.dispatcher`, and its individual filename
remains `commands/individual/canonical-dispatcher.ini`, so existing replacement
instructions and integrations remain compatible. `canonical` is the historical
namespace, not a CopyQ requirement.

## Choose one safety handler

- **Integrated setup:** install Clipboard Router. This preserves the existing
  routing, redaction and Frequent behaviour. The normal bundles include it.
- **Protection-only setup:** install
  `commands/alternatives/secret-protection.ini`. It excludes/redacts secrets but
  does not choose tabs, count copies or create a Frequent index. Existing external
  routing commands can run afterward on sanitized data.

Do not enable both. Both handlers check for an enabled counterpart or duplicate
handler identity and fail closed with `SECRET_HANDLER_CONFLICT` before processing
the item. Remove the extra handler rather than ignoring that notification.
Whichever handler is chosen must be the first automatic command: a later guard
cannot undo earlier commands' writes or network requests.

The standalone alternative is **not** bundled into `all.ini`. There are still 18
commands in the integrated suite, with one additional optional alternative. The
Moonlander bundle and its F13/F19/F22 ownership remain unchanged.

## Verification and recovery

Run `npm test`, `npm run build`, and the PowerShell tests. Tests execute feature
modules directly and in generated CopyQ code, exercise actual isolated tab
storage, and check that unrelated helpers are absent from narrow imports.

For command backups, use CopyQ's native **Save Commands** / **Load Commands**
format. A naive `JSON.stringify(commands())` round-trip loses regular-expression
fields and is not an equivalent backup. Never edit live configuration files while
CopyQ is running.

### Disposable verification storage

Use `.backup-scratch/` for generated test/build state. Set `TEMP` and `TMP` to
its absolute path only in the verification shell and its child processes, never
in system settings. For installer integration tests, copy the files listed in
`PUBLIC-FILES.txt`, preserving relative paths, into a fresh child directory such
as `.backup-scratch/test-package/`, then run its PowerShell tests. Keep `TEMP`
and `TMP` at the parent scratch directory: installer state must remain outside
the package under test. Node tests run from the real Git checkout.

The package copy and runtime data are regenerable from the public allowlist and
the documented build/test commands. Retain source, deliberate fixtures and the
generated distribution in their normal repository locations. Scratch is ignored
by Git, but its exclusion from backups must be checked separately; this project
does not configure backup software.
