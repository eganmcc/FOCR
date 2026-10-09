import 'dart:typed_data';

import '../extraction/registration_extractor.dart';
import '../image/image_ops.dart';
import 'ocr_engine.dart';

class ScanResult {
  const ScanResult({
    required this.extraction,
    required this.rotationDegrees,
    required this.rawText,
    required this.elapsed,
    required this.image,
    required this.ocrPasses,
  });

  final ExtractionResult extraction;

  /// Clockwise rotation that produced [extraction] (or the last one tried when not found).
  final int rotationDegrees;

  /// OCR text of the matching (or best) pass. Stays on the device (FR-015).
  final String rawText;
  final Duration elapsed;

  /// The image upright according to [rotationDegrees], EXIF applied, longest side ≤ 2000 px.
  final Uint8List image;
  final int ocrPasses;

  bool get found => extraction is Found;
}

/// Orchestrates normalize → OCR → extract, trying each orientation until a valid number is
/// found (FR-003; constitution V: at most 4 orientations, early exit).
class ScanPipeline {
  ScanPipeline(this._ocr, this._imageOps, this._extractor);

  final OcrEngine _ocr;
  final ImageOps _imageOps;
  final RegistrationExtractor _extractor;

  static const List<int> rotations = [0, 90, 180, 270];

  /// Throws [FormatException] if [image] cannot be decoded.
  Future<ScanResult> scan(Uint8List image, {bool tryRotations = true}) async {
    final sw = Stopwatch()..start();
    final upright = await _imageOps.normalize(image);
    var passes = 0;

    _Pass? best;
    for (final degrees in tryRotations ? rotations : const [0]) {
      final oriented = degrees == 0 ? upright : await _imageOps.rotate(upright, degrees);
      final text = await _ocr.recognize(oriented);
      passes++;
      final pass = _Pass(degrees, oriented, text, _extractor.extract(text));
      if (pass.extraction is Found) return pass.toResult(sw.elapsed, passes);
      if (best == null || pass.score > best.score) best = pass;
    }

    // Engines with a sparse layout mode (Tesseract) get one more try on the most readable
    // orientation; photographed screens often defeat block segmentation.
    if (_ocr.supportsSparseLayout && best != null) {
      final text = await _ocr.recognize(best.image, layout: OcrLayout.sparse);
      passes++;
      final pass = _Pass(best.degrees, best.image, text, _extractor.extract(text));
      if (pass.extraction is Found) return pass.toResult(sw.elapsed, passes);
    }

    return best!.toResult(sw.elapsed, passes);
  }
}

class _Pass {
  _Pass(this.degrees, this.image, this.text, this.extraction);

  final int degrees;
  final Uint8List image;
  final String text;
  final ExtractionResult extraction;

  static final RegExp _keywords =
      RegExp(r'registrasi|kartu|kredit|bca|adalah|nomor|pengajuan', caseSensitive: false);

  /// Readability heuristic: known page words weigh most, then amount of text.
  int get score => _keywords.allMatches(text).length * 1000 + text.length;

  ScanResult toResult(Duration elapsed, int passes) => ScanResult(
        extraction: extraction,
        rotationDegrees: degrees,
        rawText: text,
        elapsed: elapsed,
        image: image,
        ocrPasses: passes,
      );
}
