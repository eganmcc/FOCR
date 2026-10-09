import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:sembast/blob.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../core/extraction/registration_number.dart';
import 'models.dart';
import 'submission_repository.dart';

class SembastSubmissionRepository implements SubmissionRepository {
  SembastSubmissionRepository(this._db, {Clock? clock, Uuid? uuid})
      : _clock = clock ?? const Clock(),
        _uuid = uuid ?? const Uuid();

  static const String dbName = 'focr.db';

  final Database _db;
  final Clock _clock;
  final Uuid _uuid;

  final _captures = stringMapStoreFactory.store('captures');
  final _records = stringMapStoreFactory.store('records');

  static final _newestFirstOrder = [SortOrder<Object?>('confirmedAt', false)];
  static final _newestFirst = Finder(sortOrders: _newestFirstOrder);

  @override
  Future<String> saveCapture(CaptureDraft draft) async {
    final id = _uuid.v4();
    await _captures.record(id).put(_db, {
      'imageJpeg': Blob(draft.imageJpeg),
      'rotationDegrees': draft.rotationDegrees,
      'rawText': draft.rawText,
      'createdAt': _clock.now().toUtc().toIso8601String(),
    });
    return id;
  }

  @override
  Future<void> deleteCapture(String captureId) => _captures.record(captureId).delete(_db);

  @override
  Future<RegistrationRecord> saveRecord(RecordDraft draft) async {
    final record = RegistrationRecord(
      id: _uuid.v4(),
      number: draft.number.value,
      format: draft.number.format,
      applicationDate: draft.number.applicationDate,
      captureId: draft.captureId,
      entryMethod: draft.entryMethod,
      duplicateOverride: draft.duplicateOverride,
      syncStatus: SyncStatus.pending,
      confirmedAt: _clock.now().toUtc(),
    );
    await _records.record(record.id).put(_db, record.toMap());
    return record;
  }

  @override
  Future<RegistrationRecord?> findByNumber(String number) async {
    final snap = await _records.findFirst(
      _db,
      finder: Finder(filter: Filter.equals('number', number), sortOrders: _newestFirstOrder),
    );
    return snap == null ? null : RegistrationRecord.fromMap(snap.key, snap.value);
  }

  @override
  Future<RegistrationRecord> updateNumber(String recordId, RegistrationNumber number) {
    return _db.transaction((txn) async {
      final value = await _records.record(recordId).get(txn);
      if (value == null) throw StateError('Record $recordId not found');
      final current = RegistrationRecord.fromMap(recordId, value);
      if (current.syncStatus != SyncStatus.pending) {
        throw StateError('Only pending records can be edited');
      }
      final updated = current.copyWith(number: number, entryMethod: EntryMethod.edited);
      await _records.record(recordId).put(txn, updated.toMap());
      return updated;
    });
  }

  @override
  Stream<List<RegistrationRecord>> watchAll() => _records
      .query(finder: _newestFirst)
      .onSnapshots(_db)
      .map((snaps) => [for (final s in snaps) RegistrationRecord.fromMap(s.key, s.value)]);

  @override
  Future<Uint8List?> captureImage(String captureId) async {
    final value = await _captures.record(captureId).get(_db);
    return (value?['imageJpeg'] as Blob?)?.bytes;
  }
}
