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
