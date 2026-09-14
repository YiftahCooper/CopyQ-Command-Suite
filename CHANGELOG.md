# Changelog

## Unreleased

- Fix Markdown headings and quotations being mistaken for shell prompts and routed into Artifacts.
- Prefer Python highlighting for recognizable Python declarations instead of an incorrect generic lexer guess that can produce monochrome output.
- Resolve the installed Tesseract executable before OCR execution, avoiding CopyQ's stalled short-name launch when Tesseract is absent from PATH. Add a real exported-command regression with bilingual PNG input and PATH deliberately empty.
- Document checkout-based setup and deferring translation; verify selective updates preserve the existing translation command and Moonlander without requiring Azure configuration.
- Check selected dependencies during setup preview and block installation before command mutation when prerequisites are missing, including the Azure helper module and region configuration.
- Let Azure configuration reuse the existing encrypted key without requesting or replacing it; keep normal-user service acceptance separate from file checks.
- Fix setup's Read installed selection → Preview changes shortcut conversion: retain empty, single and multiple shortcut lists without `PROFILE_SHORTCUT_INVALID`.
- Add an inspectable PowerShell 7 / Windows Forms setup assistant with selective command installation, shortcut overrides, nonsecret profiles, preview and installed-definition verification.
- Preserve unrelated native command objects, refuse conflicting shortcuts and drift, and retain private command-only backups with guarded restore receipts. No clipboard-history backups or application upgrades.
- Add deterministic allowlist-based release ZIP packaging and setup guidance; dependency software installation stays explicit and separate.
- Split core features and individual runtime command bodies into focused source files. Generated imports embed only their dependency closure; remove the shared implementation monolith without new runtime dependencies.
- Rename Canonical Dispatcher to Clipboard Router while preserving its stable identity and import filename. Preserve the integrated 18-command inventory and Moonlander exports.
- Add optional Secret Protection (Standalone), excluded from normal bundles, with conflict detection against the integrated router. Document feature boundaries and native command backups.
- Permanently redact recognized credentials inside newly copied documents while leaving the current Windows clipboard unchanged for immediate original paste. History/menu paste uses only the redacted version, without a hidden original or new shortcut.
- Remove original alternate MIME representations from redacted history items, exclude them from frequency counting, and test that trash/undo and later automatic commands cannot recover the original secret.
- Preserve ordinary URL IDs and paths; redact only recognizable credential components. Document heuristic limits, formatting loss, and the separate Windows clipboard-history boundary.
- Check secrets and concealment metadata before image/owner passthrough, including clipboard data without plain text. Ensure notification failures cannot bypass suppression.
- Route standalone HTTP(S), FTP(S), and file URLs directly to `&URLs`, independent of page type or title fetching; recognize private Google Calendar feed capability URLs as sensitive.
- Document first-position dispatcher installation and disabling the redundant `&web` handler. Preserve existing history pending deliberate consolidation.
- Exercise actual automatic-command processing and tab storage in isolated CopyQ tests without modifying the system clipboard.

## 1.1.0 - 2026-07-29

- Added strong technical-artifact routing to a lazy `Artifacts` tab.
- Rebuilt `Frequent` as a whitespace-normalized secondary index across all eligible text destinations, ordered by most recent qualifying copy.
- Added undoable deletion through `(trash)` and local `Ctrl+Z`, including Frequent-counter dismissal and restoration.
- Expanded the public distribution to fifteen canonical and three Moonlander commands.

## 1.0.0 - 2026-07-19

Initial public release.

- Published thirteen general-purpose CopyQ 16 commands and three Moonlander integrations.
- Added sixteen individual imports plus canonical, Moonlander, and complete bundles.
- Removed machine-specific runtime paths in favour of CopyQ environment discovery.
- Added read-only dependency reporting and DPAPI-protected Azure Translator configuration.
- Added deterministic isolated-session export, import verification, privacy gates, and provenance documentation.
