# AI navigation 1.2.1 repair validation

Production symptom: vcai_navigation_enabled=true delivered to normal member, but no toolbar DOM on landing or existing AI topic.
Root cause: main 41122a7 has navigation initializer/component/policy/stylesheet at repository root. Discourse ignores those locations; common/common.scss and locales/en.yml also omit navigation additions.
Repair: restore the exact feaa9ff reviewed modules at canonical paths, stylesheet import and labels. Settings and policy unchanged. Root-level upload duplicates retained to avoid unrelated cleanup.

Checks on 2026-10-22:
- 10 navigation policy tests passed.
- Discourse 2026.9.0-latest real importer: original main navigation modules absent; repaired package navigation modules present.
- JS and common/desktop/mobile CSS compile without errors for both packages. Test database transaction rolled back.
- Regression runner: test/import-navigation-check.rb (expects /tmp/vcai-before and /tmp/vcai-after).

Not yet verified: final toolbar rendering/actions in the production browser after updating the component; real phone keyboard/upload/draft interactions. No live settings or deployment changes made.
