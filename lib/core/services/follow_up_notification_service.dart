import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up.dart';
import 'follow_up_message_templates.dart';

class FollowUpNotificationService {
  static const _channel = MethodChannel('mi_lista_plus/settings');
  static const _followUpChannelId = 'follow_up';
  static const _summaryId = 2147483001;
  static const _testId = 2147483002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();
  String? _launchPayload;
  bool _initialized = false;

  Stream<String> get payloads => _payloadController.stream;
  bool get wasLaunchedFromNotification => _launchPayload != null;

  String? takeLaunchPayload() {
    final value = _launchPayload;
    _launchPayload = null;
    return value;
  }

  Future<void> initialize({bool requestPermission = true}) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // La operacion principal es Colombia; este fallback evita usar UTC.
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _payloadController.add(payload);
        }
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launchPayload = launch?.notificationResponse?.payload;
    }
    _initialized = true;
    if (requestPermission) await requestPermissions();
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidResult = await android?.requestNotificationsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosResult = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidResult ?? iosResult ?? true;
  }

  Future<bool> notificationsAllowed() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    return true;
  }

  Future<int> pendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.where((item) => _isFollowUpPayload(item.payload)).length;
  }

  Future<String> manufacturer() async {
    if (kIsWeb) return '';
    try {
      return (await _channel.invokeMethod<String>('manufacturer') ?? '')
          .toLowerCase();
    } catch (_) {
      return '';
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {
      await requestPermissions();
    }
  }

  Future<void> sendTestNotification() => _plugin.show(
        _testId,
        'Notificaciones activas',
        'Mi Lista + puede enviarte recordatorios de seguimiento.',
        _details,
        payload: jsonEncode({'v': 1, 'kind': 'test'}),
      );

  Future<void> reschedule(
    List<FollowUp> followUps,
    List<Customer> customers, {
    int reminderHour = 9,
  }) async {
    if (!_initialized || !await notificationsAllowed()) return;
    await _cancelFollowUpNotificationsOnly();
    final customersById = {for (final customer in customers) customer.id: customer};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eligible = followUps.where((item) {
      final customer = customersById[item.customerId];
      return item.status == FollowUpStatus.pending &&
          customer != null &&
          !customer.isArchived &&
          customer.followUpEnabled &&
          customer.hasActiveConsent;
    }).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final usedIds = <int>{_summaryId, _testId};
    final assignedIds = <String, int>{};
    for (final item in eligible) {
      var candidate = notificationId(item.id);
      while (usedIds.contains(candidate)) {
        candidate = candidate == 0x7fffffff ? 1 : candidate + 1;
      }
      usedIds.add(candidate);
      assignedIds[item.id] = candidate;
    }

    final dueNow = eligible.where((item) {
      final date = DateTime(item.dueAt.year, item.dueAt.month, item.dueAt.day);
      final scheduled = DateTime(
        item.dueAt.year,
        item.dueAt.month,
        item.dueAt.day,
        reminderHour,
      );
      return date.isBefore(today) || (date == today && !scheduled.isAfter(now));
    }).toList();
    if (dueNow.isNotEmpty) {
      final first = dueNow.first;
      await _plugin.show(
        dueNow.length == 1 ? assignedIds[first.id]! : _summaryId,
        dueNow.length == 1
            ? 'Seguimiento: ${customersById[first.customerId]!.name}'
            : '${dueNow.length} seguimientos pendientes',
        dueNow.length == 1
            ? FollowUpMessageTemplates.message(
                first.type,
                customersById[first.customerId]!.name,
              )
            : '📋 Abre Mi Lista + para revisar vencidos y pendientes de hoy.',
        _details,
        payload: _payload(first.id, summary: dueNow.length > 1),
      );
    }

    final future = eligible.where((item) {
      final scheduled = DateTime(
        item.dueAt.year,
        item.dueAt.month,
        item.dueAt.day,
        reminderHour,
      );
      return scheduled.isAfter(now);
    });
    // iOS conserva una cantidad limitada; dejamos espacio para avisos del sistema.
    for (final item in future.take(50)) {
      final customer = customersById[item.customerId]!;
      await _plugin.zonedSchedule(
        assignedIds[item.id]!,
        'Seguimiento: ${customer.name}',
        FollowUpMessageTemplates.message(item.type, customer.name),
        tz.TZDateTime(
          tz.local,
          item.dueAt.year,
          item.dueAt.month,
          item.dueAt.day,
          reminderHour,
        ),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: _payload(item.id),
      );
    }
  }

  Future<void> _cancelFollowUpNotificationsOnly() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final item in pending.where((entry) => _isFollowUpPayload(entry.payload))) {
      await _plugin.cancel(item.id);
    }
    await _plugin.cancel(_summaryId);
  }

  static bool _isFollowUpPayload(String? payload) {
    if (payload == null) return false;
    try {
      final value = jsonDecode(payload);
      return value is Map && value['v'] == 1 && value['followUpId'] != null;
    } catch (_) {
      return false;
    }
  }

  static String? followUpIdFromPayload(String payload) {
    try {
      final value = jsonDecode(payload);
      if (value is Map && value['v'] == 1) {
        return value['followUpId'] as String?;
      }
    } catch (_) {
      // Payloads de versiones anteriores contenian solamente el identificador.
      if (payload.isNotEmpty && !payload.startsWith('{')) return payload;
    }
    return null;
  }

  static int notificationId(String persistentId) {
    var hash = 0x811c9dc5;
    for (final unit in persistentId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static String _payload(String id, {bool summary = false}) =>
      jsonEncode({'v': 1, 'followUpId': id, if (summary) 'summary': true});

  static final _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _followUpChannelId,
      'Seguimientos',
      channelDescription: 'Recordatorios de clientes, entregas y reposicion',
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
      importance: Importance.high,
      priority: Priority.high,
      groupKey: 'mi_lista_plus_follow_ups',
    ),
    iOS: DarwinNotificationDetails(),
  );


}
