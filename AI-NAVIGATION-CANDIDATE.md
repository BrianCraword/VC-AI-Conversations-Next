# AI navigation candidate — 2026-10-19

Opt-in candidate, not deployed or accepted for production. VC AI Conversations Next 1.1.0 pairs with Header Navigation 5.4.0. Both branches: codex/ai-conversation-navigation.

AI: adds a top toolbar with Conversations, New conversation and Site menu; uses a context label on landing. It rejects guests, ordinary topics/PMs, missing bot metadata, mismatched route/topic IDs and configured restricted bot participants. Default excluded ID -1237 is VC's interview bot; review this setting whenever that bot changes. Draft text, attachments and uploads block leaving rather than silently discarding content. The toolbar defaults off (vcai_navigation_enabled=false).

Navigation: provides a versioned data-only adapter for the toolbar's menu. It reuses existing parent/child surface and group gates and dynamic destinations. Bottom suppression and existing menus are unchanged. Direct Feed remains available if the adapter is absent. External menu destinations are omitted from this first internal-navigation candidate.

Independent verifier source review: initial narrow-screen panel anchoring defect fixed; landing self-link changed to context label; attachment-only guard added. Re-review found no confirmed blocker for preparing the disabled candidate. This is NOT production acceptance.

Validation: 34 focused checks passed (policy/menu gates, actual DOM draft fixtures including attachment-only/in-progress, content-tag preprocessing, Babel/Glimmer parse, Sass, YAML, default-off). Repository tests additionally reproduce admission/menu cases. These are not installed Discourse integration tests. Docker engine was unavailable and WSL Podman had no test container. Runtime lifecycle, layout at phone/zoom widths, native draft persistence, keyboards and role fixtures remain required before enablement. No live UI changed or prompt sent.

Extension point verified against core 821e9e2f9f94483a3be8d1e077cde0fd94970479: application.gjs above-main-container; plugin-outlet renders componentClass without legacy wrapper. Exact core docked-composer.gjs confirms .docked-composer__upload for pending and complete uploads. Native New Question event/router/focus semantics were inspected in the public installed AI bundle. Local/full deployed component equality has not been attested.

Rollback: leave toolbar setting off or turn it off. Nav adapter is inert without a requester. Restore previous source revisions if needed: AI 41868afa867d4f937802f14bfcde7e9c3a2c0e7e; Nav 47eae7fbe73b5efe0afe64749a0df6806607448e. No homepage/logo/Canvas/permission configuration changed. Brian owns installation. Before installation confirm actual source/configuration and run integration tests against a non-production Discourse instance.

Run repository tests: node --test test/navigation-policy.test.mjs (AI) and node --test test/site-menu.test.mjs (Nav). The shared project navigation-plan-2026-10-18/candidate-01 folder retains the larger validation runner, results and source evidence.
