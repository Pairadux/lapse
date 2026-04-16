import 'package:lapse/features/notifications/data/notification_prefs_store.dart';
import 'package:lapse/features/notifications/application/notification_service.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/notifications/domain/notification_settings.dart';

class DueReminderScheduler {
  static const int maxScheduledReminders = 30;

  final CardRepository _cardRepository;
  final NotificationService _notificationService;
  final NotificationPrefsStore _prefsStore;
  final DateTime Function() _now;

  DueReminderScheduler({
    required CardRepository cardRepository,
    required NotificationService notificationService,
    required NotificationPrefsStore prefsStore,
    DateTime Function()? now,
  }) : _cardRepository = cardRepository,
       _notificationService = notificationService,
       _prefsStore = prefsStore,
       _now = now ?? DateTime.now;

  Future<void> rescheduleAll() async {
    await _notificationService.initialize();

    final settings = await _prefsStore.load();
    final existingIds = await _prefsStore.loadScheduledDueReminderIds();
    await _notificationService.cancelDueReminders(existingIds);
    await _prefsStore.saveScheduledDueReminderIds(const <int>[]);

    if (!settings.enabled) return;

    final plans = await _buildDesiredPlans(settings);
    if (plans.isEmpty) return;

    final scheduledIds = <int>[];
    for (final plan in plans.take(maxScheduledReminders)) {
      await _notificationService.scheduleDueReminder(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        whenLocal: plan.fireAt,
      );
      scheduledIds.add(plan.id);
    }

    await _prefsStore.saveScheduledDueReminderIds(scheduledIds);
  }

  /// Incrementally syncs scheduled reminder IDs to current due dates by
  /// canceling/scheduling only the delta.
  Future<void> syncSchedule() async {
    await _notificationService.initialize();

    final settings = await _prefsStore.load();
    final existingIds = (await _prefsStore.loadScheduledDueReminderIds())
        .toSet();

    if (!settings.enabled) {
      if (existingIds.isNotEmpty) {
        await _notificationService.cancelDueReminders(existingIds);
      }
      await _prefsStore.saveScheduledDueReminderIds(const <int>[]);
      return;
    }

    final desiredPlans = (await _buildDesiredPlans(settings))
        .take(maxScheduledReminders)
        .toList(growable: false);
    final desiredIds = desiredPlans.map((p) => p.id).toSet();

    final toCancel = existingIds.difference(desiredIds);
    if (toCancel.isNotEmpty) {
      await _notificationService.cancelDueReminders(toCancel);
    }

    final planById = <int, _ReminderPlan>{
      for (final plan in desiredPlans) plan.id: plan,
    };
    final toAdd = desiredIds.difference(existingIds);
    for (final id in toAdd) {
      final plan = planById[id];
      if (plan == null) continue;
      await _notificationService.scheduleDueReminder(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        whenLocal: plan.fireAt,
      );
    }

    await _prefsStore.saveScheduledDueReminderIds(
      desiredPlans.map((p) => p.id).toList(),
    );
  }

  Future<List<_ReminderPlan>> _buildDesiredPlans(
    NotificationSettings settings,
  ) async {
    final now = _now();
    final sortedDays = await _cardRepository.getDistinctDueDates();
    if (sortedDays.isEmpty) return const <_ReminderPlan>[];

    sortedDays.sort((a, b) => a.compareTo(b));

    final plans = <_ReminderPlan>[];
    for (final day in sortedDays) {
      final fireAt = DateTime(
        day.year,
        day.month,
        day.day,
        settings.reminderHour,
        settings.reminderMinute,
      );
      if (!fireAt.isAfter(now.add(const Duration(seconds: 5)))) continue;

      plans.add(
        _ReminderPlan(
          id: _notificationId(day),
          fireAt: fireAt,
          title: 'Cards ready to review',
          body: 'You have cards to review today.',
        ),
      );
    }
    plans.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return plans;
  }

  static int _notificationId(DateTime day) {
    return day.year * 10000 + day.month * 100 + day.day;
  }
}

class _ReminderPlan {
  final int id;
  final DateTime fireAt;
  final String title;
  final String body;

  const _ReminderPlan({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
  });
}
