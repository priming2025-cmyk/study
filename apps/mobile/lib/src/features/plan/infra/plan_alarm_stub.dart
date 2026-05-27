Future<void> planAlarmInit() async {}

Future<void> planAlarmSchedule({
  required String planItemId,
  required String subject,
  required DateTime whenLocal,
  bool fiveMinBefore = false,
}) async {}

Future<void> planAlarmCancel(String planItemId) async {}
