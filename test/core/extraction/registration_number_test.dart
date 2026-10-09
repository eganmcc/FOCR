import 'package:flutter_test/flutter_test.dart';
import 'package:focr/core/extraction/registration_number.dart';

void main() {
  final today = DateTime(2026, 10, 9);

  ValidationResult parse(String v) => RegistrationNumber.tryParse(v, today: today);

  group('format', () {
    test('accepts long format and exposes date + sequence', () {
      final r = parse('A030510202600701');
      expect(r.isValid, isTrue);
      final n = r.number!;
      expect(n.format, RegistrationFormat.long);
      expect(n.applicationDate, DateTime(2026, 10, 5));
      expect(n.sequence, '00701');
    });

    test('accepts short format without date checks', () {
      final r = parse('A03C526979');
      expect(r.isValid, isTrue);
      expect(r.number!.format, RegistrationFormat.short);
      expect(r.number!.applicationDate, isNull);
      expect(r.number!.sequence, '526979');
    });

    for (final bad in [
      '',
      'A03',
      'A0305102026007', // too short
      'A0305102026007011', // too long
      'B030510202600701', // wrong prefix
      'A03C52697', // short too short
      'A03C5269790', // short too long
      'A03X526979',
      'a030510202600701', // lowercase is not normalized here
      'A03 0510202600701',
    ]) {
      test('rejects bad format "$bad"', () {
        expect(parse(bad).reason, InvalidReason.badFormat);
      });
    }
  });

  group('date validation (long format)', () {
    test('rejects impossible date', () {
      expect(parse('A033102202600001').reason, InvalidReason.invalidDate); // 31 Feb
      expect(parse('A030013202600001').reason, InvalidReason.invalidDate); // month 13
      expect(parse('A030010202600001').reason, InvalidReason.invalidDate); // day 0
    });

    test('rejects future date', () {
      expect(parse('A031010202600001').reason, InvalidReason.futureDate);
    });

    test('accepts today', () {
      expect(parse('A030910202600001').isValid, isTrue);
    });

    test('accepts exactly 60 days ago, rejects 61', () {
      // 2026-10-09 minus 60 days = 2026-08-10
      expect(parse('A031008202600001').isValid, isTrue);
      expect(parse('A030908202600001').reason, InvalidReason.tooOld);
    });

    test('window is configurable', () {
      final r = RegistrationNumber.tryParse('A030908202600001', today: today, windowDays: 90);
      expect(r.isValid, isTrue);
    });

    test('time of day on "today" does not matter', () {
      final r = RegistrationNumber.tryParse('A030910202600001', today: DateTime(2026, 10, 9, 0, 0, 1));
      expect(r.isValid, isTrue);
    });
  });
}
