# 1.6.3 recovery rollback

Brian reports the live site returned429 after updating component306 to1.6.2. Safe mode followed by disabling that component restored site access. Treat1.6.2 as withdrawn. The exact JavaScript/server failure has not been captured; do not claim the rate-limit mechanism or a specific module incompatibility as proven.

1.6.3 restores all executable/style/locale files to1.6.1 commit762833cdf7dbcc649e46f7b515356ee7230e860a. The new selector initializer is removed entirely, including its module imports and class patch. Only version metadata/documentation differs from1.6.1. This is a recovery rollback, not a fix for the original phone picker problem.

Production component remains disabled. Brian owns updating and controlled re-enable; the agent makes no live setting changes. Preserve component settings and temporary redirects. Before any future sheet release, capture live Discourse version/API compatibility and reproduce with that exact build; require phone acceptance and verify startup on unrelated routes as well as AI landing.

Evidence: owner-reported update/disable correlation, Git-normalized content comparison to1.6.1 product files, existing regression tests, independent rollback review. Production recovery after installing1.6.3 remains unverified.

Further evidence: a single unauthenticated live GET after disabling returned HTTP200. Generator identifies Discourse2026.10.0-latest commit821e9e2f9f94483a3be8d1e077cde0fd94970479; local validation was2026.9. Both new imported modules exist in that upstream revision, so missing-module failure is not established. Brian pasted429s for mini-profiler results, matchmaking next-step, chat channels and AI landing, plus a rejected AJAX promise. This confirms broad throttling symptoms, not the request initiator or root cause. No pre429 JavaScript exception captured.
