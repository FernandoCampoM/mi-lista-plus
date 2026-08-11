import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/core/services/follow_up_notification_service.dart';
import 'package:mi_lista_plus/domain/entities/follow_up.dart';
import 'package:mi_lista_plus/domain/services/follow_up_schedule.dart';

void main() {
  group('FollowUpSchedule', () {
    final delivery = DateTime(2026, 8, 9, 16, 30);

    test('calcula los seguimientos desde la fecha de entrega', () {
      final result = FollowUpSchedule.afterDelivery(delivery);

      expect(result[FollowUpType.dayOne], DateTime(2026, 8, 10, 9));
      expect(result[FollowUpType.dayThree], DateTime(2026, 8, 12, 9));
      expect(result[FollowUpType.dayEight], DateTime(2026, 8, 17, 9));
      expect(result[FollowUpType.periodic], DateTime(2026, 9, 1, 9));
    });

    test('calcula nutricion a 10 dias y belleza a 180 dias', () {
      expect(
        FollowUpSchedule.replenishment(delivery, daysPerUnit: 10, quantity: 1),
        DateTime(2026, 8, 19, 9),
      );
      expect(
        FollowUpSchedule.replenishment(delivery, daysPerUnit: 180, quantity: 1),
        DateTime(2027, 2, 5, 9),
      );
    });
  });

  test('los identificadores de notificacion son persistentes y no negativos', () {
    final first = FollowUpNotificationService.notificationId('follow-up-123');
    final second = FollowUpNotificationService.notificationId('follow-up-123');
    expect(first, second);
    expect(first, greaterThan(0));
  });

  test('lee payload versionado y conserva compatibilidad anterior', () {
    expect(
      FollowUpNotificationService.followUpIdFromPayload(
        '{"v":1,"followUpId":"abc"}',
      ),
      'abc',
    );
    expect(
      FollowUpNotificationService.followUpIdFromPayload('legacy-id'),
      'legacy-id',
    );
  });
}
