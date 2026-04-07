import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapse/features/notifications/domain/notification_settings.dart';

class NotificationPrefsStore {
  static const _kEnabled = 'notifications.enabled';
  static const _kDueToday = 'notifications.due_today';
  static const _kOneDay = 'notifications.one_day';
  static const _kOneWeek = 'notifications.one_week';
  static const _kHour = 'notifications.hour';
  static const _kMinute = 'notifications.minute';
  static const _kScheduledIds = 'notifications.scheduled_ids';

  Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = const NotificationSettings.defaults();
    return NotificationSettings(
      enabled: prefs.getBool(_kEnabled) ?? defaults.enabled,
      remindDueToday: prefs.getBool(_kDueToday) ?? defaults.remindDueToday,
      remindOneDayBefore:
          prefs.getBool(_kOneDay) ?? defaults.remindOneDayBefore,
      remindOneWeekBefore:
          prefs.getBool(_kOneWeek) ?? defaults.remindOneWeekBefore,
      reminderHour: prefs.getInt(_kHour) ?? defaults.reminderHour,
      reminderMinute: prefs.getInt(_kMinute) ?? defaults.reminderMinute,
    );
  }

  Future<void> save(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, settings.enabled);
    await prefs.setBool(_kDueToday, settings.remindDueToday);
    await prefs.setBool(_kOneDay, settings.remindOneDayBefore);
    await prefs.setBool(_kOneWeek, settings.remindOneWeekBefore);
    await prefs.setInt(_kHour, settings.reminderHour);
    await prefs.setInt(_kMinute, settings.reminderMinute);
  }

  Future<List<int>> loadScheduledDueReminderIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kScheduledIds) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toList();
  }

  Future<void> saveScheduledDueReminderIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kScheduledIds,
      ids.map((id) => id.toString()).toList(),
    );
  }
}
