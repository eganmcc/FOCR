import 'package:flutter_test/flutter_test.dart';
import 'package:focr/core/extraction/normalizer.dart';

void main() {
  group('normalizeCandidate', () {
    test('clean values pass through', () {
      expect(normalizeCandidate('A030510202600701'), 'A030510202600701');
      expect(normalizeCandidate('A03C526979'), 'A03C526979');
    });

    test('maps look-alike letters in digit positions', () {
      expect(normalizeCandidate('AO3O51O2O26OO7O1'), 'A030510202600701');
      expect(normalizeCandidate('A03C5Z6979'), 'A03C526979');
      expect(normalizeCandidate('A03C51l198'), 'A03C511198');
      expect(normalizeCandidate('A03C5I1I98'), 'A03C511198');
      expect(normalizeCandidate('A03CS09864'), 'A03C509864');
      expect(normalizeCandidate('A032209202601B90'), 'A032209202601890');
      expect(normalizeCandidate('A03O3lO2O26OO958'), 'A030310202600958');
      expect(normalizeCandidate('A03C5|1198'), 'A03C511198');
    });

    test('removes internal whitespace', () {
      expect(normalizeCandidate('A03 0510 2026 00701'), 'A030510202600701');
      expect(normalizeCandidate('A03C 526 979'), 'A03C526979');
    });

    test('position 0 must be A (4 accepted as OCR confusion)', () {
      expect(normalizeCandidate('4030510202600701'), 'A030510202600701');
      expect(normalizeCandidate('a03C526979'), 'A03C526979');
    });

    test('position 3 C variants', () {
      expect(normalizeCandidate('A03c526979'), 'A03C526979');
      expect(normalizeCandidate('A03(526979'), 'A03C526979');
      expect(normalizeCandidate('A03G526979'), 'A03C526979');
    });

    test('does not map letters outside the confusion set', () {
      // X is not a digit look-alike: result keeps it and later fails validation.
      expect(normalizeCandidate('A03C52X979'), 'A03C52X979');
    });

    test('A and C are never mapped into digits elsewhere', () {
      // C at position 5 is not a digit look-alike; stays and fails validation.
      expect(normalizeCandidate('A03C5C6979'), 'A03C5C6979');
    });
  });

  group('normalizeText', () {
    test('converts full-width characters and unifies whitespace', () {
      expect(normalizeText('Ａ０３Ｃ５２６９７９'), 'A03C526979');
      expect(normalizeText('a b\tc'), 'a b c');
    });

    test('keeps newlines', () {
      expect(normalizeText('a\r\nb'), 'a\nb');
    });
  });
}
