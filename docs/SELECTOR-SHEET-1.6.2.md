> WITHDRAWN 2026-10-28: Brian reported a production outage after updating1.6.2; disabling component306 restored access. Local publication acceptance below did not establish production compatibility. See ROLLBACK-1.6.3.md.

# Mobile selector sheet 1.6.2

## Problem and scope
Brian reports that1.6.1 opens then immediately closes on a physical phone. Chrome mobile-width inspection stays open but shows starters/disclaimer overlapping the menu. The phone dismissal itself was not reproduced locally and its exact event cause remains unconfirmed.1.6.1 publication checks did not establish physical-device acceptance.

Below768px, AI landing agent/model DropdownSelectBox opens a top-layer HTML dialog instead of the floating native popup. It never enters native expanded state, avoiding that popup's outside-dismiss path. Only Close, Escape, choosing, route exit, component destruction or switching to desktop closes it; keyboard/visual viewport changes only resize it. Background controls are inert while modal. Search is optional to use; initial focus is Close so opening does not summon the keyboard.

The sheet reads native permission-filtered choices and content customizations and uses native validation/change callbacks. It does not reconstruct recipient/agent/model settings or edit drafts/uploads. Names/descriptions render as safe plain text. Native fallback remains when workspace/master disabled or outside landing; desktop retains native popup. Desktop composer stacking now outranks starter/disclaimer siblings. No navigation, agent identity, prompt or redirect changes.

## Evidence
22 existing regression/boundary tests passed. Combined Canvas/nav/AI Discourse2026.9 importer/JS/common/desktop/mobile compilation passed. Local normal-member browser verified390px opaque modal, search, Creative selection retaining draft, selection/Close focus restoration, Escape, and320x480 list scrolling (408px panel,320px width). Desktop1280 popup opaque above page siblings. No browser errors observed. Independent source review found no blocking native-option defect.

## Remaining acceptance
Physical Android/iPhone touch, software keyboard, Safari, real uploads and a runtime fixture with multiple underlying models remain unverified. Code covers both native dropdown classes; observed runtime choice was agents. Arbitrary plugin-added special action items with onSelect handlers are not part of the native agent/model fixture. Production untouched; Brian owns deployment.

On the affected phone: open with keyboard closed, then while editing; leave open, scroll/search, select, reopen, Close/cancel, rotate. Confirm no immediate dismissal, overlapping background text, lost draft/attachments or incorrect selected agent. Verify desktop and native fallback after update. Keep this issue open until phone acceptance.

Update the existing component from main; preserve settings. Roll back to1.6.1 commit762833cdf7dbcc649e46f7b515356ee7230e860a if needed (that version still has the reported phone issue).
