import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/notifications/application/due_reminder_scheduler.dart';
import 'package:lapse/features/notifications/application/notification_service.dart';
import 'package:lapse/features/notifications/data/notification_prefs_store.dart';
import 'package:lapse/features/notifications/domain/notification_settings.dart';

void main() {
  int idFor(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

  group('syncSchedule', () {
    test('cancels and schedules only the delta', () async {
      final day17 = DateTime(2026, 4, 17);
      final day18 = DateTime(2026, 4, 18);
      final day19 = DateTime(2026, 4, 19);

      final cardRepo = _FakeCardRepository([day17, day18]);
      final notifications = _FakeNotificationService();
      final prefs = _FakePrefsStore(
        settings: const NotificationSettings(
          enabled: true,
          remindDueToday: true,
          remindOneDayBefore: true,
          remindOneWeekBefore: true,
          reminderHour: 9,
          reminderMinute: 0,
        ),
        scheduledIds: [idFor(day17), idFor(day19)],
      );

      final scheduler = DueReminderScheduler(
        cardRepository: cardRepo,
        notificationService: notifications,
        prefsStore: prefs,
        now: () => DateTime(2026, 4, 16, 8, 0),
      );

      await scheduler.syncSchedule();

      expect(notifications.canceledIds, [idFor(day19)]);
      expect(notifications.scheduledIds, [idFor(day18)]);
      expect(prefs.scheduledIds, [idFor(day17), idFor(day18)]);
    });

    test('disabling reminders clears existing scheduled IDs', () async {
      final day17 = DateTime(2026, 4, 17);
      final day18 = DateTime(2026, 4, 18);
      final notifications = _FakeNotificationService();
      final prefs = _FakePrefsStore(
        settings: const NotificationSettings(
          enabled: false,
          remindDueToday: true,
          remindOneDayBefore: true,
          remindOneWeekBefore: true,
          reminderHour: 9,
          reminderMinute: 0,
        ),
        scheduledIds: [idFor(day17), idFor(day18)],
      );

      final scheduler = DueReminderScheduler(
        cardRepository: _FakeCardRepository([day17, day18]),
        notificationService: notifications,
        prefsStore: prefs,
        now: () => DateTime(2026, 4, 16, 8, 0),
      );

      await scheduler.syncSchedule();

      expect(notifications.canceledIds, [idFor(day17), idFor(day18)]);
      expect(prefs.scheduledIds, isEmpty);
    });
  });
}

class _FakeCardRepository extends CardRepository {
  final List<DateTime> dueDays;

  _FakeCardRepository(this.dueDays);

  @override
  Future<List<DateTime>> getDistinctDueDates() async => dueDays;
}

class _FakeNotificationService extends NotificationService {
  final List<int> canceledIds = <int>[];
  final List<int> scheduledIds = <int>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelDueReminders(Iterable<int> ids) async {
    canceledIds.addAll(ids);
  }

  @override
  Future<void> scheduleDueReminder({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    scheduledIds.add(id);
  }
}

class _FakePrefsStore extends NotificationPrefsStore {
  NotificationSettings settings;
  List<int> scheduledIds;

  _FakePrefsStore({required this.settings, required this.scheduledIds});

  @override
  Future<NotificationSettings> load() async => settings;

  @override
  Future<List<int>> loadScheduledDueReminderIds() async => scheduledIds;

  @override
  Future<void> saveScheduledDueReminderIds(List<int> ids) async {
    scheduledIds = List<int>.from(ids);
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    this.settings = settings;
  }
}
