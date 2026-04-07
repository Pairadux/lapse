class NotificationSettings {
  final bool enabled;
  final bool remindDueToday;
  final bool remindOneDayBefore;
  final bool remindOneWeekBefore;
  final int reminderHour;
  final int reminderMinute;

  const NotificationSettings({
    required this.enabled,
    required this.remindDueToday,
    required this.remindOneDayBefore,
    required this.remindOneWeekBefore,
    required this.reminderHour,
    required this.reminderMinute,
  });

  const NotificationSettings.defaults()
    : enabled = false,
      remindDueToday = true,
      remindOneDayBefore = true,
      remindOneWeekBefore = true,
      reminderHour = 9,
      reminderMinute = 0;

  NotificationSettings copyWith({
    bool? enabled,
    bool? remindDueToday,
    bool? remindOneDayBefore,
    bool? remindOneWeekBefore,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      remindDueToday: remindDueToday ?? this.remindDueToday,
      remindOneDayBefore: remindOneDayBefore ?? this.remindOneDayBefore,
      remindOneWeekBefore: remindOneWeekBefore ?? this.remindOneWeekBefore,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}
