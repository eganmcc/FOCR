# Contracts: internal Dart interfaces

This app exposes no network API in this feature. The contracts are the interfaces that isolate
platform code (Constitution IV). Every implementation must satisfy the behavioral notes.

## OcrEngine — `lib/core/ocr/ocr_engine.dart`
```dart
abstract interface class OcrEngine {
  /// Recognizes text in an encoded image (JPEG/PNG). Must not throw for "no text"; return ''.
  Future<String> recognize(Uint8List encodedImage);
  Future<void> dispose();
}
```
- `MlKitOcrEngine` (Android/iOS): writes the bytes to a temp file and calls
  `TextRecognizer(script: latin).processImage(InputImage.fromFilePath)`. Returns `RecognizedText.text`
  (lines joined with `\n`). Deletes the temp file.
- `TesseractWebOcrEngine` (web): a lazily created single worker, using the local asset paths
  (research R2). PSM 6, then PSM 11 if the extractor finds nothing (the pipeline orchestrates this
  via `recognizeAlternate`, optional).
- It is selected via a conditional import:
  `ocr_engine_factory.dart` → `_io.dart` | `_web.dart`.

## ImageOps — `lib/core/image/image_ops.dart`
```dart
abstract interface class ImageOps {
  /// Decode, apply EXIF orientation, downscale to maxSide, encode JPEG.
  Future<Uint8List> normalize(Uint8List input, {int maxSide = 2000});
  Future<Uint8List> rotate(Uint8List jpeg, int degrees); // 90 | 180 | 270, clockwise
}
```
It runs via `compute`: a background isolate on mobile, inline on web.

## RegistrationExtractor — `lib/core/extraction/registration_extractor.dart`
```dart
class RegistrationExtractor {
  RegistrationExtractor({required Clock clock, int windowDays = 60});
  ExtractionResult extract(String ocrText);
}
```
Pure and deterministic for a fixed clock. No Flutter imports.

## ScanPipeline — `lib/core/ocr/scan_pipeline.dart`
```dart
class ScanPipeline {
  ScanPipeline(OcrEngine, ImageOps, RegistrationExtractor);
  /// Tries [0, 90, 180, 270] (or only [0] when tryRotations=false) and stops at the first Found.
  Future<ScanResult> scan(Uint8List image, {bool tryRotations = true});
}
```

## SubmissionRepository — `lib/data/submission_repository.dart`
```dart
abstract interface class SubmissionRepository {
  Future<String> saveCapture(CaptureDraft draft);           // returns captureId
  Future<void> deleteCapture(String captureId);
  Future<RegistrationRecord> saveRecord(RecordDraft draft); // syncStatus = pending
  Future<RegistrationRecord?> findByNumber(String number);
  Future<void> updateNumber(String recordId, String number); // pending only
  Stream<List<RegistrationRecord>> watchAll();              // newest first
  Future<Uint8List?> captureImage(String captureId);
}
```
Implementation: `SembastSubmissionRepository`, using a `DatabaseFactory` from `databaseFactoryIo` or
`databaseFactoryWeb`.

## SyncService / CloudOcrFallback — extension points (FR-016)
```dart
abstract interface class SyncService { Future<int> pushPending(); bool get isEnabled; }
abstract interface class CloudOcrFallback { Future<ExtractionResult?> tryExtract(Uint8List image); bool get isEnabled; }
```
In this feature they are `NoopSyncService` and `DisabledCloudOcrFallback`. `isEnabled == false`,
so the UI hides the related controls.
