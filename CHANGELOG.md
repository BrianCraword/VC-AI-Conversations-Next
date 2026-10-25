## 1.4.2 — Navigation clarity

Keeps History, Memories and Explore visibly labeled on mobile and constrained desktop toolbars. Mobile uses two columns; New remains thread-only. Actions, draft guards, Memories close and bottom-bar suppression are unchanged.

## 1.4.1 — Memories close button

Adds a labeled44px close button inside the fixed Memories header, reachable on full-width mobile panels. Uses the existing close path and returns focus to a visible Memories trigger. Memory data and permissions unchanged.

## 1.4.0 — Contextual AI actions

Remove New from the start page and redundant Back from threads. History follows the panel owner and is omitted when pinned open. Memories moves into the toolbar with expanded-state feedback. Duplicate header/sidebar actions stand down only while replacements are mounted. See CONTEXTUAL-ACTIONS.md for the approved behavior and validation limits.

## 1.3.0 — 2026-10-23

- Compact AI action bar using Canvas-compatible colors, rounded corners, icons, and a primary new-conversation action.
- Short mobile labels and 44px controls; omit duplicate desktop Explore when global shared Explore is available.
- Conditionally hide the empty legacy history filter while its replacement is mounted.

## 1.2.1 — 2026-10-22

- Repair the flattened 1.2.0 upload: navigation code is now in javascripts/discourse, styles in stylesheets, and strings in locales/en.yml.
- Restore the navigation stylesheet import. Settings and admission/draft policies are unchanged.

# Changelog

## 1.0.1 — 2026-10-11
- Fixed: the Memories module rewrote the page's body class about 60 times a
  second on every page, forever. It watches the body class, and on each
  change it re-applied itself with `classList.remove`/`add`, which rewrite
  the attribute even when nothing changes, so it kept waking itself up. It
  now uses `classList.toggle(name, force)`, which leaves the attribute alone
  when it is already right. Seen live: 120 body-class rewrites in 2 seconds
  before, 0 after.

## 1.0.0 — 2026-10-11
- First upload to GitHub (unversioned until now). Installed on the site as
  component id 306, replacing the hand-uploaded copy (304).
