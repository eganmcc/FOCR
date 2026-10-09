import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/extraction/registration_extractor.dart';
import 'core/image/image_ops.dart';
import 'core/ocr/ocr_engine.dart';
import 'core/ocr/ocr_engine_factory.dart';
import 'core/ocr/scan_pipeline.dart';
import 'data/extension_points.dart';
import 'data/models.dart';
import 'data/submission_repository.dart';

/// Dependency wiring (research R8). Tests override any of these with fakes.

final clockProvider = Provider<Clock>((_) => const Clock());

final ocrEngineProvider = Provider<OcrEngine>((ref) {
  final engine = createOcrEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final imageOpsProvider = Provider<ImageOps>((_) => const DartImageOps());

final extractorProvider = Provider<RegistrationExtractor>(
  (ref) => RegistrationExtractor(clock: ref.watch(clockProvider)),
);

final scanPipelineProvider = Provider<ScanPipeline>(
  (ref) => ScanPipeline(ref.watch(ocrEngineProvider), ref.watch(imageOpsProvider), ref.watch(extractorProvider)),
);

/// Overridden in `main()` once the local database is open.
final repositoryProvider = Provider<SubmissionRepository>(
  (_) => throw UnimplementedError('repositoryProvider must be overridden'),
);

final recordsProvider = StreamProvider<List<RegistrationRecord>>(
  (ref) => ref.watch(repositoryProvider).watchAll(),
);

final syncServiceProvider = Provider<SyncService>((_) => const NoopSyncService());

final cloudOcrFallbackProvider = Provider<CloudOcrFallback>((_) => const DisabledCloudOcrFallback());
