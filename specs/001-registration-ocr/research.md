# Research: BCA Registration Number Capture

Versions checked on 2026-10-09 against Flutter 3.47.1 / Dart 3.13.1.

## R1. Mobile OCR engine (Android + iOS)
- **Decision**: `google_mlkit_text_recognition` ^0.17.1, Latin script, on-device. Use the same engine
  on both platforms.
- **Rationale**: Free, fully offline, and fast. ML Kit v2 handles photographed screens well. The
  project owner chose ML Kit first for both platforms. Requirements: iOS 15.5 minimum, 64-bit only,
  and armv7 excluded in the Podfile.
- **Alternatives**: Apple Vision on iOS. It's possibly more accurate on glare, has no binary size
  cost, and runs on the simulator, but needs ~100 lines of Swift. It's deferred, and can be swapped in
  behind `OcrEngine` (Constitution IV) if iOS field accuracy falls short.
- **Caveat**: ML Kit iOS pods don't run on Apple Silicon simulators. iOS integration tests need a
  device, or an x86_64/Rosetta simulator.

## R2. Web OCR engine
- **Decision**: Tesseract.js 7.0.0 called through `dart:js_interop` (+ `package:web`). The main
  script, worker, `tesseract.js-core` wasm (SIMD-LSTM build plus a non-SIMD fallback) and
  `eng.traineddata.gz` are self-hosted under `web/tesseract/`. `workerPath`, `corePath` and `langPath`
  point at local paths. One long-lived worker is created lazily and reused.
- **Rationale**: It's the only mature OCR that runs in a browser with no network. Pinning the assets
  locally satisfies Constitution I.
- **Parameters**: `tessedit_char_whitelist` is **not** used, because the anchor words ("adalah",
  "Nomor Registrasi") are needed. PSM 6 (single block) is tried first, then PSM 11 (sparse) if nothing
  is found.
- **Alternatives**: ML Kit has no web support. Running PaddleOCR or ONNX in the browser is more
  accurate but adds 10–20 MB of models and a complex pipeline. Revisit if web accuracy is a problem.

## R3. Orientation handling
- **Decision**: Decode, apply EXIF orientation, and downscale so the longest side is ≤ 2000 px.
  Run OCR at 0°. If no valid match, rotate to 90°, 180° and 270° in that order, and stop at the
  first valid match. Rotation uses `package:image` ^4.10.1 via Flutter `compute`: a background isolate
  on mobile, inline on web (no isolates there).
  On mobile, rotated images go to a temp JPEG passed to `InputImage.fromFilePath`.
- **Rationale**: Simple and deterministic, and it matches the handoff. The early exit keeps the
  common upright case to one pass.
- **Alternatives**: Using ML Kit's rotation metadata only works for raw NV21/BGRA buffers, not files.
  A word-confidence orientation heuristic is premature (YAGNI).

