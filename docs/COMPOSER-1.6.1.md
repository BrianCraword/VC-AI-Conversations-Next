# Composer reliability 1.6.1

The relocated native selector was inside an overflow-hidden wrapper. Opening it scrolled that wrapper and clipped the composer. Landing-only visible overflow restores the native menu; mobile action columns reserve room for upload, selector and Ask.

Draft feedback starts at 90% of configured max_post_length. A native service preflight rejects oversized payloads including attachment markdown and separators. Unicode codepoints match server counting. No truncation or agent changes. Rejecting rather than resolving preserves uploads in the native caller. Inline count covers text; its wording explains attachments also count at send time.

## Validation - 2026-10-27

22 tests pass, including seven length/Unicode/attachment boundaries. Combined Canvas/nav/AI JavaScript and common/desktop/mobile compilation pass in Discourse2026.9. Independent source review found no blocking defects.

Normal-member390px picker opens at wrapper scrollTop0 and selects Creative with draft intact. At320px searchable selection restores Forum Helper with draft intact and no textarea horizontal overflow. A32,001-character Ask attempt against local limit32,000 displays the new rejection dialog and keeps all text. Textarea is bounded at253px with internal scrolling; client/scroll widths both306px. Reducing text clears aria-invalid.

## Limits and rollout

Physical phones, Safari, software keyboard and real attachment submission remain unverified. Simulated Control+Enter did not activate the native shortcut in this preview; no keyboard-runtime claim. Attachment accounting and service coverage were source/unit reviewed. Production limit not queried. No production changes.

Brian updates the existing VC-AI-Conversations-Next component from main. Preserve settings and redirects. Rollback:1.6.0 commit1e0de536771d510b707012fbf00d0b3b6850be8f. Master/workspace switches retain native fallback.
