import '../../domain/entities/follow_up.dart';

/// Centraliza todos los textos de seguimiento para notificaciones, modales y WhatsApp.
/// Los emojis son funcionales/neutrales; se evitan corazones y caritas romanticas.
abstract final class FollowUpMessageTemplates {
  static String message(FollowUpType type, String customerName) {
    final name = customerName.trim().isEmpty ? 'cliente' : customerName.trim();
    return switch (type) {
      FollowUpType.dayOne =>
        '👋 Hola $name, ¿ya comenzaste a usar tus productos? Cuéntame cómo vas.',
      FollowUpType.dayThree =>
        '🌿 Hola $name, ¿cómo te has sentido estos días? ¿Cómo ha sido tu experiencia con los productos?',
      FollowUpType.dayEight =>
        '✨ Hola $name, quería saber cómo vas y qué cambios has notado hasta ahora.',
      FollowUpType.periodic =>
        '📋 Hola $name, paso a hacerte seguimiento. ¿Cómo vas con tus productos?',
      FollowUpType.replenishment =>
        '📦 Hola $name, es posible que tu producto esté próximo a terminarse. ¿Cómo vas con él?',
      FollowUpType.birthday =>
        '🎂🎉 ¡Feliz cumpleaños, $name! 🥳 Que tengas un excelente día y que este nuevo año venga lleno de cosas buenas.',
    };
  }

  static String shortLabel(FollowUpType type) => switch (type) {
        FollowUpType.dayOne => '✅ Confirmación de inicio',
        FollowUpType.dayThree => '🌿 Seguimiento de bienestar',
        FollowUpType.dayEight => '⭐ Experiencia con el producto',
        FollowUpType.periodic => '📋 Seguimiento quincenal',
        FollowUpType.replenishment => '📦 Producto próximo a terminarse',
        FollowUpType.birthday => '🎂 Cumpleaños',
      };
}
