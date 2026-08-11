import '../entities/follow_up.dart';

class FollowUpSchedule {
  const FollowUpSchedule._();

  static DateTime atReminderHour(DateTime date, {int hour = 9}) =>
      DateTime(date.year, date.month, date.day, hour);

  static Map<FollowUpType, DateTime> afterDelivery(
    DateTime deliveredAt, {
    int hour = 9,
  }) => {
        FollowUpType.dayOne:
            atReminderHour(deliveredAt.add(const Duration(days: 1)), hour: hour),
        FollowUpType.dayThree:
            atReminderHour(deliveredAt.add(const Duration(days: 3)), hour: hour),
        FollowUpType.dayEight:
            atReminderHour(deliveredAt.add(const Duration(days: 8)), hour: hour),
        FollowUpType.periodic:
            atReminderHour(deliveredAt.add(const Duration(days: 23)), hour: hour),
      };

  static DateTime replenishment(
    DateTime deliveredAt, {
    required int daysPerUnit,
    required int quantity,
    int hour = 9,
  }) => atReminderHour(
        deliveredAt.add(Duration(days: daysPerUnit * quantity)),
        hour: hour,
      );

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
