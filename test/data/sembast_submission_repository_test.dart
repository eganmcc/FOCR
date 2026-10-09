import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focr/core/extraction/registration_number.dart';
import 'package:focr/data/models.dart';
import 'package:focr/data/sembast_submission_repository.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database db;
  late DateTime now;
  late SembastSubmissionRepository repo;
  final today = DateTime(2026, 10, 9);

  RegistrationNumber num(String v) => RegistrationNumber.tryParse(v, today: today).number!;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    now = DateTime.utc(2026, 10, 9, 8);
    repo = SembastSubmissionRepository(db, clock: Clock(() => now));
  });

  tearDown(() => db.close());

  Future<RegistrationRecord> save(String v, {EntryMethod method = EntryMethod.auto}) =>
      repo.saveRecord(RecordDraft(number: num(v), captureId: null, entryMethod: method));

  test('saves a pending record and finds it by number', () async {
    final saved = await save('A030510202600701');
    expect(saved.syncStatus, SyncStatus.pending);
    expect(saved.format, RegistrationFormat.long);
    expect(saved.applicationDate, DateTime(2026, 10, 5));

    final found = await repo.findByNumber('A030510202600701');
    expect(found, isNotNull);
    expect(found!.id, saved.id);
    expect(found.applicationDate, DateTime(2026, 10, 5));
    expect(found.confirmedAt, now);
    expect(await repo.findByNumber('A03C526979'), isNull);
  });

  test('watchAll lists newest first', () async {
    await save('A03C526979');
    now = now.add(const Duration(minutes: 1));
    await save('A03C511198');
    now = now.add(const Duration(minutes: 1));
    await save('A03C509864');
    final list = await repo.watchAll().first;
    expect(list.map((r) => r.number), ['A03C509864', 'A03C511198', 'A03C526979']);
  });

  test('duplicate saves are allowed and findByNumber returns the newest', () async {
    await save('A03C526979');
    now = now.add(const Duration(hours: 1));
    final second = await repo.saveRecord(
      RecordDraft(number: num('A03C526979'), captureId: null, entryMethod: EntryMethod.auto, duplicateOverride: true),
    );
    final found = await repo.findByNumber('A03C526979');
    expect(found!.id, second.id);
    expect(found.duplicateOverride, isTrue);
  });

  test('updateNumber revalidated value, marks edited, pending only', () async {
    final saved = await save('A03C526979');
    final updated = await repo.updateNumber(saved.id, num('A030510202600701'));
    expect(updated.number, 'A030510202600701');
    expect(updated.format, RegistrationFormat.long);
    expect(updated.entryMethod, EntryMethod.edited);

    // Simulate a future sync marking it synced.
    final map = updated.toMap()..['syncStatus'] = SyncStatus.synced.name;
    await stringMapStoreFactory.store('records').record(saved.id).put(db, map);
    expect(() => repo.updateNumber(saved.id, num('A03C526979')), throwsStateError);
  });

  test('captures round-trip image bytes and can be deleted', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 255]);
    final id = await repo.saveCapture(CaptureDraft(imageJpeg: bytes, rotationDegrees: 90, rawText: 'x'));
    expect(await repo.captureImage(id), bytes);
    await repo.deleteCapture(id);
    expect(await repo.captureImage(id), isNull);
  });
}
