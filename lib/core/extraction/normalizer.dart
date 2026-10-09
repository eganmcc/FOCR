/// OCR text and candidate normalization (research R9). Pure Dart.
library;

/// Look-alike characters that OCR commonly emits in place of digits.
/// Applied to digit positions only. `G→6` is deliberately absent (too many false positives).
const Map<String, String> digitConfusions = {
  'O': '0', 'o': '0', 'Q': '0', 'D': '0',
  'I': '1', 'l': '1', 'i': '1', '|': '1', '!': '1',
  'S': '5', 's': '5',
  'B': '8',
  'Z': '2', 'z': '2',
};

const Set<String> _firstCharA = {'A', 'a', '4'};
const Set<String> _shortMarkerC = {'C', 'c', '(', 'G'};

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _horizontalSpace = RegExp(r'[ \t   　]+');

/// Normalizes raw OCR text: full-width ASCII to half-width, CRLF to LF, horizontal whitespace
/// runs to a single space. Newlines are kept because they delimit OCR lines.
String normalizeText(String text) {
  final buf = StringBuffer();
  for (final rune in text.runes) {
    // Full-width forms U+FF01..U+FF5E map to ASCII 0x21..0x7E.
    buf.writeCharCode(rune >= 0xFF01 && rune <= 0xFF5E ? rune - 0xFEE0 : rune);
  }
  return buf
      .toString()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(_horizontalSpace, ' ');
}

/// Normalizes a single candidate token to the canonical registration-number alphabet.
///
/// Removes whitespace, forces position 0 to `A` (from `a`/`4`), maps position 3 to `C` when it
/// is a C look-alike, and maps digit look-alikes in every other position. Characters outside
/// the confusion map are left as-is so that validation rejects them (never guess).
String normalizeCandidate(String raw) {
  final chars = raw.replaceAll(_whitespace, '').split('');
  final out = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    final c = chars[i];
    if (i == 0) {
      out.write(_firstCharA.contains(c) ? 'A' : c);
    } else if (i == 3 && _shortMarkerC.contains(c)) {
      out.write('C');
    } else {
      out.write(digitConfusions[c] ?? c);
    }
  }
  return out.toString();
}

/// True when [c] can be part of a candidate token (alphanumerics plus OCR look-alike symbols).
bool isCandidateChar(String c) {
  final u = c.codeUnitAt(0);
  final alnum = (u >= 0x30 && u <= 0x39) || (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A);
  return alnum || c == '|' || c == '!' || c == '(';
}

/// True when [c] could be the first character of a registration number.
bool isStartChar(String c) => _firstCharA.contains(c);

/// Expected canonical length given the normalized 4th character.
int expectedLength(String normalizedFourthChar) => normalizedFourthChar == 'C' ? 10 : 16;
