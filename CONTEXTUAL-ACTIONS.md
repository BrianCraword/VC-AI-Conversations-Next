# Contextual AI actions — 1.4.0

Approved behavior
- Start page: AI context, Memories, History only when not permanently visible. No New action in toolbar or sidebar.
- AI thread: New conversation, Memories, History when not permanently visible. Remove misleading duplicate Back/Conversations action.
- Drawer state: retain History as close control when open, reflect aria-expanded; Memories reflects existing owner state. Existing panel close/Escape mechanisms remain.
- Desktop shared Explore stays global. Mobile Explore stays separately divided at far end; composer retains bottom.
- Header icons disappear only while a corresponding toolbar button is actually mounted. Disabled toolbar or ineligible routes retain fallback controls.

Investigation
Normal-member production1.3 has vcai-history--persistent on desktop. Clicking History changes nothing. History owner reflectDrawerState explicitly suppresses drawer-open while persistent; toolbar incorrectly exposed its toggle. The fix consumes this existing state, without a second drawer state or storage.

Implementation boundaries
Existing permission/admission and draft protection, memory fetching/editing/storage, redirects, panel owners, and global header component are unchanged. This component only changes action availability/presentation and delegates existing events. Native sidebar New wrapper is hidden conditionally while the equivalent toolbar context/action is present.

Acceptance
Check landing/thread, hard load and route changes, desktop persistent history, mobile drawer open/close, Memories active state, only one overlay, resize, disabled modules, excluded interview/ordinary PM fallback, 320/390/tablet widths, light/dark, keyboard and unsaved draft.

Evidence
15 policy/panel-state tests pass. Discourse importer GJS and common/desktop/mobile CSS compilation recorded separately. Independent source review requested. Final candidate visual/runtime acceptance remains pending a permitted preview or deployment; static/source checks do not establish it. No production changes.

Final source evidence: Discourse2026.9 import includes toolbar modules and reports no JS/CSS errors; transaction rolled back. Independent verifier found no source blocker and independently passed15 tests. Candidate visual/runtime checks remain pending.
