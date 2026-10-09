import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db_factory.dart';
import 'data/sembast_submission_repository.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase(SembastSubmissionRepository.dbName);
  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(SembastSubmissionRepository(db))],
      child: const FocrApp(),
    ),
  );
}
