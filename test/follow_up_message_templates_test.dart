import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/core/services/follow_up_message_templates.dart';
import 'package:mi_lista_plus/domain/entities/follow_up.dart';

void main() {
  test('todas las plantillas usan emojis funcionales y evitan emojis romanticos', () {
    const forbidden = ['❤️', '💕', '😍', '😘', '🥰', '💜'];
    for (final type in FollowUpType.values) {
      final message = FollowUpMessageTemplates.message(type, 'Ana');
      expect(message, contains('Ana'));
      for (final emoji in forbidden) {
        expect(message.contains(emoji), isFalse, reason: '${type.name}: $message');
      }
    }
  });

  test('las plantillas cubren todos los tipos de seguimiento', () {
    expect(FollowUpMessageTemplates.message(FollowUpType.dayOne, 'Ana'), contains('👋'));
    expect(FollowUpMessageTemplates.message(FollowUpType.dayThree, 'Ana'), contains('🌿'));
    expect(FollowUpMessageTemplates.message(FollowUpType.dayEight, 'Ana'), contains('✨'));
    expect(FollowUpMessageTemplates.message(FollowUpType.periodic, 'Ana'), contains('📋'));
    expect(FollowUpMessageTemplates.message(FollowUpType.replenishment, 'Ana'), contains('📦'));
    expect(FollowUpMessageTemplates.message(FollowUpType.birthday, 'Ana'), contains('🎂'));
  });
}
