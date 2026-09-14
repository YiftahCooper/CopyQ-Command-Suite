# Credits and Provenance

This project is built for [CopyQ](https://github.com/hluk/CopyQ), created and maintained by Lukáš Holecek (`hluk`) and its contributors. The suite is licensed under GPL-3.0-only to match CopyQ's copyleft licensing model.

## Publication boundary

The repository contains only original commands and independent, substantial rewrites. It does not reproduce the command bodies from [`hluk/copyq-commands`](https://github.com/hluk/copyq-commands). Links below acknowledge inspiration and make the upstream commands easy to install from their original source.

## Independently rewritten command families

- Canonical Dispatcher was inspired by [Big Data Tab](https://github.com/hluk/copyq-commands/blob/master/commands/big-data-tab.ini), [Ignore Passwords and Tokens](https://github.com/hluk/copyq-commands/blob/master/commands/ignore-passwords-tokens.ini), and [Frequent Items Tab](https://github.com/hluk/copyq-commands/blob/master/commands/frequent-items-tab.ini) by `hluk`.
- Move to Trash (Undoable) and Undo Delete were inspired by the maintained [Undoable Move to Trash](https://github.com/hluk/copyq-commands/blob/master/commands/undoable-move-to-trash.ini) pair by `hluk`. This suite uses an independently structured implementation with private batch metadata, 30-day lazy cleanup, and Frequent-counter dismissal/restoration.
- Remove Background and Text Colors was inspired by [the upstream command](https://github.com/hluk/copyq-commands/blob/master/commands/remove-background-and-text-colors.ini) by `hluk`.
- Copy Items as JSON and Paste Items from JSON were inspired by [Copy/Paste Items as JSON](https://github.com/hluk/copyq-commands/blob/master/commands/copy-paste-items-as-json.ini), associated with `beefeater7` and `hluk`.
- Search All Tabs was inspired by [Search All Tabs](https://github.com/hluk/copyq-commands/blob/master/commands/search-all-tabs.ini), associated with `alexjulien`, `GFDGIT`, and `hluk`.
- To Title Case was inspired by [To Title Case](https://github.com/hluk/copyq-commands/blob/master/commands/to-title-case.ini) by `hluk`.
- Toggle Upper/Lower Case was inspired by [Toggle Upper/Lower Case of Selected Text](https://github.com/hluk/copyq-commands/blob/master/commands/toggle-upper-lower-case-of-selected-text.ini) by `hluk`.
- Show Frequent shares its original idea with [Frequent Items Tab](https://github.com/hluk/copyq-commands/blob/master/commands/frequent-items-tab.ini) by `hluk`.
- Copy and Search on Web was inspired by [Copy and Search on Web](https://github.com/hluk/copyq-commands/blob/master/commands/copy-and-search-on-web.ini) by `hluk`.
- Render Markdown was inspired by [Render Markdown](https://github.com/hluk/copyq-commands/blob/master/commands/render-markdown.ini) by `hluk`.
- Highlight Code was inspired by [Highlight Code](https://github.com/hluk/copyq-commands/blob/master/commands/highlight-code.ini) by `hluk`.
- Copy Text in Image was inspired by [Copy Text in Image](https://github.com/hluk/copyq-commands/blob/master/commands/copy-text-in-image.ini), associated with `hluk` and `niun`.
- Translate to English was inspired by [Translate to English](https://github.com/hluk/copyq-commands/blob/master/commands/translate-to-english.ini) by `hluk`.

## Recommended upstream commands used alongside this suite

These eleven commands are not distributed in this repository:

The legacy **Copy URL (web address) to other tab** should now be disabled when using Canonical Dispatcher: its `&web` destination duplicates the dispatcher's `&URLs` routing. **Tab for URLs with Title and Icon** remains optional enrichment after the dispatcher, with a standalone-URL filter. Its network requests and URL logging are separate from the suite's offline routing and content-free notifications.

| Command | Original source | Known contributors |
|---|---|---|
| Render HTML | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/render-html.ini) | `hluk` |
| Search & Replace | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/search-and-replace.ini) | `hluk` |
| Edit and Paste | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/edit-and-paste.ini) | `hluk` |
| Preview Image Files | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/preview-image-files.ini) | `hluk`, `GFDGIT` |
| Image Tab | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/image-tab.ini) | `hluk` |
| Tab for URLs with Title and Icon | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/tab-for-urls-with-title-and-icon.ini) | `hluk`, `metafaniel` |
| Copy URL (web address) to other tab | [Same upstream command](https://github.com/hluk/copyq-commands/blob/master/commands/tab-for-urls-with-title-and-icon.ini) | `hluk`, `metafaniel` |
| Tab Key to Select Next/Previous | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/tab-key-select.ini) | `hluk` |
| Edit Files | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/edit-files.ini) | `beefeater7`, `hluk` |
| Linkify | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/linkify.ini) | `hluk` |
| Snippets | [Source](https://github.com/hluk/copyq-commands/blob/master/commands/snippets.ini) | `hluk`, `m4r71n`, `pbodnar` |

Contributor attribution is based on the upstream repository history examined during the provenance audit. The upstream repository remains authoritative.

## Moonlander companion project

The three Moonlander CopyQ wrappers integrate with [YiftahCooper/Moonlander-Custom-Config](https://github.com/YiftahCooper/Moonlander-Custom-Config). That repository supplies the clipboard transaction scripts, transformations, installer, and reselection executable; none of those runtime files are duplicated here.
