import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../widgets/primary_button.dart';

class LegalDisclaimerScreen extends StatelessWidget {
  const LegalDisclaimerScreen({super.key});

  static const _whatsapp = '573156837054';

  Future<void> _openWhatsApp() async {
    final text = Uri.encodeComponent(
      'Hola Fernando, vengo desde Mi Lista+ y necesito soporte o quiero reportar una sugerencia.',
    );
    final uri = Uri.parse('https://wa.me/$_whatsapp?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Descargo de responsabilidad'),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: const [
                Text(
                  'Mi Lista+',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 14),
                Text(
                  'Mi Lista+ es una aplicación independiente desarrollada por Fernando Campo con el propósito de facilitar la consulta de información de productos y precios cuando no se dispone de conexión a Internet.\n\n'
                  'Esta aplicación no es un producto oficial de OMNILIFE, ni está afiliada, respaldada, patrocinada o autorizada por OMNILIFE.\n\n'
                  'El principal valor de esta aplicación es permitir la consulta de productos y precios sin necesidad de conexión a Internet, por lo que se recomienda utilizarla únicamente cuando no se tenga acceso a Internet.\n\n'
                  'Si usted cuenta con conexión a Internet, le sugerimos utilizar la aplicación oficial OMNINEGOCIO, proporcionada por OMNILIFE, ya que allí encontrará la información oficial y más actualizada.\n\n'
                  'La información presentada en esta aplicación ha sido recopilada con fines informativos y puede contener errores, omisiones o encontrarse desactualizada. Los precios, productos, presentaciones, disponibilidad y demás datos mostrados no sustituyen la información oficial publicada por OMNILIFE. Antes de realizar cualquier compra o tomar una decisión comercial, se recomienda verificar la información a través de los canales oficiales de la empresa.\n\n'
                  'Las marcas, nombres comerciales y logotipos de OMNILIFE pertenecen a sus respectivos propietarios y son utilizados únicamente con fines informativos e identificativos.\n\n'
                  'El desarrollador no garantiza la exactitud, integridad o vigencia de la información contenida en la aplicación y no será responsable por pérdidas, perjuicios o inconvenientes derivados del uso de la misma.\n\n'
                  'Si encuentras algún error en la información, tienes sugerencias para mejorar la aplicación o necesitas soporte técnico, puedes comunicarte directamente con el desarrollador:\n\n'
                  'Fernando Campo\nWhatsApp: +57 315 683 7054\n\n'
                  'Tu retroalimentación será de gran ayuda para seguir mejorando la aplicación.',
                  style: TextStyle(fontSize: 15, height: 1.45),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: PrimaryButton(
                label: 'CONTACTAR POR WHATSAPP',
                onPressed: _openWhatsApp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
