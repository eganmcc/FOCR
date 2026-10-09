import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focr/core/extraction/registration_extractor.dart';
import 'package:focr/core/extraction/registration_number.dart';
import 'package:focr/core/image/image_ops.dart';
import 'package:focr/core/ocr/ocr_engine.dart';
import 'package:focr/core/ocr/scan_pipeline.dart';
import 'package:focr/data/models.dart';
import 'package:focr/data/sembast_submission_repository.dart';
import 'package:focr/features/review/review_screen.dart';
import 'package:focr/providers.dart';
import 'package:image/image.dart' as img;
import 'package:sembast/sembast_memory.dart' show Database, newDatabaseFactoryMemory;

final _png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

class _PngImageOps implements ImageOps {
  @override
  Future<Uint8List> normalize(Uint8List input, {int maxSide = 2000}) async => _png;

  @override
  Future<Uint8List> rotate(Uint8List jpeg, int degrees, {int maxSide = 2000}) async => _png;
}

class _TextOcr implements OcrEngine {
  _TextOcr(this.text);

  final String text;

  @override
  bool get supportsSparseLayout => false;

  @override
  Future<String> recognize(Uint8List encodedImage, {OcrLayout layout = OcrLayout.block}) async => text;

  @override
  Future<void> dispose() async {}
}

void main() {
  final clock = Clock.fixed(DateTime(2026, 10, 9, 10));
  late Database db;
  late SembastSubmissionRepository repo;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('t.db');
    repo = SembastSubmissionRepository(db, clock: clock);
  });

  tearDown(() => db.close());

  Future<void> pumpReview(WidgetTester tester, {String? ocrText}) async {
    final extractor = RegistrationExtractor(clock: clock);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          repositoryProvider.overrideWithValue(repo),
          imageOpsProvider.overrideWithValue(_PngImageOps()),
          scanPipelineProvider.overrideWithValue(
            ScanPipeline(_TextOcr(ocrText ?? ''), _PngImageOps(), extractor),
          ),
        ],
        child: MaterialApp(home: ReviewScreen(sourceImage: ocrText == null ? null : _png)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lets real async work (sembast) finish between frames, then settles animations.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Finder field() => find.byKey(const Key('registrationField'));
  FilledButton confirmButton(WidgetTester t) =>
      t.widget<FilledButton>(find.ancestor(of: find.text('Confirm & save'), matching: find.bySubtype<FilledButton>()));

  Future<List<RegistrationRecord>> records() => repo.watchAll().first;

  testWidgets('pre-fills the extracted number and saves as auto', (tester) async {
    await pumpReview(tester, ocrText: 'Anda adalah A03C526979');
    expect(tester.widget<TextField>(field()).controller!.text, 'A03C526979');
    expect(confirmButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('confirm')));
    await settle(tester);

    final saved = await tester.runAsync(records);
    expect(saved!.single.number, 'A03C526979');
    expect(saved.single.entryMethod, EntryMethod.auto);
    expect(saved.single.syncStatus, SyncStatus.pending);
    expect(saved.single.captureId, isNotNull);
  });

  testWidgets('editing to an invalid value shows the reason and disables confirm', (tester) async {
    await pumpReview(tester, ocrText: 'Anda adalah A03C526979');
    await tester.enterText(field(), 'A03C5269');
    await tester.pump();
    expect(find.text(describeInvalidReason(InvalidReason.badFormat)), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(field(), 'A031512202600001'); // future date
    await tester.pump();
    expect(find.text(describeInvalidReason(InvalidReason.futureDate)), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('not found leaves the field empty with a manual-entry hint', (tester) async {
    await pumpReview(tester, ocrText: 'Pengajuan Berhasil');
    expect(find.textContaining('No valid registration number found'), findsOneWidget);
    expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('edited OCR value is saved as edited', (tester) async {
    await pumpReview(tester, ocrText: 'Anda adalah A03C526979');
    await tester.enterText(field(), 'a03c 511198');
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm')));
    await settle(tester);

    final saved = await tester.runAsync(records);
    expect(saved!.single.number, 'A03C511198');
    expect(saved.single.entryMethod, EntryMethod.edited);
  });

  testWidgets('manual entry without an image saves as manual', (tester) async {
    await pumpReview(tester);
    await tester.enterText(field(), 'A030510202600701');
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm')));
    await settle(tester);

    final saved = await tester.runAsync(records);
    expect(saved!.single.entryMethod, EntryMethod.manual);
    expect(saved.single.captureId, isNull);
  });

  testWidgets('duplicate number asks before saving; override is recorded', (tester) async {
    await tester.runAsync(() => repo.saveRecord(RecordDraft(
          number: RegistrationNumber.tryParse('A03C526979', today: clock.now()).number!,
          captureId: null,
          entryMethod: EntryMethod.manual,
        )));
    await pumpReview(tester, ocrText: 'Anda adalah A03C526979');

    // Cancel: nothing new saved.
    await tester.tap(find.byKey(const Key('confirm')));
    await settle(tester);
    expect(find.byKey(const Key('duplicateDialog')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(records))!, hasLength(1));

    // Save anyway.
    await tester.tap(find.byKey(const Key('confirm')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('saveAnyway')));
    await settle(tester);

    final saved = (await tester.runAsync(records))!;
    expect(saved, hasLength(2));
    expect(saved.where((r) => r.duplicateOverride), hasLength(1));
  });
}
