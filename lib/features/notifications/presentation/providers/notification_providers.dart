import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/notifications/application/due_reminder_scheduler.dart';
import 'package:lapse/features/notifications/application/notification_service.dart';
import 'package:lapse/features/notifications/data/notification_prefs_store.dart';
import 'package:lapse/features/notifications/domain/notification_settings.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationPrefsStoreProvider = Provider<NotificationPrefsStore>((ref) {
  return NotificationPrefsStore();
});

final dueReminderSchedulerProvider = Provider<DueReminderScheduler>((ref) {
  return DueReminderScheduler(
    cardRepository: ref.read(cardRepositoryProvider),
    notificationService: ref.read(notificationServiceProvider),
    prefsStore: ref.read(notificationPrefsStoreProvider),
  );
});

final notificationBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(notificationServiceProvider).initialize();
  await ref.read(dueReminderSchedulerProvider).rescheduleAll();
});

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
    );

class NotificationSettingsNotifier extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    return ref.read(notificationPrefsStoreProvider).load();
  }

  Future<bool> setEnabled(bool enabled) async {
    final current = _current;
    if (enabled) {
      final granted = await ref
          .read(notificationServiceProvider)
          .requestPermissions();
      if (!granted) return false;
    }
    final next = current.copyWith(enabled: enabled);
    await _persistAndReschedule(next);
    return true;
  }

  Future<void> setReminderTime({required int hour, required int minute}) async {
    final current = _current;
    final next = current.copyWith(reminderHour: hour, reminderMinute: minute);
    await _persistAndReschedule(next);
  }

  Future<void> setRemindDueToday(bool value) async {
    final next = _current.copyWith(remindDueToday: value);
    await _persistAndReschedule(next);
  }

  Future<void> setRemindOneDayBefore(bool value) async {
    final next = _current.copyWith(remindOneDayBefore: value);
    await _persistAndReschedule(next);
  }

  Future<void> setRemindOneWeekBefore(bool value) async {
    final next = _current.copyWith(remindOneWeekBefore: value);
    await _persistAndReschedule(next);
  }

  NotificationSettings get _current {
    return state.asData?.value ?? const NotificationSettings.defaults();
  }

  Future<void> _persistAndReschedule(NotificationSettings next) async {
    await ref.read(notificationPrefsStoreProvider).save(next);
    state = AsyncData(next);
    await ref.read(dueReminderSchedulerProvider).rescheduleAll();
  }
}
