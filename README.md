# FOCR: BCA Registration Number Scan

A Flutter app (Android, iOS, Web) that reads the BCA credit-card **registration number**
(`A03` + 13 digits, or `A03C` + 6 digits) from a screenshot, photo or live camera scan,
**on-device and offline**. Salespeople check the pre-filled number, then confirm it. Records are
stored locally as *pending* until the backend exists.

- Requirements and decisions: [`specs/001-registration-ocr/`](specs/001-registration-ocr/)
  (spec, plan, research, tasks). This project uses [GitHub Spec Kit](https://github.com/github/spec-kit):
  see `.specify/memory/constitution.md` and the `/speckit-*` skills in `.claude/skills/`.
- Original handoff: [`docs/bca-ocr-handoff.md`](docs/bca-ocr-handoff.md)

## How it works

| Layer | Android / iOS | Web |
|---|---|---|
| OCR | Google ML Kit Text Recognition v2 (Latin) | Tesseract.js 7, self-hosted in `web/tesseract/` |
| Storage | sembast (file) | sembast_web (IndexedDB) |
| Offline shell | native | `web/sw.js` service worker + self-hosted CanvasKit |

Pipeline (`lib/core/ocr/scan_pipeline.dart`): EXIF fix and downscale → OCR → extract. If nothing
valid is found, it retries at 90°, 180° and 270° and stops at the first valid match. On web, one
extra sparse-layout pass follows.

Extraction (`lib/core/extraction/`, pure Dart): it prefers the text after "adalah" / "Nomor
Registrasi", merges split tokens, and maps look-alikes in digit positions only (O→0, I/l→1, S→5,
B→8, Z→2). It validates the format, and for the long format checks that the embedded DDMMYYYY date
is real, not in the future, and ≤ 60 days old. It never guesses.

## Setup

```sh
flutter pub get
./tool/fetch_tesseract_assets.sh      # only needed if web/tesseract/ is missing
```

iOS needs a deployment target of 15.5+ (already set). ML Kit iOS pods don't run on Apple Silicon
simulators, so use a real device.

## Run

```sh
flutter run -d <android-or-ios-device>
flutter run -d chrome
```

Web release build, fully self-hosted:

```sh
flutter build web --release --no-web-resources-cdn
```

## Web release package (for DevOps)

```sh
./tool/build_web.sh                    # → dist/FOCR-web-<version>.tar.gz / .zip / .sha256
BASE_HREF=/focr/ ./tool/build_web.sh   # if served under a sub-path
```

The package contains `public/` (web root), `nginx/focr.conf`, a `Dockerfile` and the deploy guide
in Bahasa Indonesia ([`docs/deploy-web.id.md`](docs/deploy-web.id.md)). The site must be served
over HTTPS (camera + offline), with `.wasm` as `application/wasm` and `eng.traineddata.gz` without
`Content-Encoding`.

## Android release / QA build

Release builds are signed with the key from `android/key.properties` (git-ignored). It points at
`~/.android-keys/focr/focr-release.jks`. Without that file, the build falls back to the debug key.

```sh
# bump `version:` in pubspec.yaml first, e.g. 0.1.0+2
flutter build apk --release
```

**Keep the keystore backed up.** Installed apps can only be updated by an APK signed with the same
key.

## Test

```sh
flutter analyze
flutter test                                  # extraction rules, pipeline, storage, review screen
```

On-device OCR against the real sample images:

1. Copy the 7 samples into `test/fixtures/images/`, using the names in `test/fixtures/README.md`.
2. Run:
   ```sh
   dart run tool/gen_fixture_images.dart
   flutter test integration_test/ocr_samples_test.dart -d <device-id>
   ```

The images are embedded into a git-ignored Dart file, so they never ship inside the app.

## Not in this feature

The backend sync (`SyncService`) and cloud OCR fallback (`CloudOcrFallback`) are interfaces with
disabled implementations in `lib/data/extension_points.dart`. They'll be wired in when the backend
is specified.
