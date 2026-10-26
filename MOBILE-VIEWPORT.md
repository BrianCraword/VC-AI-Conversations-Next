# Mobile viewport tuning - 1.5.1

Approved by Brian on 2026-10-26. CSS-only revision, limited to mobile widths under640px and the admitted AI navigation surface. No server, data, action, permission, redirect, setting-schema or Header Navigation changes.

## Cause and change
Live390x844 had97px real scroll on the idle start page. The theme minimum height (viewport minus110px) and native AI fixed height (viewport minus header minus5em) independently reserved a nearly full viewport inside header/toolbar/bottom-bar space. The mobile outlet now uses a minimum-height flex layout accounting for actual header and published navigation inset; the welcome section has natural height and grows into remaining space. No fixed-height clipping or page-scroll lock.

The action strip begins directly below the header,48px tall with44px action targets when shared navigation is active. Fallback two-row toolbar takes its natural96px height. Spacing, image/headline and composer padding are tighter; ambient artwork stays within the welcome section. Upload/agent/Ask and starter controls retain44px minimum targets. Threads only receive the compact strip; native transcript and composer behavior is unchanged.

## Verified on final candidate
- Local Discourse2026.9/Canvas import and JavaScript/common/desktop/mobile stylesheet compilation;15 existing AI eligibility/draft/panel checks pass.
- Normal member, long Support greeting and actual public Fire.svg artwork in isolated fixture:390x844 document844px;412x915 document915px;630x800 document800px. Toolbar top55px equals header bottom, height48px.
-320x568 document640px;72px scroll reaches disclaimer above bar. Largest native text setting (20px root) document823px;255px scroll reaches every input/action and disclaimer. Local text preference restored. The Ask keyboard shortcut is partly clipped at largest text, while Ask label/target remain available; inherited shortcut presentation is cosmetic.
- Topic320px: toolbar48px directly under55px header, composer bottom=bar top509px. No transcript overflow lock.
- Disabled bottom navigation390x844: document844px, fallback Explore/History/Memories present, toolbar96px. Desktop1440px returns to block outlet/original58px toolbar and14px rounded card, global navigation/sidebar retained. No browser console errors observed.
- Independent verifier inspected source/screenshots and found no substantive blocker. Browser/compiler results are builder evidence.

## Not verified and follow-up
Physical Android/iPhone keyboard, browser chrome/rotation and safe-area behavior, dark visual comparison, real upload growth and exact installed production stack remain unverified. No production settings/data changes or AI submissions. Test after updating the existing AI component; report clipping or draft/keyboard regressions before broad acceptance. Previous1.5.0 commit4888141 is the code rollback point; this revision adds no settings/migrations. Keep current Header Navigation5.7.0 and its activation choice unchanged.

Screenshots/measurements: chat artifacts mobile-viewport folder, including start-390.jpg,start-412.jpg,start-320.jpg,start-630.jpg,largest-text-320.jpg,thread-320.jpg,fallback-390.jpg,desktop.jpg.
