import 'dart:math';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/encrypted_backup_service.dart';
import '../state/app_scope.dart';
import '../widgets/adaptive_banner_ad.dart';
import '../widgets/app_header.dart';
import 'follow_up_settings_screen.dart';

class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key});
  @override State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  final password = TextEditingController();
  final modules = <String>{'inventory', 'sales', 'clients', 'followups'};
  bool busy = false;
  bool obscurePassword = true;
  static const labels = {
    'inventory': 'Inventario', 'sales': 'Ventas', 'clients': 'Clientes',
    'followups': 'Seguimientos y notas', 'simulations': 'Simulaciones', 'config': 'Configuracion local',
  };

  @override void dispose() { password.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: Column(children: [
      const AppHeader(
        title: 'Respaldo y sincronización',
        showBack: true,
        showCountrySelector: false,
        titleFontSize: 18,
      ),
      Expanded(child: SafeArea(top: false, child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [
        const Text('Datos incluidos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const Text('Las dependencias necesarias se agregan automaticamente.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 8),
        ...labels.entries.map((entry) => CheckboxListTile(
          value: modules.contains(entry.key), title: Text(entry.value), contentPadding: EdgeInsets.zero,
          onChanged: busy ? null : (value) => setState(() => value == true ? modules.add(entry.key) : modules.remove(entry.key)),
        )),
        TextField(
          controller: password,
          obscureText: obscurePassword,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Contraseña (minimo 8 caracteres)',
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: 'Se ignorarán espacios al inicio y al final.',
            suffixIcon: IconButton(
              tooltip: obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
              icon: Icon(
                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: busy ? null : _saveBackup,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt),
          label: Text(
            busy ? 'GENERANDO RESPALDO...' : 'CREAR Y GUARDAR RESPALDO',
          ),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : _shareBackup,
          icon: const Icon(Icons.share_outlined),
          label: const Text('COMPARTIR RESPALDO'),
        ),
        OutlinedButton.icon(onPressed: busy ? null : _import, icon: const Icon(Icons.restore), label: const Text('IMPORTAR CON VISTA PREVIA')),
        OutlinedButton.icon(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const FollowUpSettingsScreen())), icon: const Icon(Icons.tune), label: const Text('CONFIGURAR SEGUIMIENTO')),
        const Divider(height: 34),
        const Text('Sincronizacion cercana manual', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const Text('Un dispositivo envia y el otro recibe. El sistema comparte un paquete cifrado por Bluetooth, Nearby Share, AirDrop o la opcion cercana disponible.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(onPressed: busy ? null : _sendNearby, icon: const Icon(Icons.send_to_mobile), label: const Text('ENVIAR DATOS')),
        OutlinedButton.icon(onPressed: busy ? null : _receiveNearby, icon: const Icon(Icons.install_mobile), label: const Text('RECIBIR DATOS')),
        if (busy) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
        const AdaptiveBannerAd(
          placement: BannerPlacement.backup,
          margin: EdgeInsets.only(top: 16, bottom: 4),
          maxHeight: 72,
        ),
      ]))),
    ]),
  );

  Future<void> _saveBackup() async {
    if (!_valid()) return;
    final secret = password.text.trim();
    setState(() => busy = true);
    try {
      final bytes = await AppScope.of(context)
          .backupService
          .generateEncryptedBytes(
          modules: modules,
          password: secret,
        );
      if (!mounted) return;
      final fileName =
          'mi_lista_plus_${DateTime.now().millisecondsSinceEpoch}.mlplus';
      final savedLocation = await FilePicker.platform.saveFile(
        dialogTitle: 'Selecciona dónde guardar el respaldo',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['mlplus'],
        bytes: bytes,
      );
      if (!mounted) return;
      if (savedLocation != null) {
        await AppScope.adsOf(context).recordImportantAction(
          ImportantAdAction.backupCreated,
        );
        if (!mounted) return;
      }
      _message(
        savedLocation == null
            ? 'No se guardó el respaldo.'
            : 'Respaldo guardado correctamente.',
      );
    } catch (error) {
      if (mounted) _message('No fue posible guardar el respaldo: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _shareBackup() async {
    if (!_valid()) return;
    final root = await getTemporaryDirectory();
    final file = File(
      p.join(
        root.path,
        'mi_lista_plus_${DateTime.now().millisecondsSinceEpoch}.mlplus',
      ),
    );
    await _run(() async {
      try {
        await AppScope.of(context).backupService.exportToFile(
          modules: modules,
          password: password.text.trim(),
          path: file.path,
        );
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Respaldo cifrado Mi Lista+',
        );
        if (mounted) {
          await AppScope.adsOf(context).recordImportantAction(
            ImportantAdAction.backupShared,
          );
        }
      } finally {
        if (await file.exists()) await file.delete();
      }
    }, 'Respaldo compartido correctamente.');
  }

  Future<void> _import() async {
    if (!_validPassword()) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    await _previewAndImport(path, password.text.trim());
  }

  Future<void> _sendNearby() async {
    if (modules.isEmpty) { _message('Selecciona al menos un modulo.'); return; }
    final code = (100000 + Random.secure().nextInt(900000)).toString();
    final root = await getTemporaryDirectory();
    final file = File(p.join(root.path, 'mi_lista_plus_sync.mlplus'));
    await _run(() async {
      try {
        await AppScope.of(context).backupService.exportToFile(
          modules: modules,
          password: EncryptedBackupService.transferPassword(code),
          path: file.path,
        );
        if (!mounted) return;
        await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
          title: const Text('Codigo de emparejamiento'),
          content: Text('$code\n\nComunica este codigo al dispositivo receptor. Solo sirve para este paquete.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CONTINUAR'))],
        ));
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Sincronizacion Mi Lista+',
        );
        if (mounted) {
          await AppScope.adsOf(context).recordImportantAction(
            ImportantAdAction.backupShared,
          );
        }
      } finally {
        if (await file.exists()) await file.delete();
      }
    }, 'Paquete enviado al selector del sistema.');
  }

  Future<void> _receiveNearby() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Recibir datos'),
      content: TextField(controller: codeController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Codigo de emparejamiento')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, codeController.text), child: const Text('SELECCIONAR ARCHIVO'))],
    ));
    Future<void>.delayed(
      const Duration(milliseconds: 400),
      codeController.dispose,
    );
    if (code == null || code.length != 6 || !mounted) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path != null && mounted) {
      await _previewAndImport(
        path,
        EncryptedBackupService.transferPassword(code),
      );
    }
  }

  Future<void> _previewAndImport(String path, String secret) async {
    setState(() => busy = true);
    try {
      final preview = await AppScope.of(context).backupService.preview(path, secret);
      if (!mounted) return;
      final mode = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Vista previa'),
        content: Text('Fecha: ${preview.exportedAt.toLocal()}\nModulos: ${preview.modules.map((item) => labels[item] ?? item).join(', ')}\nRegistros: ${preview.counts.values.fold<int>(0, (sum, value) => sum + value)}\n\nCombinar conserva lo existente. Reemplazar sustituye los modulos incluidos.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')), OutlinedButton(onPressed: () => Navigator.pop(dialogContext, 'merge'), child: const Text('COMBINAR')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, 'replace'), child: const Text('REEMPLAZAR'))],
      ));
      if (mode == null || !mounted) return;
      final counts = await AppScope.of(context).backupService.importPreview(preview, replace: mode == 'replace');
      await AppScope.of(context).reloadAfterImport();
      if (mounted) {
        await AppScope.adsOf(context).recordImportantAction(
          ImportantAdAction.backupImported,
        );
      }
      if (!mounted) return;
      _message('Importacion completada: ${counts.values.fold<int>(0, (sum, value) => sum + value)} registros.');
    } catch (error) { if (mounted) _message('$error'); } finally { if (mounted) setState(() => busy = false); }
  }

  bool _valid() => modules.isNotEmpty && _validPassword();
  bool _validPassword() { if (password.text.trim().length >= 8) return true; _message('La contraseña debe tener al menos 8 caracteres, sin contar espacios externos.'); return false; }
  Future<void> _run(Future<void> Function() action, String success) async { setState(() => busy = true); try { await action(); if (mounted) _message(success); } catch (error) { if (mounted) _message('$error'); } finally { if (mounted) setState(() => busy = false); } }
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
}
