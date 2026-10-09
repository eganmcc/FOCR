/// BCA credit-card registration number value type and validation rules.
///
/// Pure Dart: no Flutter or platform imports (constitution principle III).
library;

enum RegistrationFormat { long, short }

enum InvalidReason { badFormat, invalidDate, futureDate, tooOld }

/// Long: `A03` + DDMMYYYY + 5-digit sequence. Short: `A03C` + 6 digits.
final RegExp registrationPattern = RegExp(r'^A03(?:\d{13}|C\d{6})$');

const int defaultWindowDays = 60;

class RegistrationNumber {
  const RegistrationNumber._(this.value, this.format, this.applicationDate);

  final String value;
  final RegistrationFormat format;

  /// Embedded application date (long format only), as a date-only value.
  final DateTime? applicationDate;

  String get sequence => format == RegistrationFormat.long ? value.substring(11) : value.substring(4);

  /// The only way to obtain a [RegistrationNumber]. Never guesses: [value] must already be
  /// normalized; anything that fails the format or date rules is rejected with a reason.
  static ValidationResult tryParse(
    String value, {
    required DateTime today,
    int windowDays = defaultWindowDays,
  }) {
    if (!registrationPattern.hasMatch(value)) {
      return const ValidationResult.invalid(InvalidReason.badFormat);
    }
    if (value[3] == 'C') {
      return ValidationResult.valid(RegistrationNumber._(value, RegistrationFormat.short, null));
    }

    final day = int.parse(value.substring(3, 5));
    final month = int.parse(value.substring(5, 7));
    final year = int.parse(value.substring(7, 11));
    final date = DateTime.utc(year, month, day);
    // DateTime normalizes overflow (e.g. 31 Feb -> 3 Mar); a round-trip mismatch means invalid.
    if (date.year != year || date.month != month || date.day != day) {
      return const ValidationResult.invalid(InvalidReason.invalidDate);
    }

    final todayDate = DateTime.utc(today.year, today.month, today.day);
    if (date.isAfter(todayDate)) {
      return const ValidationResult.invalid(InvalidReason.futureDate);
    }
    if (todayDate.difference(date).inDays > windowDays) {
      return const ValidationResult.invalid(InvalidReason.tooOld);
    }
    return ValidationResult.valid(
      RegistrationNumber._(value, RegistrationFormat.long, DateTime(year, month, day)),
    );
  }

  @override
  bool operator ==(Object other) => other is RegistrationNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class ValidationResult {
  const ValidationResult.valid(RegistrationNumber this.number) : reason = null;
  const ValidationResult.invalid(InvalidReason this.reason) : number = null;

  final RegistrationNumber? number;
  final InvalidReason? reason;

  bool get isValid => number != null;
}

/// Human-readable message for a rejection reason (shown under the editable field).
String describeInvalidReason(InvalidReason reason, {int windowDays = defaultWindowDays}) =>
    switch (reason) {
      InvalidReason.badFormat => 'Must be A03 + 13 digits, or A03C + 6 digits',
      InvalidReason.invalidDate => 'The date inside the number (DDMMYYYY) is not a real date',
      InvalidReason.futureDate => 'The date inside the number is in the future',
      InvalidReason.tooOld => 'The date inside the number is more than $windowDays days ago',
    };
