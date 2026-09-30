import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

// ── NUEVO: diálogo de confirmación para acciones destructivas ───────────
// Propósito: pedir confirmación antes de borrar o archivar, con el mismo
//            estilo que ya usa sale_detail_screen.
// Depende de: showDialog de Material y AppColors.danger.
// No modifica: los diálogos existentes de otras pantallas.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'CANCELAR',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}
