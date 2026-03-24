import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/features/study/data/review_session_summary_repository.dart';
import 'package:lapse/features/study/domain/review_session_summary.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late ReviewSessionSummaryRepository repo;

  setUp(() {
    helper = DatabaseHelper.forTesting(dbName: 'test_session_summary.db');
    repo = ReviewSessionSummaryRepository(dbHelper: helper);
  });

  tearDown(() async {
    await helper.close();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, 'test_session_summary.db'));
  });

  ReviewSessionSummary makeSummary({
    String? id,
    String date = '2026-03-14',
    int againCount = 2,
    int hardCount = 3,
    int goodCount = 10,
    int easyCount = 5,
  }) {
    final start = DateTime(2026, 3, 14, 10, 0);
    final end = DateTime(2026, 3, 14, 10, 15);
    return ReviewSessionSummary(
      id: id,
      date: date,
      startedAt: start,
      endedAt: end,
      totalReviews: againCount + hardCount + goodCount + easyCount,
      againCount: againCount,
      hardCount: hardCount,
      goodCount: goodCount,
      easyCount: easyCount,
      newCount: 5,
      learningCount: 3,
      reviewCount: 12,
      durationMs: end.difference(start).inMilliseconds,
    );
  }

  test('add + getAll round-trip', () async {
    final summary = makeSummary(id: 's1');
    await repo.add(summary);

    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.first.id, 's1');
    expect(all.first.totalReviews, 20);
    expect(all.first.date, '2026-03-14');
  });

  test('getByDate returns matching sessions only', () async {
    await repo.add(makeSummary(id: 's1', date: '2026-03-14'));
    await repo.add(makeSummary(id: 's2', date: '2026-03-15'));

    final march14 = await repo.getByDate('2026-03-14');
    expect(march14, hasLength(1));
    expect(march14.first.id, 's1');
  });

  test('getByDateRange returns inclusive range', () async {
    await repo.add(makeSummary(id: 's1', date: '2026-03-13'));
    await repo.add(makeSummary(id: 's2', date: '2026-03-14'));
    await repo.add(makeSummary(id: 's3', date: '2026-03-15'));
    await repo.add(makeSummary(id: 's4', date: '2026-03-16'));

    final range = await repo.getByDateRange('2026-03-14', '2026-03-15');
    expect(range, hasLength(2));
    expect(range.map((s) => s.id).toSet(), {'s2', 's3'});
  });

  test('getDailyStats aggregates multiple sessions per day', () async {
    await repo.add(makeSummary(
        id: 's1', date: '2026-03-14', goodCount: 10, easyCount: 5));
    await repo.add(makeSummary(
        id: 's2', date: '2026-03-14', goodCount: 8, easyCount: 2));

    final stats = await repo.getDailyStats('2026-03-14', '2026-03-14');
    expect(stats, hasLength(1));
    expect(stats.first['good_count'], 18);
    expect(stats.first['easy_count'], 7);
  });

  test('fromSession factory computes derived fields', () {
    final start = DateTime(2026, 3, 14, 9, 0);
    final end = DateTime(2026, 3, 14, 9, 20);
    final summary = ReviewSessionSummary.fromSession(
      startedAt: start,
      endedAt: end,
      againCount: 1,
      hardCount: 2,
      goodCount: 7,
      easyCount: 3,
      newCount: 4,
      learningCount: 2,
      reviewCount: 7,
    );

    expect(summary.totalReviews, 13);
    expect(summary.durationMs, 20 * 60 * 1000);
    expect(summary.date, '2026-03-14');
  });

  group('sync status', () {
    test('add sets syncStatus to pending', () async {
      await repo.add(makeSummary(id: 's1'));

      final all = await repo.getAll();
      expect(all.first.syncStatus, SyncStatus.pending);
    });

    test('getUnsynced returns pending items only', () async {
      await repo.add(makeSummary(id: 's1'));
      await repo.add(makeSummary(id: 's2'));

      final all = await repo.getAll();
      final s1 = all.firstWhere((s) => s.id == 's1');
      await repo.markSynced({s1.id: s1.updatedAt.toIso8601String()});

      final unsynced = await repo.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.id, 's2');
    });

    test('markSynced updates sync status', () async {
      await repo.add(makeSummary(id: 's1'));
      final all = await repo.getAll();
      final s1 = all.first;
      await repo.markSynced({s1.id: s1.updatedAt.toIso8601String()});

      final unsynced = await repo.getUnsynced();
      expect(unsynced, isEmpty);
    });

    test('markSynced with empty map is a no-op', () async {
      await repo.markSynced({});
    });
  });
}
