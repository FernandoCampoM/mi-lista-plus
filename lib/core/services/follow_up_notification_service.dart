import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up.dart';

class FollowUpNotificationService {
  FollowUpNotificationService({this.onTap});

  final void Function(String? payload)? onTap;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // timezone.local conserva un valor valido aun si el fabricante no lo informa.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) => onTap?.call(response.payload),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> reschedule(List<FollowUp> followUps, List<Customer> customers, {int reminderHour = 9}) async {
    await _plugin.cancelAll();
    final customersById = {for (final customer in customers) customer.id: customer};
    final now = DateTime.now();
    final pending = followUps
        .where((item) => item.status == FollowUpStatus.pending && item.dueAt.isAfter(now))
        .where((item) {
          final customer = customersById[item.customerId];
          return customer != null && !customer.isArchived && customer.followUpEnabled && customer.hasActiveConsent;
        })
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    // iOS conserva un maximo limitado de notificaciones pendientes; se agenda una ventana movil.
    for (final item in pending.take(50)) {
      final customer = customersById[item.customerId]!;
      await _plugin.zonedSchedule(
        item.id.hashCode & 0x7fffffff,
        'Seguimiento: ${customer.name}',
        _body(item.type),
        tz.TZDateTime(tz.local, item.dueAt.year, item.dueAt.month, item.dueAt.day, reminderHour),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'follow_up', 'Seguimientos',
            channelDescription: 'Recordatorios de clientes, entregas y reposicion',
            importance: Importance.high, priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: item.id,
      );
    }
  }

  String _body(FollowUpType type) => switch (type) {
        FollowUpType.dayOne => 'Confirma si ya comenzo a usar sus productos.',
        FollowUpType.dayThree => 'Pregunta como se ha sentido y registra sus notas.',
        FollowUpType.dayEight => 'Conoce como ha sido su experiencia.',
        FollowUpType.periodic => 'Es momento de retomar la conversacion.',
        FollowUpType.replenishment => 'Su producto puede estar por terminarse.',
        FollowUpType.birthday => 'Hoy es su cumpleanos. Envia una felicitacion.',
      };
}
