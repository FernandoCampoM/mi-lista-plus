// ── NUEVO: pruebas del Lote B (notificaciones y código de emparejamiento) ─
// Propósito: verificar el aviso diario de vencidos y el formato del código.
// Depende de: FollowUpNotificationService y EncryptedBackupService (estáticos).
// No modifica: pruebas existentes.
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/core/services/encrypted_backup_service.dart';
import 'package:mi_lista_plus/core/services/follow_up_notification_service.dart';

void main() {
  group('aviso de seguimientos vencidos', () {
    final today = DateTime(2026, 9, 29);

    test('se muestra si nunca se avisó', () {
      expect(
        FollowUpNotificationService.dueNoticeDecision(
          stored: null,
          today: today,
          dueIds: ['a'],
        ),
        isTrue,
      );
    });

    test('no se repite el mismo día con los mismos vencidos', () {
      final stored = FollowUpNotificationService.encodeDueNotice(today, ['a', 'b']);
      expect(
        FollowUpNotificationService.dueNoticeDecision(
          stored: stored,
          today: today,
          dueIds: ['b', 'a'],
        ),
        isFalse,
      );
      // Completar uno no vuelve a notificar.
      expect(
        FollowUpNotificationService.dueNoticeDecision(
          stored: stored,
          today: today,
          dueIds: ['a'],
        ),
        isFalse,
      );
    });

    test('se muestra si aparece un vencido nuevo', () {
      final stored = FollowUpNotificationService.encodeDueNotice(today, ['a']);
      expect(
        FollowUpNotificationService.dueNoticeDecision(
          stored: stored,
          today: today,
          dueIds: ['a', 'c'],
        ),
        isTrue,
      );
    });

    test('se muestra de nuevo al día siguiente', () {
      final stored = FollowUpNotificationService.encodeDueNotice(today, ['a']);
      expect(
        FollowUpNotificationService.dueNoticeDecision(
          stored: stored,
          today: today.add(const Duration(days: 1)),
          dueIds: ['a'],
        ),
        isTrue,
      );
    });

    test('un valor guardado dañado no bloquea el aviso', () {
      expect(
        FollowUpNotificationService.dueNoticeDecision(
          stored: 'no-json',
          today: today,
          dueIds: ['a'],
        ),
        isTrue,
      );
    });
  });

  group('código de emparejamiento', () {
    test('el código generado es válido y tiene formato XXXX-XXXX-XX', () {
      for (var i = 0; i < 50; i++) {
        final code = EncryptedBackupService.generatePairingCode();
        expect(code, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{2}$')));
        expect(EncryptedBackupService.isValidPairingCode(code), isTrue);
      }
    });

    test('acepta minúsculas, espacios y sin guiones', () {
      const code = 'K7PX-M3QD-9R';
      expect(
        EncryptedBackupService.transferPassword(' k7px m3qd 9r '),
        EncryptedBackupService.transferPassword(code),
      );
    });

    test('sigue aceptando códigos antiguos de 6 dígitos', () {
      expect(
        EncryptedBackupService.transferPassword('123456'),
        'MLP-SYNC-123456',
      );
    });

    test('rechaza códigos incompletos o con letras ambiguas', () {
      expect(EncryptedBackupService.isValidPairingCode('12345'), isFalse);
      expect(EncryptedBackupService.isValidPairingCode('K7PX-M3QD-9'), isFalse);
      expect(EncryptedBackupService.isValidPairingCode('O0IL-M3QD-9R'), isFalse);
      expect(
        () => EncryptedBackupService.transferPassword('abc'),
        throwsArgumentError,
      );
    });
  });
}
