## 1.4.2 — Navigation clarity

Validation and rollout: [clarity notes](docs/CLARITY-1.4.2.md).

Keeps History, Memories and Explore visibly labeled on mobile and constrained desktop toolbars. Mobile uses two columns; New remains thread-only. Actions, draft guards, Memories close and bottom-bar suppression are unchanged.

## 1.4.1 — Memories close button

Adds a labeled44px close button inside the fixed Memories header, reachable on full-width mobile panels. Uses the existing close path and returns focus to a visible Memories trigger. Memory data and permissions unchanged.

## 1.4.0 — Contextual AI actions

Remove New from the start page and redundant Back from threads. History follows the panel owner and is omitted when pinned open. Memories moves into the toolbar with expanded-state feedback. Duplicate header/sidebar actions stand down only while replacements are mounted. See CONTEXTUAL-ACTIONS.md for the approved behavior and validation limits.

## 1.3.0 compact AI action bar

Desktop groups the return/context label, History and primary New conversation action. Explore remains in shared global navigation; fallback Explore remains when that integration is unavailable. Mobile uses Back, New, and labeled History/Explore icons with 44px targets. Existing navigation enable setting, admission and draft protection remain unchanged. An empty legacy sidebar filter is hidden only while the current history filter is mounted; entered legacy filter text keeps it visible.

## 1.2.1 installation repair

Restores the AI navigation initializer, component, policy, stylesheet and translations to the directories Discourse imports. Update this existing component from GitHub after the repair is merged. Keep vcai_navigation_enabled enabled and reload the page. Do not upload individual flattened files; preserve the repository folder structure.

# VC AI Conversations Next

Theme component for the AI conversation pages on victoriouschristians.com:
workspace landing, conversation history, saved memories, header controls and
the response-status indicator. Each module has its own on/off setting.

- **Type:** theme component (site id 306, under VC-Canvas)
- **Repo:** https://github.com/BrianCraword/VC-AI-Conversations-Next

## Key files
- `javascripts/discourse/lib/vcai-route-state.js` — one body-class observer that tells every module whether the page is the AI landing or an AI thread
- `javascripts/discourse/api-initializers/vcai-*.gjs` — one file per module
- `settings.yml`, `locales/en.yml` — settings and their descriptions

## Notes
- **Never re-set a body class that is already right.** Several modules watch
  `<body class>`. `classList.add`/`remove` rewrite the attribute even when
  nothing changes, which wakes every watcher; use `classList.toggle(name, force)`.

## 1.5.0 — shared mobile AI navigation (2026-10-25)

Paired Header Navigation 5.7 / AI Conversations Next 1.5 supports stable five-tab navigation on admitted mobile AI pages and a compact labeled toolbar. Opt in with `je_nav_ai_bottom_navigation_enabled` in shared_explore layout; default off pending physical-phone keyboard acceptance. Header measures the bar including safe area; AI offsets its native composer without changing native keyboard positioning. Missing or disabled integration retains the prior toolbar and suppression. Desktop, native menus, redirects, permissions and draft guards remain unchanged. No production deployment.

See [AI-BOTTOM-NAV.md](AI-BOTTOM-NAV.md) for verification, phone acceptance and rollback.