## R4. Live camera scan
- **Decision**: `camera` ^0.12.1. **Periodic still capture** (`takePicture` about every 800 ms while
  the previous OCR isn't busy). Each still goes through the same `ScanPipeline`, but only at 0°
  (the salesperson can tilt the phone), and the first valid match locks.
- **Rationale**: One code path on Android, iOS and Web. The plugin README warns that Android image
  streams need the legacy `camera_android` plugin to get NV21 frames, and web has no image streams.
  Stills are sharper than stream frames on glary screens.
- **Android implementation**: `camera_android` ^0.10.12 is a direct dependency, overriding the
  default `camera_android_camerax`. On 2026-10-09 CameraX crashed natively at app start on an API 34
  emulator (`Unsupported value: ProcessCameraProvider`). The ML Kit plugin also recommends the
  legacy plugin.
- **Alternatives**: `startImageStream` + `InputImage.fromBytes` gives lower latency on mobile only.
  It can be added later as an optimisation behind the same `FrameSource` abstraction.

## R5. Local persistence (semi-offline)
- **Decision**: `sembast` ^3.8.11 (IO, file in the app documents directory via `path_provider`)
  and `sembast_web` ^2.4.6 (IndexedDB). Images are stored as downscaled JPEG bytes (longest side
  ≤ 1280 px, quality 80) in a separate `captures` store, using sembast's `Blob` type. The records
  store keeps only metadata, so list views stay light.
- **Rationale**: Pure Dart, one API on all three platforms, and no wasm or native sqlite setup for
  web. The data volume is small (dozens of records a day).
- **Alternatives**: drift (sqlite) is more powerful but needs sqlite3.wasm plus worker setup on web.
  Hive or Isar have uncertain maintenance.

## R6. Web offline shell
- **Decision**: Build with `flutter build web --no-web-resources-cdn`, so CanvasKit is self-hosted
  instead of loaded from gstatic. Add a small custom `web/sw.js` registered from `index.html`: it
  precaches `web/tesseract/*` on install and serves same-origin GETs cache-first with network update
  (stale-while-revalidate). Flutter's built-in service worker is deprecated, so it isn't relied on.
- **Rationale**: This meets SC-005 after the first online load.
- **Alternatives**: Workbox via CDN would violate the no-CDN rule, and the build step adds tooling
  for little gain.

## R7. Image input
- **Decision**: `image_picker` ^1.2.4 for gallery and camera-photo on all platforms. HEIC on iOS is
  converted to JPEG by the picker. Files over 20 MB are rejected before decoding.

## R8. State management & DI
- **Decision**: `flutter_riverpod` ^3.4.3. Providers expose `OcrEngine`, `ImageRotator`,
  `SubmissionRepository`, `SyncService`, `CloudOcrFallback` and `Clock`. Tests override the
  providers with fakes.
- **Alternatives**: Plain `InheritedWidget` or get_it work, but Riverpod gives test overrides and
  async state with less code.

## R9. Extraction algorithm (pure Dart)
1. Normalize the whole text: Unicode NFKC-ish replacements (full-width → ASCII), collapse whitespace.
2. **Anchor pass**: find `adalah` or `nomor\s*registrasi\s*:?` (case-insensitive). Take the next
   ≤ 30 non-newline characters, remove spaces, and normalize a candidate starting with
   `A0 3`/`AO3`/`A03` and similar variants.
3. **Global pass**: tokenize the text into runs of `[A-Za-z0-9]` with internal spaces allowed (to
   merge splits), and keep tokens starting with something that normalizes to `A03`.
4. **Per-candidate normalization**: position 0 must be `A` (accept `4`→`A` only at position 0).
   Positions 1–2 are digits via the confusion map. Position 3 is `C` (also accept `c`, `(`, `G`→`C`)
   or a digit via the map. The rest are digits via the map (O/o/Q/D→0, I/l/i/|/!→1, S/s→5, B→8,
   Z/z→2, G→6 is **not** applied, to avoid false positives). Truncate to the format's length only when
   the next character is a non-alphanumeric boundary.
5. **Validate**: regex `^A03(?:\d{13}|C\d{6})$`. For the long format, check DDMMYYYY is a real date,
   not after `today`, and `today - date ≤ 60 days`. `Clock` is injected.
6. **Choose**: anchor-pass result first, otherwise the first valid global result, otherwise
   `NotFound`. Return the result with its source (anchor/global) for diagnostics.
- **Note**: Both handoff rules and constitution II forbid guessing, so no "best effort" partial
  matches are ever returned.

## R10. Testing strategy
- Unit tests (pure Dart, `flutter test`) cover the extractor with OCR-text fixtures: clean and
  noisy variants of each of the 7 samples, plus negative cases.
- Widget tests cover the review screen (validation, duplicate dialog) with fake providers.
- Integration tests (`integration_test/`) run the 7 image fixtures through the real `ScanPipeline`
  on an Android device/emulator and an iOS device. Web: a manual checklist in quickstart.md, since
  `integration_test` on web needs chromedriver (optional).
