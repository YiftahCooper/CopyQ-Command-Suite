# Command Catalogue

Each file below is a separate import through CopyQ's command dialog (`F6` → **Load Commands**). On GitHub, open its download link and use **Download raw file** to save the INI, not the HTML page. The two undo commands are a pair: install both. Core commands require CopyQ 16. Optional dependencies are called out explicitly.

## Clipboard automation

### Clipboard Router (formerly Canonical Dispatcher)

- Download: [commands/individual/canonical-dispatcher.ini](../../commands/individual/canonical-dispatcher.ini)
- Activation: first automatic command, with an empty Format filter, on clipboard changes.
- Behaviour: checks secrets and concealment metadata before image/owner/hidden passthrough; routes text of at least 5,000 characters to `BIG`, standalone HTTP(S)/FTP(S)/file URLs to `&URLs`, strong technical blocks to `Artifacts`, and detected source code to `Code`. Every eligible text copy is counted independently of that primary destination. URL storage works without fetching the address or requiring HTML.
- Strength: replaces several order-sensitive automatic commands with one deterministic precedence chain and never logs clipboard content. A sixth copy creates a trimmed, text-only secondary entry in `Frequent` while the original stays in its normal tab.
- Limitation: secret detection is deliberately conservative for standalone values and can suppress opaque identifiers. Embedded detection uses recognizable token formats and explicit credential fields, not arbitrary mixed-case words or document hashes; unfamiliar or encoded credentials can be missed. Existing stored secrets are not retroactively removed. Earlier automatic commands can bypass the guard, so the dispatcher must be first. Disable the legacy `&web` copy command; optional title/icon enrichment must run later and match only standalone HTTP(S) URLs.
- Privacy: whole secrets/concealment metadata are excluded (`SECRET_IGNORED`). Recognized credentials within documents are replaced with `[REDACTED]` in the stored item (`SECRET_REDACTED`). All original alternate formats are dropped for that item, and it is not frequency-counted. Ordinary paste still uses the current Windows clipboard original; selecting from history pastes only the sanitized version. Undo cannot recover removed credentials. Ordinary URL IDs stay intact; explicit credential parameters, embedded URL passwords and private Google Calendar feed tokens are redacted. This does not control other clipboard managers or Windows clipboard history. Frequency state contains at most 4,096 hashes, counts, and recency values rather than copied text.
- Dependencies: CopyQ 16.

`Artifacts` requires a strong signal: a JSON object/array with at least two entries, a structured multiline PowerShell or shell command, a command transcript, multiple timestamped or level-prefixed log lines, a stack trace/backtrace, a unified diff, or a configuration block with at least three entries. A standalone path, `git status`, a one-line PowerShell command, a short identifier, an ordinary URL, normal prose, and normal Markdown prose stay outside `Artifacts`.

### Secret Protection (Standalone) — optional alternative

- Download: [commands/alternatives/secret-protection.ini](../../commands/alternatives/secret-protection.ini) (not in the standard bundles).
- Activation: first automatic command, with an empty Format filter. Use **instead of**, not alongside, Clipboard Router or Canonical Dispatcher.
- Behaviour: the same standalone-secret exclusion and permanent history redaction described above. Immediate system-clipboard paste remains unchanged. It does not choose a destination tab, access frequency settings or create Frequent entries; later user-installed handlers retain responsibility for routing.
- Strength: install secret protection without adopting the suite's tab organisation or frequency feature. Its export embeds only secret-related helpers.
- Limitation: the same detection and alternate-format limitations apply. An enabled duplicate handler or coexistence with the router fails closed with `SECRET_HANDLER_CONFLICT`; remove the extra command to resume storing copies.
- Privacy: content-free `SECRET_IGNORED`, `SECRET_REDACTED` and `SECRET_REDACTION_FAILED` notifications. No copied content is logged.
- Dependencies: CopyQ 16.

### Move to Trash (Undoable)

