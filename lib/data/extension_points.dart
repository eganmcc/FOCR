import 'dart:typed_data';

import '../core/extraction/registration_extractor.dart';

/// Pushes pending records to the backend and marks them synced (FR-016). The backend doesn't
/// exist yet; see [NoopSyncService].
abstract interface class SyncService {
  bool get isEnabled;

  /// Returns the number of records synced.
  Future<int> pushPending();
}

/// Network OCR used when on-device OCR finds nothing (FR-016). Must go through the backend;
/// no API keys in the client (constitution: Technology Constraints).
abstract interface class CloudOcrFallback {
  bool get isEnabled;
  Future<ExtractionResult?> tryExtract(Uint8List image);
}

class NoopSyncService implements SyncService {
  const NoopSyncService();

  @override
  bool get isEnabled => false;

  @override
  Future<int> pushPending() async => 0;
}

class DisabledCloudOcrFallback implements CloudOcrFallback {
  const DisabledCloudOcrFallback();

  @override
  bool get isEnabled => false;

  @override
  Future<ExtractionResult?> tryExtract(Uint8List image) async => null;
}
