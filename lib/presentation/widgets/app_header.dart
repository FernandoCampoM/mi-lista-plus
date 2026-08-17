import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../screens/legal_disclaimer_screen.dart';
import '../state/app_scope.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.showBack = false,
    this.actions = const [],
    this.titleFontSize = 26,
    this.showCountrySelector = true,
    this.onOpenDataTransfer,
    super.key,
  });

  final String title;
  final bool showBack;
  final List<Widget> actions;
  final double titleFontSize;
  final bool showCountrySelector;
  final VoidCallback? onOpenDataTransfer;

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.fernandocampo.mi_lista_plus';
  static const _playStoreMarketUrl =
      'market://details?id=com.fernandocampo.mi_lista_plus';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 14,
        top: MediaQuery.paddingOf(context).top + 10,
        bottom: 14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.deepPurple, AppColors.purple],
        ),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: showBack ? () => Navigator.pop(context) : () => _openAppMenu(context),
            icon: Icon(showBack ? Icons.arrow_back : Icons.menu),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(.13),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: titleFontSize,
                  ),
            ),
          ),
          if (showCountrySelector && state.selectedCountry != null)
            PopupMenuButton<String>(
              tooltip: 'Cambiar pais',
              initialValue: state.selectedCountry!.code,
              onSelected: (countryCode) async {
                final country = state.countries.firstWhere(
                  (item) => item.code == countryCode,
                );
                final hasProducts = await state.loadCountry(country);
                if (!context.mounted) return;

                if (!hasProducts) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.errorMessage ??
                            '${country.name} no tiene productos disponibles aun.',
                      ),
                    ),
                  );
                  return;
                }

                await AppScope.adsOf(context).recordImportantAction(
                  ImportantAdAction.countryChanged,
                );
                if (!context.mounted) return;

                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              itemBuilder: (context) => state.countries
                  .map(
                    (country) => PopupMenuItem(
                      value: country.code,
                      child: Text('${country.flagEmoji} ${country.name}'),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.deepPurple.withOpacity(.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 92),
                      child: Text(
                        '${state.selectedCountry!.name} ${state.selectedCountry!.flagEmoji}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          ...actions,
        ],
      ),
    );
  }

  Future<void> _openAppMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Mi Lista+',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    final versionText = info == null
                        ? 'Versión …'
                        : 'Versión ${info.version} (${info.buildNumber})';
                    return Text(
                      versionText,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (onOpenDataTransfer != null) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 220),
                      );
                      if (!context.mounted) return;
                      await AppScope.adsOf(context).recordImportantAction(
                        ImportantAdAction.backupOpened,
                      );
                      if (context.mounted) onOpenDataTransfer!();
                    },
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Respaldo y sincronización'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _shareApplication(context);
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartir aplicación'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _openPlayStoreRating(context);
                  },
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Valorar y calificar'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await AppScope.adsOf(context)
                        .showDisclaimerInterstitialOncePerDay();
                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalDisclaimerScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Descargo de responsabilidad'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showAdvisoryDialog(context);
                  },
                  icon: const Icon(Icons.support_agent),
                  label: const Text('No estoy afiliado, quiero asesoría'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAdvisoryDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Importante'),
          content: const SingleChildScrollView(
            child: Text(
              'Si actualmente ya cuentas con un Distribuidor Independiente OMNILIFE que te asesora o atiende, te recomendamos ponerte en contacto directamente con él para realizar tus consultas, pedidos o recibir acompañamiento.\n\n'
              'Esta aplicación no pretende reemplazar la asesoría personalizada que brinda tu distribuidor.\n\n'
              'Si aún no tienes un distribuidor que te asesore, o deseas recibir orientación sobre los productos, el plan de negocio o cómo realizar un pedido, puedes presionar el botón "Contactar por WhatsApp" y con gusto recibirás atención personalizada.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CERRAR'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _openAdvisoryWhatsApp();
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('CONTACTAR POR WHATSAPP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAdvisoryWhatsApp() async {
    final text = Uri.encodeComponent(
      'Hola Fernando, vengo desde Mi Lista+ y quiero asesoría de los productos OMNILIFE Y SEYTU.',
    );
    final uri = Uri.parse('https://wa.me/573156837054?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPlayStoreRating(BuildContext context) async {
    var openedStore = false;
    try {
      openedStore = await launchUrl(
        Uri.parse(_playStoreMarketUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      openedStore = false;
    }
    if (openedStore) return;

    var openedWeb = false;
    try {
      openedWeb = await launchUrl(
        Uri.parse(_playStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      openedWeb = false;
    }
    if (!openedWeb && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Google Play en este dispositivo.'),
        ),
      );
    }
  }

  Future<void> _shareApplication(BuildContext context) async {
    try {
      await Share.share(
        'Descarga Mi Lista + desde Google Play:\n$_playStoreUrl',
        subject: 'Mi Lista +',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el menú para compartir.'),
          ),
        );
      }
    }
  }
}
