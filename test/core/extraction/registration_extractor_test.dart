import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focr/core/extraction/registration_extractor.dart';
import 'package:focr/core/extraction/registration_number.dart';

void main() {
  final extractor = RegistrationExtractor(clock: Clock.fixed(DateTime(2026, 10, 9)));

  group('OCR text fixtures', () {
    final files = Directory('test/fixtures/ocr_text')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('fixtures exist', () => expect(files, isNotEmpty));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      final expected = RegExp(r'^# expected: (\S+)').firstMatch(lines.first)!.group(1)!;
      final text = lines.skip(1).join('\n');
      final name = file.uri.pathSegments.last;

      test('$name → $expected', () {
        final result = extractor.extract(text);
        if (expected == 'none') {
          expect(result, isA<NotFound>());
        } else {
          expect(result, isA<Found>());
          expect((result as Found).number.value, expected);
        }
      });
    }
  });

  group('selection rules', () {
    test('anchor candidate wins over an earlier valid global candidate', () {
      const text = 'Ref lama A03C111111\nNo. registrasi aplikasi Kartu Kredit BCA Anda adalah A03C526979';
      final r = extractor.extract(text) as Found;
      expect(r.number.value, 'A03C526979');
      expect(r.source, CandidateSource.anchor);
    });

    test('falls back to global pass when no anchor', () {
      final r = extractor.extract('Nomor anda A03C509864 terima kasih') as Found;
      expect(r.number.value, 'A03C509864');
      expect(r.source, CandidateSource.global);
    });

    test('anchor is case-insensitive and tolerates colon/newline', () {
      expect((extractor.extract('NOMOR REGISTRASI:\nA03C511198') as Found).number.value, 'A03C511198');
    });

    test('invalid anchor candidate falls back to a valid global one', () {
      const text = 'adalah A03C52 (terpotong)\nA03C526979';
      expect((extractor.extract(text) as Found).number.value, 'A03C526979');
    });

    test('start must be at a word boundary', () {
      // "x4O3C509864" is inside a larger token, so it is not a candidate.
      expect(extractor.extract('kode x4O3C509864'), isA<NotFound>());
    });

    test('number glued to a longer token is rejected, not truncated', () {
      expect(extractor.extract('A03C5269790'), isA<NotFound>());
    });

    test('trailing punctuation ends the candidate', () {
      expect((extractor.extract('adalah A03C526979, simpan.') as Found).number.value, 'A03C526979');
    });

    test('NotFound reports rejected candidates with reasons', () {
      final r = extractor.extract('adalah A031512202600001') as NotFound;
      expect(r.rejected, hasLength(1));
      expect(r.rejected.single.normalized, 'A031512202600001');
      expect(r.rejected.single.reason, InvalidReason.futureDate);
    });

    test('empty text', () {
      expect(extractor.extract(''), isA<NotFound>());
    });

    test('uses injected clock for date window', () {
      final later = RegistrationExtractor(clock: Clock.fixed(DateTime(2027, 1, 1)));
      expect(later.extract('adalah A030510202600701'), isA<NotFound>());
    });
  });
}
