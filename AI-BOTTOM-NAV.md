# Shared mobile navigation on AI â€” candidate acceptance

Header Navigation 5.7.0 pairs with VC AI Conversations Next 1.5.0. Update the existing components; preserve their settings. Brian owns production deployment.

## Activation and fallback
The new `je_nav_ai_bottom_navigation_enabled` flag defaults **false**. It additionally requires `shared_explore`, a permitted mounted mobile Explore owner, and the compatible admitted AI toolbar. Enable only for controlled physical-phone acceptance first. Disabling the flag restores the prior AI toolbar/Explore and bottom suppression after refresh. Older/missing AI compatibility also retains fallback; desktop uses the existing rich navigation.

## Behavior
Feed Â· Explore Â· AI Â· Messages Â· You remain in stable positions. AI stays highlighted on admitted start/conversation pages; private messages and restricted interviews retain existing classification. The contextual row contains New / History / Memories, with New absent at start. Header publishes its measured occupied height including safe area; AI uses that as the docked composer's lower edge. Native keyboard top positioning and native composer height remain untouched. Keyboard signals temporarily hide the bar; History/Memories and native composer/modal/chat/fullscreen suppression take priority. You opens focused on Close and Escape restores its invoker.

## Evidence from this candidate
- 66 automated checks pass: projection/gates, AI eligibility, draft/attachment detection, occupancy priorities, paired handshake/missing flag/mobile owner, viewport keyboard threshold, regression preventing recursive eligibility.
- Combined local Discourse 2026.9 + Canvas imports, JavaScript and common/desktop/mobile stylesheet compilation pass. Upgrade preserved all 31 sampled stored settings; disabling new flag verified.
- Local ordinary member browser: 320/390px start/thread, five tabs and AI highlight; 54px contextual row and 44px controls. At320px composer bottom=bar top681px; at390px=785px. Expanded six-line composer and formatting toolbar stayed above bar. Native draft guards blocked Feed/Messages/AI, Explore Latest and You Preferences; draft retained, including reload recovery.
- History and Memories hide bar and set inset0, then restore59px on close. Memories returns focus. You close focus/Escape return pass. Desktop resize clears coordination/inset/mobilebar. Discussions removes coordination and highlights Explore. Disabled-setting browser fallback restores New/History/Memories/Explore and hides bar. Final preview console checked: no errors.

## Limits and remaining acceptance
This is accepted only as a default-off candidate, not as enabled production acceptance. Physical Android/iPhone software keyboard, rotation, device safe areas, long AI exchanges, real upload progress, dark visual review and the exact installed production stack remain UNVERIFIED. Local persistent-memory backend is unavailable; no memory data was changed. A start-page draft test hit a browser automation dialog stall, so full completion is not claimed. No AI requests or production submissions were made.

Before broad activation: test both phone platforms with start/thread drafts, keyboard open/close, rotation and browser chrome movement; short/long conversations, scroll-to-end, growing composer, formatting/upload, History/Memories/Explore/You, direct links and Back; native overlays; signed-out/noneligible contexts; dark palette. Verify no lost text, obscured controls, duplicate safe-area gap or incorrect active tab. Roll back immediately with the flag if clearance or restoration fails.

Source ownership: Header owns visibility/measurement/personal-sheet focus. AI owns eligibility advertisement, compact toolbar and composer styling. Server/plugin/data logic, Canvas, permissions, redirects, native menus and unread calculations were not changed.

Independent verifier accepted this exact candidate for default-off publication after source/screenshot review and independently running occupancy tests. Final320px shared bar fits five61x56px tabs in305px available width; all labels have equal client/scroll widths. Earlier clipped-You screenshots were replaced after correction.
