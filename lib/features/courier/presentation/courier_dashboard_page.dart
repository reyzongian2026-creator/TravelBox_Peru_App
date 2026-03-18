import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell_scaffold.dart';

class CourierDashboardPage extends StatelessWidget {
  CourierDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      title: 'Panel courier',
      currentRoute: '/courier/panel',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14532D), Color(0xFF0B8B8C)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operacion courier TravelBox',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Toma un servicio disponible, confirma salida, comparte ubicacion y cierra la entrega o recojo desde tu modulo operativo.',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => context.go('/courier/services'),
                  icon: const Icon(Icons.route_outlined),
                  label: Text(context.l10n.t('ver_mis_servicios')),
                ),
                SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/ops/qr-handoff'),
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: Text(context.l10n.t('validacion_qr_y_pin')),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flujo operativo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(context.l10n.t('1_revisa_servicios_disponibles_y_toma_un')),
                  Text(context.l10n.t('2_registra_tu_vehiculo_si_aplica')),
                  Text(context.l10n.t('3_marca_salida_e_informa_eta')),
                  Text(
                    '4. Actualiza ubicacion y estado durante el trayecto.',
                  ),
                  Text(context.l10n.t('5_confirma_recojo_o_entrega_al_finalizar')),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.my_location_outlined),
              title: Text(context.l10n.t('tracking_manual_asistido')),
              subtitle: const Text(
                'Puedes usar GPS del navegador o registrar coordenadas manuales si estas probando en local.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

