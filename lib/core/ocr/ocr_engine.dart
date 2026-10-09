import 'dart:typed_data';

/// Page segmentation hint. Engines that have no equivalent ignore it.
enum OcrLayout {
  /// Treat the image as a block of text (default).
  block,

  /// Find as much text as possible in no particular order (Tesseract PSM 11).
  sparse,
}

/// On-device text recognizer (contracts/interfaces.md). Implementations: ML Kit (Android/iOS),
/// Tesseract.js (web).
abstract interface class OcrEngine {
  /// Recognizes text in an encoded JPEG/PNG image. Returns '' when no text is found.
  Future<String> recognize(Uint8List encodedImage, {OcrLayout layout = OcrLayout.block});

  /// Whether [OcrLayout.sparse] produces a different pass worth retrying.
  bool get supportsSparseLayout;

  Future<void> dispose();
}
