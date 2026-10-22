# Shared Explore candidate — 5.6.0 / AI Next 1.2.0

This is an opt-in candidate, not a production acceptance record. Update the existing configured components, not a fresh component with example settings.

## Behavior

- `je_nav_layout: shared_explore` uses the same rich Explore directory on Feed and standard pages. Desktop retains Discussions, Word and Matchmaking shortcuts when the strip is wide enough. Narrower desktop strips keep these destinations in Explore.
- Mobile browsing uses Feed, Explore, AI, Messages and You. Existing surface and permission gates still apply. Labels stay visible; scroll does not hide tabs or rearrange them.
- The bottom tabs and reserved padding stand down for AI/composer occupancy. The same sheet is opened from a top control. AI Next 1.2 supplies Conversations, New conversation, Explore and the existing History action on admitted AI routes; restricted interviews are excluded.
- Unsent AI text and uploads block navigation through the new controls. No draft is silently cleared or serialized. Native header/browser navigation still belongs to Discourse.
- Shared mode preserves native header controls; it does not suppress them before replacements are ready.
- Missing AI Next leaves native controls and the navigation-owned Explore fallback. AI Next preserves its previous menu under legacy navigation or when the shared renderer is unavailable.

## Upgrade and activation

1. Export existing component settings and record source revisions. Last observed active IDs: nav250 and AI306; duplicate nav314 absent. Confirm these at installation.
2. Update these existing components from the coordinated candidate branches. Preserve `je_nav_destinations`, identity links and all saved settings. New defaults remain `je_nav_layout: legacy` and `vcai_navigation_enabled: false`.
3. Preview on a non-default theme with the same saved configuration. A fresh component requires explicit configuration import; a ZIP cannot transfer another component's database settings.
4. For the intended desktop Messages shortcut, change only the saved Messages row's `surface` from `mobile` to `both`. This is an explicit presentation choice; source code never widens it. Preserve its members gate and badge source.
5. Ensure `je_nav_show_mobile` is true. Set AI `vcai_navigation_enabled` true, then select nav `je_nav_layout: shared_explore`. Reload. The old focus/unified flags are ignored only in this mode.
6. Test Feed, Latest/categories, ordinary topics, messages, AI landing/topic and interview; desktop/tablet/phone, keyboard, attachments, unsent drafts, Back/Forward and role gates. Physical iOS/Android keyboard tests remain required. Brian controls production activation.

Leave both temporary logo and homepage redirects unchanged. Feed links point directly to `/feed`; redundant brand Home is omitted only in the shared presentation. No redirect plugin merger or Plaza retirement is included.

## Rollback

Select `je_nav_layout: legacy` and restore the previous AI toolbar setting. Restore Messages surface from the exported settings if changed. If a source rollback is required, nav base is 9b8a8f948e5cfe9df9150aea164671b0d779456b, AI base is 9fe781af494d9b7def567670f9652feec74590ae. Restore the original branch/source and update existing components. Do not enable the duplicate test component.

## Validation limits

Builder Node tests, configured-destination role/surface parity and local Discourse compilation support candidate preparation. They do not establish visual or physical-phone acceptance. Local compiler is Discourse2026.9; Canvas tested is2.10.1. Exact installed live core remains a separate acceptance target. Contextual ordinary-topic Back is deferred; deterministic Conversations return is included.
