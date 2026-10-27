# Sunrise landing appearance — 1.6.0

Appearance-only update from 1.5.1 (c564d21), approved by Brian. The configured greeting logo URL, agent names, prompts, agent selector, navigation, drafts and conversation behavior are preserved. No production deployment or settings changes are included.

## Design and assets

- Supplied `Misty Sunrise Over Mountain Lake-1.png`, encoded as WebP at quality82 without changing dimensions/composition; 52,530 bytes versus original1,767,141 bytes. Bundled in about.json so theme import owns delivery; no external asset host required.
- Existing logo remains a separate image. Background position52%/32% and an18% height offset anchor the sun behind it. Scenery width follows the actual content, including beside the pinned desktop history sidebar. Decorative paint adds no layout height or pointer targets.
- Fade on both axes; light/dark palette veils38%/68%. Existing ambient-field switch disables the landscape. The normal plain background remains if its asset cannot load.
- Landing-only Georgia serif headline; no new font downloads. Existing body typography retained.
- Decorative SVG starter icons: book, seedling, scales, search, leaf, lightbulb. Exact configured default labels receive these icons; customized labels receive a neutral compass. Labels/prompts are not rewritten. Icons are hidden from assistive technology and cannot receive focus.

## Verification — local isolated Discourse2026.9 + Canvas

15 existing navigation/panel tests passed. Combined Canvas/navigation/AI import, JavaScript and common/desktop/mobile stylesheet compilation passed. Source and screenshots received independent review; browser interactions/measurements are builder evidence.

Final light viewport/document sizes:390x844/390x844;412x915/412x915. At320x568 the document is666px tall; natural scroll98px places disclaimer bottom497.44 above navigation top509. Desktop1440x1000 document width1425 (scrollbar), height1082; pinned sidebar and all six starters remain available. An earlier desktop scenery overflow was detected and corrected before delivery.

Largest native text20px at320x568: document823, scroll255, disclaimer bottom496.53, action targets45–47.5px. The inherited Ask shortcut crowds at this extreme size; Ask remains accessible. This check preceded the final scenery-only width/fade refinement; typography and layout sizing did not change afterward. Text preference restored to Normal.

Fallback tested with BOTH ambient-field and AI bottom-navigation integration disabled: no landscape/bar, Explore/History/Memories available, toolbar96px,390x844 document fit. Default integrated toolbar remains48px. Existing thread320 composer bottom509 aligns with bar top509; no landing scene mounted. Starter click filled the original configured prompt; unsent local draft cleared. No AI request, post, message or memory-data change. Browser console error check empty.

Final dark screenshot verifies palette-aware contrast. Screenshots and dimensions: `C:/Users/crawf/.codex/visualizations/2026/10/24/01a16b7e-d753-7ce2-9fbf-23f905b8fdfd/sunrise-landing/`.

## Rollout and limits

Brian updates the existing AI component from main. Header Navigation is unchanged. Retain existing navigation activation choice and temporary redirects. Roll back by restoring1.5.1/c564d21; no settings migration. Physical-phone keyboard/rotation/safe-area, real uploads, production stack and Safari rendering remain unverified. Local test fixtures use Forum Helper and a long Support greeting; those values are not shipped as changed configuration.
