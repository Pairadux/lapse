import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const String dueChannelId = 'due_reminders';
  static const String dueChannelName = 'Due reminders';
  static const String dueChannelDescription =
      'Reminders for cards due in 1 week, 1 day, and today.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();
    var granted = true;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final androidGranted = await android.requestNotificationsPermission();
      granted = granted && (androidGranted ?? true);
    }
    if (ios != null) {
      final iosGranted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = granted && (iosGranted ?? false);
    }
    if (macos != null) {
      final macGranted = await macos.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = granted && (macGranted ?? false);
    }
    return granted;
  }

  Future<void> cancelDueReminders(Iterable<int> ids) async {
    await initialize();
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  Future<void> scheduleDueReminder({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    await initialize();
    if (!whenLocal.isAfter(DateTime.now())) return;

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        dueChannelId,
        dueChannelName,
        channelDescription: dueChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(whenLocal, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on UnimplementedError {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] zonedSchedule unsupported on this platform.',
        );
      }
    }
  }
}
