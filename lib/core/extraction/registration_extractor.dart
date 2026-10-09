/// Extracts a validated BCA registration number from raw OCR text (research R9). Pure Dart.
library;

import 'package:clock/clock.dart';

import 'normalizer.dart';
import 'registration_number.dart';

enum CandidateSource { anchor, global }

sealed class ExtractionResult {
  const ExtractionResult();
}

class Found extends ExtractionResult {
  const Found(this.number, {required this.source, required this.raw});

  final RegistrationNumber number;
  final CandidateSource source;

  /// The candidate text exactly as OCR produced it (before normalization).
  final String raw;
}

class NotFound extends ExtractionResult {
  const NotFound({this.rejected = const []});

  /// Candidates that looked like a registration number but failed validation.
  final List<RejectedCandidate> rejected;
}

class RejectedCandidate {
  const RejectedCandidate(this.raw, this.normalized, this.reason);

  final String raw;
  final String normalized;
  final InvalidReason reason;
}

class RegistrationExtractor {
  RegistrationExtractor({Clock? clock, this.windowDays = defaultWindowDays}) : _clock = clock ?? const Clock();

  final Clock _clock;
  final int windowDays;

  static final RegExp _anchor = RegExp(r'adalah|nomor\s*registrasi', caseSensitive: false);

  /// How far after an anchor we look for the start of the number.
  static const int _anchorWindow = 40;

  ExtractionResult extract(String ocrText) {
    final text = normalizeText(ocrText);
    final today = _clock.now();
    final rejected = <String, RejectedCandidate>{};

    Found? tryAt(int start, CandidateSource source) {
      final raw = _collect(text, start);
      if (raw == null) return null;
      final normalized = normalizeCandidate(raw);
      if (!normalized.startsWith('A03')) return null;
      final result = RegistrationNumber.tryParse(normalized, today: today, windowDays: windowDays);
      if (result.isValid) return Found(result.number!, source: source, raw: raw);
      rejected.putIfAbsent(normalized, () => RejectedCandidate(raw, normalized, result.reason!));
      return null;
    }

    // 1. Anchor pass: prefer the candidate right after "adalah" / "Nomor Registrasi".
    for (final m in _anchor.allMatches(text)) {
      final end = (m.end + _anchorWindow).clamp(0, text.length);
      for (var i = m.end; i < end; i++) {
        if (_isStart(text, i)) {
          final found = tryAt(i, CandidateSource.anchor);
          if (found != null) return found;
        }
      }
    }

    // 2. Global pass: first valid candidate anywhere.
    for (var i = 0; i < text.length; i++) {
      if (_isStart(text, i)) {
        final found = tryAt(i, CandidateSource.global);
        if (found != null) return found;
      }
    }

    return NotFound(rejected: rejected.values.toList());
  }

  static bool _isStart(String text, int i) =>
      isStartChar(text[i]) && (i == 0 || !isCandidateChar(text[i - 1]));

  /// Collects whitespace-separated chunks starting at [start] until their concatenation reaches
  /// the expected length for its format. Returns the raw text (with internal whitespace), or null
  /// when the chunks overshoot (the number is glued to something else) or run out.
  /// Overshoot is returned as the full raw text so validation records it as rejected.
  static String? _collect(String text, int start) {
    final raw = StringBuffer();
    final compact = StringBuffer();
    var i = start;
    while (i < text.length) {
      // Read one chunk.
      final chunkStart = i;
      while (i < text.length && isCandidateChar(text[i])) {
        i++;
      }
      if (i == chunkStart) break;
      final chunk = text.substring(chunkStart, i);
      if (raw.isNotEmpty) raw.write(' ');
      raw.write(chunk);
      compact.write(chunk);

      if (compact.length >= 4) {
        final required = expectedLength(normalizeCandidate(compact.toString())[3]);
        if (compact.length >= required) return raw.toString();
      }
      // Continue only across whitespace; any other character ends the candidate.
      if (i >= text.length || (text[i] != ' ' && text[i] != '\n')) break;
      while (i < text.length && (text[i] == ' ' || text[i] == '\n')) {
        i++;
      }
    }
    return raw.isEmpty ? null : raw.toString();
  }
}
