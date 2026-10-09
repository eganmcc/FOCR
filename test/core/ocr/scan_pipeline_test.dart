import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focr/core/extraction/registration_extractor.dart';
import 'package:focr/core/image/image_ops.dart';
import 'package:focr/core/ocr/ocr_engine.dart';
import 'package:focr/core/ocr/scan_pipeline.dart';

/// Image bytes are a single byte holding the cumulative rotation / 90.
class FakeImageOps implements ImageOps {
  @override
  Future<Uint8List> normalize(Uint8List input, {int maxSide = 2000}) async => Uint8List.fromList([0]);

  @override
  Future<Uint8List> rotate(Uint8List jpeg, int degrees, {int maxSide = 2000}) async =>
      Uint8List.fromList([(jpeg[0] + degrees ~/ 90) % 4]);
}

class FakeOcr implements OcrEngine {
  FakeOcr(this.textByQuarterTurns, {this.sparse = false, this.sparseText = ''});

  final Map<int, String> textByQuarterTurns;
  final bool sparse;
  final String sparseText;
  final calls = <(int, OcrLayout)>[];

  @override
  bool get supportsSparseLayout => sparse;

  @override
  Future<String> recognize(Uint8List encodedImage, {OcrLayout layout = OcrLayout.block}) async {
    calls.add((encodedImage[0], layout));
    if (layout == OcrLayout.sparse) return sparseText;
    return textByQuarterTurns[encodedImage[0]] ?? '';
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  final extractor = RegistrationExtractor(clock: Clock.fixed(DateTime(2026, 10, 9)));
  final input = Uint8List.fromList([42]);
  const page = 'No. registrasi aplikasi Kartu Kredit BCA Anda adalah A03C526979';

  ScanPipeline pipeline(OcrEngine ocr) => ScanPipeline(ocr, FakeImageOps(), extractor);

  test('upright match needs a single OCR pass', () async {
    final ocr = FakeOcr({0: page});
    final r = await pipeline(ocr).scan(input);
    expect(r.found, isTrue);
    expect(r.rotationDegrees, 0);
    expect(ocr.calls, hasLength(1));
  });

  test('tries 0, 90, 180, 270 in order and stops at first match', () async {
    final ocr = FakeOcr({0: 'noise', 1: 'more noise', 2: page, 3: page});
    final r = await pipeline(ocr).scan(input);
    expect((r.extraction as Found).number.value, 'A03C526979');
    expect(r.rotationDegrees, 180);
    expect(ocr.calls.map((c) => c.$1), [0, 1, 2]);
  });

  test('at most 4 OCR passes when nothing is found (no sparse support)', () async {
    final ocr = FakeOcr({});
    final r = await pipeline(ocr).scan(input);
    expect(r.found, isFalse);
    expect(ocr.calls, hasLength(4));
    expect(r.ocrPasses, 4);
  });

  test('tryRotations=false only tries upright', () async {
    final ocr = FakeOcr({1: page});
    final r = await pipeline(ocr).scan(input, tryRotations: false);
    expect(r.found, isFalse);
    expect(ocr.calls, hasLength(1));
  });

  test('sparse retry runs once on the most readable orientation', () async {
    final ocr = FakeOcr(
      {0: 'xx', 1: 'No. registrasi aplikasi Kartu Kredit BCA Anda adalah ???', 2: 'y', 3: 'z'},
      sparse: true,
      sparseText: 'adalah A03C526979',
    );
    final r = await pipeline(ocr).scan(input);
    expect(r.found, isTrue);
    expect(r.rotationDegrees, 90);
    expect(ocr.calls.last, (1, OcrLayout.sparse));
    expect(ocr.calls, hasLength(5));
  });

  test('not found reports the most readable orientation and its text', () async {
    final ocr = FakeOcr({0: 'a', 1: 'b', 2: 'Kartu Kredit BCA', 3: 'c'});
    final r = await pipeline(ocr).scan(input);
    expect(r.found, isFalse);
    expect(r.rotationDegrees, 180);
    expect(r.rawText, 'Kartu Kredit BCA');
  });
}
