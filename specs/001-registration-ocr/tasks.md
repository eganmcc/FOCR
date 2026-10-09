---
description: "Task list for BCA Registration Number Capture"
---

# Tasks: BCA Registration Number Capture

**Input**: Design documents from `/specs/001-registration-ocr/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/interfaces.md, quickstart.md

**Tests**: The tests below are included because the constitution requires a test-first extraction core
(Principle III). Each test task must fail before its implementation task.

**Organization**: Tasks are grouped by user story. US1+US2 are the MVP.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Create the Flutter app in the repo root: `flutter create --org co.id.ptdika --project-name focr --platforms=android,ios,web .`
- [X] T002 Add dependencies to pubspec.yaml: google_mlkit_text_recognition ^0.17.1, camera ^0.12.1, image_picker ^1.2.4, image ^4.10.1, sembast ^3.8.11, sembast_web ^2.4.6, path_provider ^2.1.6, flutter_riverpod ^3.4.3, uuid ^4.6.0, web ^1.1.1, clock; dev: integration_test
- [X] T003 [P] Configure analysis_options.yaml (flutter_lints + strict-casts, strict-raw-types)
- [X] T004 [P] Set up iOS: platform 15.5 and armv7 exclusion in ios/Podfile; NSCameraUsageDescription and NSPhotoLibraryUsageDescription in ios/Runner/Info.plist
- [X] T005 [P] Set up Android: minSdk 24 in android/app/build.gradle(.kts); CAMERA permission in android/app/src/main/AndroidManifest.xml
- [X] T006 [P] Create tool/fetch_tesseract_assets.sh: download tesseract.js@7.0.0 (tesseract.min.js, worker.min.js), tesseract.js-core@7 (simd-lstm + lstm .wasm.js/.wasm) and eng.traineddata.gz into web/tesseract/
- [X] T007 [P] Create test/fixtures/README.md (image filename → expected number table from spec US2) and the test/fixtures/images/ folder

---

## Phase 2: Foundational (blocks all stories)

- [X] T008 [P] Write failing tests for RegistrationNumber.tryParse in test/core/extraction/registration_number_test.dart: valid long/short; reject a bad format; reject an invalid date (31022026); reject a future date; reject a date older than 60 days; accept exactly 60 days; short format skips the date checks. Clock fixed at 2026-10-09
- [X] T009 Implement lib/core/extraction/registration_number.dart (value type, `format` long|short, `applicationDate` for long only, `ValidationResult` reasons badFormat/invalidDate/futureDate/tooOld)
- [X] T010 [P] Write failing tests in test/core/extraction/normalizer_test.dart: the confusion map applies to digit positions only (O/o/Q/D→0, I/l/i/|/!→1, S/s→5, B→8, Z/z→2); `4`→`A` only at position 0; `c`/`(`/`G`→`C` only at position 3; internal spaces merge
- [X] T011 Implement lib/core/extraction/normalizer.dart
- [X] T012 [P] Create OCR-text fixtures test/fixtures/ocr_text/*.txt for the 7 samples (clean + noisy variants: split token, O/0 and l/1 confusions, extra numbers on the page, Indonesian page text around the anchor)
- [X] T013 Write failing tests in test/core/extraction/registration_extractor_test.dart: every ocr_text fixture → its expected number; the anchor candidate wins over an earlier valid global candidate; no candidate → NotFound with rejected reasons; never return an invalid value
- [X] T014 Implement lib/core/extraction/registration_extractor.dart (anchor pass "adalah" / "nomor registrasi:?", then global pass, as in research R9)
- [X] T015 [P] Define the OcrEngine interface in lib/core/ocr/ocr_engine.dart and the conditional factory in lib/core/ocr/ocr_engine_factory.dart (io → MlKit, js_interop → Tesseract)
- [X] T016 [P] Implement ImageOps (normalize: EXIF + downscale to maxSide 2000 + JPEG; rotate 90/180/270) in lib/core/image/image_ops.dart via `compute` (isolate on mobile, inline on web)
- [X] T017 Create lib/providers.dart (Riverpod providers: clock, ocrEngine, imageOps, extractor, scanPipeline) and the lib/main.dart / lib/app.dart shell with routes Home, Review, Scan, History

**Checkpoint**: `flutter test` is green for the extraction core.

---

## Phase 3: User Story 1 — Extract from an uploaded image (P1) 🎯 MVP

**Goal**: Pick an image → number pre-filled in an editable field → confirm.
**Independent test**: upload the upright and email samples on Android → correct prefill.

- [X] T018 [P] [US1] Implement MlKitOcrEngine in lib/core/ocr/mlkit_ocr_engine.dart (temp file → InputImage.fromFilePath → TextRecognizer(latin); delete the temp file; return '' when there is no text)
- [X] T019 [P] [US1] Implement TesseractWebOcrEngine in lib/core/ocr/tesseract_web_ocr_engine.dart (js_interop bindings to createWorker with local workerPath/corePath/langPath; lazy single worker; PSM 6)
- [X] T020 [P] [US1] Add `<script src="tesseract/tesseract.min.js">` to web/index.html
- [X] T021 [US1] Implement ScanPipeline.scan with tryRotations=false first in lib/core/ocr/scan_pipeline.dart (normalize → OCR → extract → ScanResult with elapsed, rawText, normalizedImage)
- [X] T022 [US1] Write a widget test for the review screen in test/features/review_screen_test.dart: the prefill shows; editing to an invalid value disables Confirm and shows the reason; NotFound shows the manual-entry hint
- [X] T023 [US1] Implement HomeScreen with "Upload image" (image_picker, rejects > 20 MB) in lib/features/home/home_screen.dart
- [X] T024 [US1] Implement ReviewScreen in lib/features/review/review_screen.dart (image preview, editable pre-filled TextField validated via RegistrationNumber.tryParse, Confirm button, processing indicator)

**Checkpoint**: an upright upload works end to end on Android and web.

---

## Phase 4: User Story 2 — Robust real-world photos (P1) 🎯 MVP

**Goal**: rotated, glary or blurry samples extract correctly with no manual rotation.
**Independent test**: all 7 fixture images pass integration_test/ocr_samples_test.dart.

- [X] T025 [US2] Write a failing test in test/core/ocr/scan_pipeline_test.dart with a fake OcrEngine that returns text only for a specific rotation: the pipeline tries [0,90,180,270] in order, stops at the first Found, reports rotationDegrees, and makes at most 4 OCR calls
- [X] T026 [US2] Extend ScanPipeline with the rotation search (tryRotations=true default) in lib/core/ocr/scan_pipeline.dart
- [X] T027 [US2] Web: on NotFound after all rotations, retry the best orientation with PSM 11 in lib/core/ocr/tesseract_web_ocr_engine.dart (exposed via an optional `recognizeAlternate`)
- [X] T028 [US2] Write integration_test/ocr_samples_test.dart: load each test/fixtures/images file as an asset, run the real ScanPipeline with Clock fixed at 2026-10-09, and expect the number from the README table
- [X] T029 [US2] Make the fixture images available to the on-device test without shipping them: tool/gen_fixture_images.dart embeds test/fixtures/images/* into the git-ignored integration_test/fixture_images.g.dart

**Checkpoint**: MVP. US1+US2 are demoable, with the number copied or confirmed on screen.

---

## Phase 5: User Story 3 — Offline save and duplicates (P2)

**Goal**: Confirm → persisted `pending` record; per-device duplicate warning.
**Independent test**: offline, save 2 records and a duplicate; restart; the records persist.

- [X] T030 [P] [US3] Create models in lib/data/models.dart: Capture {id UUIDv4, imageJpeg Blob ≤1280px q80, rotationDegrees, rawText, createdAt UTC ISO-8601}; RegistrationRecord {id, number, format long|short, applicationDate? (long only), captureId?, entryMethod auto|edited|manual, duplicateOverride bool, syncStatus pending|synced, confirmedAt, syncedAt?}
- [X] T031 [P] [US3] Define the SubmissionRepository interface in lib/data/submission_repository.dart (from contracts/interfaces.md)
- [X] T032 [P] [US3] Create lib/data/db_factory.dart with conditional databaseFactoryIo (path_provider app docs dir) / databaseFactoryWeb
- [X] T033 [US3] Write failing repository tests in test/data/sembast_submission_repository_test.dart using databaseFactoryMemory: save + findByNumber; watchAll newest first; updateNumber only while pending; deleteCapture
- [X] T034 [US3] Implement SembastSubmissionRepository in lib/data/sembast_submission_repository.dart
- [X] T035 [P] [US3] Implement NoopSyncService and DisabledCloudOcrFallback in lib/data/extension_points.dart (isEnabled=false)
- [X] T036 [US3] Wire saving into ReviewScreen: entryMethod auto/edited/manual; a duplicate dialog showing the earlier confirmedAt with an explicit "Save anyway" (sets duplicateOverride=true); save the Capture only on confirm, so dismissing leaves no orphans
- [X] T037 [US3] Extend test/features/review_screen_test.dart: the duplicate dialog appears and override saves with duplicateOverride=true

---

## Phase 6: User Story 4 — Live camera scan (P2)

**Goal**: point the camera → auto-lock → review screen.
**Independent test**: a fixture shown on a second screen locks in under 3 s.

- [X] T038 [US4] Implement ScanScreen in lib/features/scan/scan_screen.dart: CameraController (back camera, high preset); a loop that calls takePicture about every 800 ms while not busy → ScanPipeline.scan(tryRotations: false) → on Found stop, then navigate to Review with the frame and result
- [X] T039 [US4] Handle permission denied or no camera → fall back to the upload flow; dispose the controller on pause/resume (WidgetsBindingObserver)
- [X] T040 [US4] Add a "Scan" entry on HomeScreen (hidden when availableCameras() is empty)

---

## Phase 7: User Story 5 — History (P3)

- [X] T041 [US5] Implement HistoryScreen in lib/features/history/history_screen.dart (watchAll, newest first: number, thumbnail, confirmedAt, status chip; tap a pending record → edit number with validation)

---

## Phase 8: Polish & Cross-Cutting

- [X] T042 [P] Create the web offline service worker web/sw.js (precache web/tesseract/*, stale-while-revalidate for same-origin GETs) and register it in web/index.html
- [X] T043 [P] Add a README.md at the repo root: setup, `tool/fetch_tesseract_assets.sh`, `flutter build web --no-web-resources-cdn`, and running the tests
- [X] T044 Run `flutter analyze` and `flutter test`; fix all issues
- [ ] T045 Run the quickstart.md validation sections 1–5 and record the results
  - 2026-10-09: §1 ✅ (`flutter analyze` clean, `flutter test` 74/74). §3 partial ✅: web release build OK;
    self-hosted Tesseract.js smoke test in headless Chrome read "adalah A03C526979" in 603 ms.
    §2, §4 and §5 are pending: they need the 7 sample images and a physical Android/iOS device.

## Dependencies & Execution Order

- Setup → Foundational → US1 → US2 (MVP). US3, US4 and US5 depend on US1 (ReviewScreen) but not on
  each other. US5 needs US3's repository.
- Inside Foundational, the tests (T008, T010, T013) are written before the code (T009, T011, T014).

## Parallel Examples

- Setup: T003, T004, T005, T006, T007 together.
- Foundational: T008 ∥ T010 ∥ T012; T015 ∥ T016.
- US1: T018 ∥ T019 ∥ T020.
- US3: T030 ∥ T031 ∥ T032 ∥ T035.

## Implementation Strategy

1. MVP = Phases 1–4. Validate with quickstart sections 1–3 (without saving).
2. Add US3 (offline persistence) → demo offline.
3. Add US4 (live scan) → US5 (history) → Polish.
