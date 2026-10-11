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