- Download: [commands/individual/move-to-trash-undoable.ini](../../commands/individual/move-to-trash-undoable.ini)
- Activation: persistent CopyQ script loaded at startup; it has no menu action or shortcut. Install it with Undo Delete and restart CopyQ after importing.
- Behaviour: chains any existing removal handler and copies each removable item, with all MIME formats, into `(trash)` before CopyQ removes it. One removal event is one undo batch. Items at least 30 days old are pruned at startup and before a new deletion.
- Strength: covers deletion batches and CopyQ-generated removals such as history-limit eviction without a timer or background process.
- Limitation: because all real removals are observed, `Ctrl+Z` restores the latest removal batch, which may not have originated from the Delete key. Your configured tab item limit also bounds `(trash)` (110 in the author's setup); importing these commands does not change that preference. Cleanup is lazy, so expired entries can remain until startup or the next deletion.
- Privacy: deleted content remains stored locally in `(trash)`. Delete it again from `(trash)` for immediate permanent removal.
- Dependencies: CopyQ 16.

### Undo Delete

- Download: [commands/individual/undo-delete.ini](../../commands/individual/undo-delete.ini)
- Activation: `Ctrl+Z` while the CopyQ item window is focused, or the item context menu.
- Behaviour: restores the newest trash batch to its source tab and approximate row, preserving MIME formats. Missing source tabs fall back to `&Clipboard`; `NOTHING_TO_UNDO` is shown when no batch exists.
- Strength: deleting from `Frequent` resets qualification, while undo restores its saved count plus copies made after deletion and merges any requalified entry instead of duplicating it.
- Limitation: requires Move to Trash (Undoable) to have recorded the deletion; it is a local CopyQ shortcut, not a system-wide undo. Deleting the trash copy or allowing it to expire permanently discards its saved Frequent count.
- Privacy: restoration and notifications do not log item content, hashes, or restored text.
- Dependencies: CopyQ 16.

### Remove Background and Text Colors

- Download: [commands/individual/remove-background-and-text-colors.ini](../../commands/individual/remove-background-and-text-colors.ini)
- Activation: automatic for HTML clipboard data; also available in the menu.
- Behaviour: neutralizes inline `color:` declarations while preserving the underlying HTML and plain text.
- Strength: makes copied rich text follow the destination's colours.
- Limitation: intentionally narrow; it is not a complete HTML or CSS sanitizer.
- Privacy: local only.
- Dependencies: CopyQ 16.

## Rendering and extraction

### Render Markdown

- Download: [commands/individual/render-markdown.ini](../../commands/individual/render-markdown.ini)
- Activation: automatic when strong Markdown structure is detected; also available in the menu.
- Behaviour: runs `marked` and adds rendered HTML while preserving the original plain text.
- Strength: headings, fenced code, links, quotations, tables, and multi-item lists render automatically without converting ordinary prose.
- Limitation: requires `marked`; failure reports `MARKDOWN_FAILED` and leaves the item unchanged.
- Privacy: local only.
- Dependencies: CopyQ 16 and marked.

### Highlight Code

- Download: [commands/individual/highlight-code.ini](../../commands/individual/highlight-code.ini)
- Activation: context menu on a text item.
- Behaviour: asks Pygments to detect the language and adds continuous, wrapped, CopyQ-compatible highlighted HTML.
- Strength: uses a readable monospace layout without the separated beige line backgrounds produced by many CopyQ highlighting snippets.
- Limitation: automatic language guessing is imperfect; failure reports `PYGMENTS_FAILED`.
- Privacy: local only.
- Dependencies: CopyQ 16, Python 3, and Pygments.

### Copy Text in Image

- Download: [commands/individual/copy-text-in-image.ini](../../commands/individual/copy-text-in-image.ini)
- Activation: select a PNG item and use the context menu, or press Meta+Ctrl+T.
- Behaviour: passes the selected PNG directly to Tesseract and copies detected English/Hebrew text.
- Strength: operates on the selected CopyQ image instead of opening a screenshot crosshair or language prompt.
- Limitation: the default language model is `eng+heb`; low-quality images can return no text. Failures use `OCR_NO_PNG`, `OCR_NO_TEXT`, or `OCR_FAILED`.
- Privacy: local only.
- Dependencies: CopyQ 16, Tesseract OCR, Tesseract eng, and Tesseract heb.

## Translation

### Translate to English

- Download: [commands/individual/translate-to-english.ini](../../commands/individual/translate-to-english.ini)
- Activation: context menu on a selected text item.
- Behaviour: sends the selected text to Azure Translator, decodes the UTF-8 result, and copies the English translation.
- Strength: works with Hebrew and other Unicode input without opening a browser.
- Limitation: requires local configuration and a working Azure subscription. Static failures include `TRANSLATE_NOT_CONFIGURED`, `TRANSLATE_AUTH_FAILED`, `TRANSLATE_REGION_FAILED`, `TRANSLATE_RATE_LIMITED`, `TRANSLATE_EMPTY`, and `TRANSLATE_FAILED`.
- Privacy: the selected source text is sent to Azure; neither source nor result is logged locally by the helper.
- Dependencies: CopyQ 16, PowerShell 7, and Azure Translator.

## Data and search

### Copy Items as JSON

- Download: [commands/individual/copy-items-as-json.ini](../../commands/individual/copy-items-as-json.ini)
- Activation: context menu on one or more selected items.
- Behaviour: serializes every selected MIME field, using Base64 only for binary data.
- Strength: preserves complete CopyQ item structure for inspection or transfer.
- Limitation: the resulting JSON can contain sensitive clipboard data; handle it accordingly.
- Privacy: local only, but intentionally exposes the selected item content to the clipboard.
- Dependencies: CopyQ 16.

### Paste Items from JSON

- Download: [commands/individual/paste-items-from-json.ini](../../commands/individual/paste-items-from-json.ini)
- Activation: context menu when the clipboard contains a supported JSON object.
- Behaviour: validates the document shape and Base64 fields before creating CopyQ items.
- Strength: refuses malformed or unexpected structures using `JSON_PARSE_INVALID` and `JSON_SHAPE_INVALID`.
- Limitation: only accepts the suite's `copyq_items` format.
- Privacy: local only.
- Dependencies: CopyQ 16.

### Search All Tabs

- Download: [commands/individual/search-all-tabs.ini](../../commands/individual/search-all-tabs.ini)
- Activation: context menu.
- Behaviour: validates a regular expression, searches all tabs, and copies matches into a fresh `Search` tab.
- Strength: searches across the whole CopyQ collection while rejecting invalid patterns with `REGEX_INVALID`.
- Limitation: replaces the previous `Search` tab and can be slow on exceptionally large histories.
- Privacy: local only.
- Dependencies: CopyQ 16.

### Copy and Search on Web

- Download: [commands/individual/copy-and-search-on-web.ini](../../commands/individual/copy-and-search-on-web.ini)
- Activation: context menu against selected application text.
- Behaviour: copies the selection, asks whether to use DuckDuckGo or GitHub, and opens the encoded query.
- Strength: offers explicit search-engine choice without occupying a global shortcut.
- Limitation: sends the query to the selected website.
- Privacy: network request to the selected search provider.
- Dependencies: CopyQ 16.

## Text and frequency tools

### To Title Case

- Download: [commands/individual/to-title-case.ini](../../commands/individual/to-title-case.ini)
- Activation: context menu against selected application text.
- Behaviour: applies predictable English title rules, including small words and the `ID`/`TV` forms, then pastes the result.
- Strength: deterministic and faster than manually correcting capitalization.
- Limitation: English-specific rules; no global shortcut is assigned.
- Privacy: local only.
- Dependencies: CopyQ 16.

### Toggle Upper/Lower Case

- Download: [commands/individual/toggle-upper-lower-case.ini](../../commands/individual/toggle-upper-lower-case.ini)
- Activation: context menu against selected application text.
- Behaviour: uppercase text becomes lowercase; all other text becomes uppercase.
- Strength: simple two-state transformation without claiming Moonlander shortcuts.
- Limitation: does not provide sentence/title case.
- Privacy: local only.
- Dependencies: CopyQ 16.

### Show Frequent

- Download: [commands/individual/show-frequent.ini](../../commands/individual/show-frequent.ini)
- Activation: menu or Meta+Shift+F.
- Behaviour: opens the `Frequent` tab menu populated by Clipboard Router.
- Strength: one unambiguous global shortcut for a most-recently-used index of text copied at least six times across normal history, URLs, `BIG`, `Artifacts`, and `Code`.
- Limitation: useful only when Clipboard Router is installed and frequency promotion has occurred.
- Privacy: local only; frequency counters do not store copied text. Leading/trailing whitespace variants share one counter and the indexed form is trimmed.
- Dependencies: CopyQ 16.

## Moonlander selected-text tools

Install [Moonlander Custom Config](https://github.com/YiftahCooper/Moonlander-Custom-Config) before these commands. Its scripts and `Moonlander.Reselect.exe` live under `%LOCALAPPDATA%\MoonlanderTextTools`; this repository provides only the CopyQ wrappers.

### Moonlander: Smart Title Case

- Download: [commands/individual/moonlander-smart-title-case.ini](../../commands/individual/moonlander-smart-title-case.ini)
- Activation: F13 or context menu against selected text.
- Behaviour: uses the companion transaction to apply smart title casing and restore the prior clipboard safely.
- Strength: selected-text transformation with clipboard restoration and caret handling.
- Limitation: selected text and the Moonlander companion runtime are required.
- Privacy: local only.
- Dependencies: CopyQ 16 and Moonlander Custom Config.

### Moonlander: Cycle Case

- Download: [commands/individual/moonlander-cycle-case.ini](../../commands/individual/moonlander-cycle-case.ini)
- Activation: F19 or context menu against selected text.
- Behaviour: cycles lower/upper case and reselects the result using the companion helper.
- Strength: preserves the Moonlander multi-line and reselection workflow.
- Limitation: selected text and the Moonlander companion runtime are required.
- Privacy: local only.
- Dependencies: CopyQ 16 and Moonlander Custom Config.

### Moonlander: Transplant Hebrew-English

- Download: [commands/individual/moonlander-transplant-hebrew-english.ini](../../commands/individual/moonlander-transplant-hebrew-english.ini)
- Activation: F22 or context menu against selected text.
- Behaviour: maps characters according to the physical Hebrew/English keyboard positions through the companion transaction.
- Strength: repairs text typed under the wrong keyboard layout without retyping it.
- Limitation: selected text and the Moonlander companion runtime are required.
- Privacy: local only.
- Dependencies: CopyQ 16 and Moonlander Custom Config.
