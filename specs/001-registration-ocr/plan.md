# Implementation Plan: BCA Registration Number Capture

**Branch**: `001-registration-ocr` | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-registration-ocr/spec.md`

## Summary

A Flutter app (Android, iOS, Web) that extracts BCA credit-card registration numbers from a
screenshot, a photo or a live camera scan, entirely on-device. Mobile uses Google ML Kit text
recognition and Web uses self-hosted Tesseract.js. A pure-Dart extractor normalizes OCR text, prefers
the candidate after the anchor text, and validates the format and embedded date. The orientation
search tries 0/90/180/270° with early exit. Confirmed numbers are saved to an offline local store
(sembast) as `pending`, with per-device duplicate detection. Backend sync and cloud OCR are
interfaces with no-op implementations.

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47 (stable)

**Primary Dependencies**: google_mlkit_text_recognition ^0.17.1, camera ^0.12.1, image_picker ^1.2.4,
image ^4.10.1, sembast ^3.8.11, sembast_web ^2.4.6, path_provider ^2.1.6, flutter_riverpod ^3.4.3,
uuid ^4.6.0, web ^1.1.1, clock (test seams). Web: Tesseract.js 7.0.0 (self-hosted assets).

**Storage**: sembast (file on mobile, IndexedDB on web). Images are stored as downscaled JPEG blobs.

**Testing**: flutter_test (unit + widget), integration_test (device OCR on the image fixtures)

**Target Platform**: Android 7.0+ (minSdk 24), iOS 15.5+, current Chrome/Safari/Edge

**Project Type**: mobile-app + web (single Flutter codebase)

**Performance Goals**: upright extraction < 2 s on a mid-range phone; worst case (4 orientations) < 5 s;
live scan lock < 3 s

**Constraints**: core flow fully offline; no CDN at runtime on web; no image leaves the device; heavy
image work off the UI isolate on mobile

**Scale/Scope**: 1 user per device, about 10–100 captures per day, 4 screens (Home, Scan, Review,
History)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How |
|---|---|---|
| I. On-Device First | ✅ | ML Kit and Tesseract.js run locally, web assets are self-hosted, the service worker caches the shell, records go to sembast |
| II. Never Guess | ✅ | `RegistrationNumber.tryParse` is the only constructor; NotFound → manual entry; confirmation is always explicit |
| III. Test-First Core | ✅ | `lib/core/extraction/` is pure Dart; tests are written before the code; fixtures for all 7 samples |
| IV. Platform Isolation | ✅ | `OcrEngine`, `ImageOps`, `SubmissionRepository`, `SyncService`, `CloudOcrFallback` with conditional imports and Riverpod DI |
| V. Speed Over Ceremony | ✅ | early-exit rotation, max 4 passes, downscale to 2000 px, `compute` (isolate on mobile); no backend code |

Post-design re-check: ✅. No violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-registration-ocr/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/interfaces.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks output
```

### Source Code (repository root)

```text
lib/
├── main.dart
├── app.dart                         # MaterialApp, routes
├── providers.dart                   # Riverpod providers (DI)
├── core/
│   ├── extraction/
│   │   ├── registration_number.dart # value type + validation
│   │   ├── normalizer.dart          # confusion map, token merge
│   │   └── registration_extractor.dart
│   ├── image/
│   │   └── image_ops.dart           # interface + package:image impl (via compute)
│   └── ocr/
│       ├── ocr_engine.dart          # interface
│       ├── ocr_engine_factory.dart  # conditional export
│       ├── mlkit_ocr_engine.dart    # io
│       ├── tesseract_web_ocr_engine.dart # web, js_interop
│       └── scan_pipeline.dart
├── data/
│   ├── models.dart                  # Capture, RegistrationRecord, drafts
│   ├── submission_repository.dart   # interface
│   ├── sembast_submission_repository.dart
│   ├── db_factory.dart              # conditional: io / web
│   └── extension_points.dart        # SyncService, CloudOcrFallback + no-op impls
└── features/
    ├── home/home_screen.dart
    ├── scan/scan_screen.dart        # live camera, periodic stills
    ├── review/review_screen.dart    # image + editable field + duplicate dialog
    └── history/history_screen.dart

web/
├── index.html                       # registers sw.js
├── sw.js                            # offline cache
└── tesseract/                       # tesseract.min.js, worker.min.js, core/*.wasm(.js), lang/eng.traineddata.gz

test/
├── fixtures/
│   ├── README.md                    # expected values per image
│   ├── images/                      # 7 originals (supplied by the owner)
│   └── ocr_text/                    # captured/synthetic OCR text per sample
├── core/extraction/                 # unit tests
├── core/ocr/scan_pipeline_test.dart # with a fake OcrEngine
├── data/                            # repository tests (sembast memory factory)
└── features/review_screen_test.dart

integration_test/ocr_samples_test.dart
tool/fetch_tesseract_assets.sh
tool/gen_fixture_images.dart        # embeds fixture images for the device test
```

**Structure Decision**: a single Flutter project with layered `core/` (pure logic + platform
interfaces), `data/` (persistence) and `features/` (UI). Platform variants are chosen with
conditional imports (`if (dart.library.js_interop)`).

## Complexity Tracking

No violations.
