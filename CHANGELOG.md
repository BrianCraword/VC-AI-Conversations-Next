## 1.6.0 � Sunrise landing appearance

Adds the supplied mountain sunrise behind the existing greeting logo, a serif landing headline and meaningful decorative starter icons. Agent identities, prompts, logo URL, navigation and conversation behavior are unchanged. Scene respects the existing ambient-field switch and palette. See [design validation](SUNRISE-LANDING.md).

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

## 1.5.0 — shared mobile AI navigation (2026-10-25)

Paired Header Navigation 5.7 / AI Conversations Next 1.5 supports stable five-tab navigation on admitted mobile AI pages and a compact labeled toolbar. Opt in with `je_nav_ai_bottom_navigation_enabled` in shared_explore layout; default off pending physical-phone keyboard acceptance. Header measures the bar including safe area; AI offsets its native composer without changing native keyboard positioning. Missing or disabled integration retains the prior toolbar and suppression. Desktop, native menus, redirects, permissions and draft guards remain unchanged. No production deployment.

Also fits all five shared tabs at 320px, gives History/Memories priority over the bar, and focuses Close when You opens. See AI-BOTTOM-NAV.md for the candidate evidence and remaining device checks.

## 1.5.1 - Mobile viewport balance (2026-10-26)

Docks mobile contextual actions directly below the header with 44px targets. The start page uses remaining dynamic viewport space rather than an extra viewport-sized welcome section. Tighter responsive spacing and artwork keep the composer prominent; short screens, enlarged text and uploads retain natural scrolling. Desktop and native keyboard/composer behavior remain unchanged.

See [MOBILE-VIEWPORT.md](MOBILE-VIEWPORT.md) for measured results, rollback and remaining physical-device checks.
