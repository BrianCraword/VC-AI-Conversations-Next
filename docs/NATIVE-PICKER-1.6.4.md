# 1.6.4 - Native mobile picker dialog

This release starts from the recovered 1.6.3 baseline. On the AI landing page at mobile widths, activating an agent or model picker moves the existing native control into a modal dialog. It retains native choices, eligibility, selection callbacks and keyboard controls. Close, Escape, selection, route changes and desktop resize restore the control. The list scrolls within the dialog; the underlying page cannot overlap it. Desktop keeps the native dropdown with corrected stacking. The session agent label refreshes after selection.

## Incident boundaries
Brian reported immediate production 429 errors on installing 1.6.2, before touching a picker, and confirmed recovery with 1.6.3. The added 1.6.2 initializer eagerly imported and patched the shared DropdownSelectBox class with classPrepend. That startup change is a suspect, not a proven root cause. The sheet rendering/selection functions ran only after opening. CSS, labels and documentation contain no request loop. Testing the withdrawn release against production core 821e9e2f9f94483a3be8d1e077cde0fd94970479, including an optimized browser build, did not reproduce the startup storm. Local plugins/configuration are not a complete production clone.

1.6.4 does not restore that initializer, import DropdownSelectBox, modify core classes, copy choices, or call selection APIs. Its startup code registers scoped input handlers; the dialog is created only after a member activates a native picker. No network request or polling loop is added. This removes the suspect integration rather than claiming the 429 mechanism is proven fixed.

## Validation
- 22 existing AI regression checks and independent source review passed.
- Discourse 2026.10.0-latest at exact core above, Rails test environment, optimized frontend, isolated cloned database; Canvas/nav/AI combined compilation.
- Native agent selection and two-model selection preserve an unsent draft. Session label updates.
- 320x480: dialog stays within viewport; native option collection scrolls and last option can be selected. 390px: modal display; Close/Escape/focus return; Shift+Tab onto Close does not dismiss.
- Resizing an open dialog to desktop restores control and removes body lock; desktop native dropdown remains available.
- No posts, AI requests, uploads or memory changes submitted. Local model fixtures use dummy credentials and are not release content.

Physical-phone touch, software keyboard, Safari, real uploads, searchable lists with more than eight agents, and full production stack remain device/installed acceptance items. Native search remains native; this release does not reconstruct it.

## Controlled owner test and rollback
Update existing component306 from main to1.6.4; hard-refresh once. First verify normal page load, then agent/model opening, selecting, Close/reopen, short draft retention and keyboard clearance on the affected phone. Report the first unexpected behavior before repeatedly reloading. Keep1.6.3 (44e510756b034d7bce02071c6d2fbd2eccb5a768) as rollback. If startup fails, safe-mode disabling306 remains the known recovery path. Production deployment is Brian-owned.