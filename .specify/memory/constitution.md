<!--
Sync Impact Report
- Version change: (template) → 1.0.0
- Modified principles: all placeholders → I. On-Device First, II. Never Guess, III. Test-First Extraction Core,
  IV. Platform Isolation Behind Interfaces, V. Speed Over Ceremony
- Added sections: Technology Constraints, Development Workflow
- Removed sections: none
- Templates requiring updates: none (plan/spec/tasks templates read this file at runtime)
- Deferred TODOs: none
-->
# FOCR Constitution

## Core Principles

### I. On-Device First (Semi-Offline)
The core flow (capture or upload → OCR → extract → confirm → save) MUST work with no network connection
on Android, iOS and Web. OCR MUST run on-device (Google ML Kit on mobile, bundled Tesseract.js on web;
no CDN-loaded assets at runtime). Confirmed records MUST be persisted locally and queued for later sync.
Network-dependent features (cloud OCR fallback, backend sync, cross-device duplicate checks) are
optional enhancements and MUST degrade gracefully when offline.
Rationale: salespeople work in the field with unreliable connectivity.

### II. Never Guess
A registration number MUST only be proposed if it matches `^A03(?:\d{13}|C\d{6})$` after
normalization, and (long format) its embedded DDMMYYYY date is a real calendar date, not in the future,
and within the configured recency window. Anything else MUST yield "not found", never a best guess.
Every extracted number MUST be shown in an editable pre-filled field and explicitly confirmed by a
human before it is saved.
Rationale: a wrong number silently submitted is worse than asking for manual entry.

### III. Test-First Extraction Core (NON-NEGOTIABLE)
Text normalization, candidate extraction and validation MUST live in pure Dart with no Flutter or
platform imports, and MUST be covered by unit tests written before the implementation. Every real
sample in `test/fixtures/` (image and/or captured OCR text) MUST have an expected-value test.
A regression on any fixture blocks merging.
Rationale: OCR engines change; the extraction rules are the stable, testable heart of the product.

### IV. Platform Isolation Behind Interfaces
OCR engine, image rotation, local storage, sync and cloud fallback MUST each be accessed through a
Dart interface, with platform implementations selected via conditional imports or dependency
injection. UI and domain code MUST NOT import platform plugins directly.
Rationale: lets us swap ML Kit for Apple Vision on iOS, or plug in the future backend, without
touching features.

### V. Speed Over Ceremony
Upright-image extraction SHOULD complete in under 1.5 s on a mid-range Android device; the rotation
search MUST stop at the first valid match and try at most 4 orientations. Heavy image work MUST run off
the UI isolate. Prefer the simplest design that meets the spec (YAGNI); no backend code until the
backend feature is specified.
Rationale: the tool exists to save salespeople time.

## Technology Constraints

- Flutter (stable channel) targeting Android, iOS and Web from one codebase.
- Mobile OCR: `google_mlkit_text_recognition` (Latin script). Web OCR: Tesseract.js via
  `dart:js_interop`, assets self-hosted under `web/`.
- Local persistence MUST work on all three platforms (IndexedDB-backed on web).
- No secrets or API keys in the client; any future cloud OCR is called through the backend.
- Images of applications are personal data: they MUST stay on-device unless the user explicitly
  triggers a cloud fallback, and MUST NOT be logged.

## Development Workflow

- Features follow Spec Kit: specify → (clarify) → plan → tasks → implement.
- `flutter analyze` MUST be clean and `flutter test` MUST pass before a task is marked done.
- Changes to the regex, normalization map or date rules MUST be accompanied by new fixture tests.

## Governance

This constitution supersedes other practices for the FOCR project. Amendments require updating this
file with a Sync Impact Report and a semantic version bump (MAJOR: principle removed/redefined;
MINOR: principle/section added; PATCH: wording). Plans MUST include a Constitution Check against these
principles, and any violation MUST be justified in the plan's Complexity Tracking table.

**Version**: 1.0.0 | **Ratified**: 2026-10-09 | **Last Amended**: 2026-10-09
