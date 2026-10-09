// Runs the real OCR pipeline (ML Kit on Android/iOS) on the reference sample images (spec US2,
// SC-001). Prepare with: dart run tool/gen_fixture_images.dart
//
//   flutter test integration_test/ocr_samples_test.dart -d <device-id>
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focr/core/extraction/registration_extractor.dart';
import 'package:focr/core/image/image_ops.dart';
import 'package:focr/core/ocr/ocr_engine_factory.dart';
import 'package:focr/core/ocr/scan_pipeline.dart';
import 'package:integration_test/integration_test.dart';

import 'fixture_images.g.dart';

/// Expected values from test/fixtures/README.md.
const expected = {
  'email': 'A032209202601890',
  'upright': 'A030510202600701',
  'rotated_90': 'A030210202606071',
  'rotated_cracked': 'A030310202600958',
  'rotated_glare': 'A03C526979',
  'blurry_browser': 'A03C511198',
  'rotated': 'A03C509864',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final engine = createOcrEngine();
  final pipeline = ScanPipeline(
    engine,
    const DartImageOps(),
    // Sample dates are Sep–Oct 2026; pin "today" so the 60-day window stays valid.
    RegistrationExtractor(clock: Clock.fixed(DateTime(2026, 10, 9))),
  );

  tearDownAll(engine.dispose);

  test('fixture images are present', () {
    expect(
      fixtureImages.keys.toSet(),
      containsAll(expected.keys),
      reason: 'Put the 7 samples in test/fixtures/images/ and run: dart run tool/gen_fixture_images.dart',
    );
  });

  for (final MapEntry(key: stem, value: number) in expected.entries) {
    test('$stem → $number', () async {
      final b64 = fixtureImages[stem];
      if (b64 == null) {
        markTestSkipped('missing test/fixtures/images/$stem.*');
        return;
      }
      final result = await pipeline.scan(base64Decode(b64));
      // ignore: avoid_print
      print('$stem: ${result.elapsed.inMilliseconds} ms, rotation ${result.rotationDegrees}°, '
          'passes ${result.ocrPasses}');
      expect(result.extraction, isA<Found>(), reason: 'OCR text:\n${result.rawText}');
      expect((result.extraction as Found).number.value, number);
    }, timeout: const Timeout(Duration(seconds: 30)));
  }
}
