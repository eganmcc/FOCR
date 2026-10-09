# Quickstart & Validation: BCA Registration Number Capture

## Prerequisites
- Flutter 3.47+ (stable). Xcode with CocoaPods for iOS. Android SDK with a device or an x86_64/arm64
  emulator.
- Put the 7 sample images in `test/fixtures/images/`, using the names in `test/fixtures/README.md`.

## Setup
```sh
flutter pub get
./tool/fetch_tesseract_assets.sh   # copies the pinned Tesseract.js 7 assets into web/tesseract/ (one-time, needs network)
```

## 1. Extraction rules (all platforms, no device)
```sh
flutter analyze
flutter test
```
Expected: all tests pass, including `test/core/extraction/` for the 7 samples (text fixtures) and the
negative cases (future date, > 60 days old, invalid date, wrong prefix, partial number).
The clock is fixed at 2026-10-09.

## 2. Real images on mobile (US1, US2)
```sh
dart run tool/gen_fixture_images.dart
flutter test integration_test/ocr_samples_test.dart -d <android-device-id>
flutter test integration_test/ocr_samples_test.dart -d <ios-device-id>
```
Expected: each fixture image produces its expected number (spec, US2 table). The rotated samples
report a non-zero `rotationDegrees`.

Note: the image fixtures carry fixed application dates, so the integration test injects
`Clock` = 2026-10-09.

## 3. Web offline (SC-005)
```sh
flutter build web --release --no-web-resources-cdn
cd build/web && python3 -m http.server 8080
```
1. Open http://localhost:8080 in Chrome and upload `rotated_glare.jpg` → `A03C526979` is pre-filled.
2. In DevTools, go to Network and set Offline. Reload: the app loads.
3. Upload another fixture: it's extracted offline. Confirm and save: it appears in History as
   "pending".
4. Save the same number again: the duplicate warning appears.

## 4. Live scan (US4, mobile)
`flutter run -d <device>`, then tap **Scan**. Point the camera at a second screen showing a fixture.
Expected: it auto-locks in under 3 s and the review screen opens with the number pre-filled.

## 5. Offline persistence (US3)
Turn on airplane mode, then save 2 records. Kill the app and reopen it: both records are listed as
"pending".
