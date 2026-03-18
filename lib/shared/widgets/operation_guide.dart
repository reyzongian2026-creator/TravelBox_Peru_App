import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OperationGuideStep {
  const OperationGuideStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class OperationGuideQuickAction {
  const OperationGuideQuickAction({
    required this.label,
    required this.route,
  });

  final String label;
  final String route;
}

class OperationGuideData {
  const OperationGuideData({
    required this.title,
    required this.summary,
    required this.steps,
    this.warning,
    this.quickActions = const [],
  });

  final String title;
  final String summary;
  final List<OperationGuideStep> steps;
  final String? warning;
  final List<OperationGuideQuickAction> quickActions;
}

OperationGuideData? resolveOperationGuide(String currentRoute) {
  final route = currentRoute.trim().toLowerCase();

  if (route.startsWith('/operator/panel')) {
    return const OperationGuideData(
      title: 'Ruta sugerida del operador',
      summary:
          'Empieza por pagos, valida reservas activas, opera QR/PIN y solo despues cierra incidencias o seguimiento logistico.',
      steps: [
        OperationGuideStep(
          icon: Icons.point_of_sale_outlined,
          title: '1. Revisar cobros pendientes',
          description:
              'Antes de recibir equipaje, confirma pagos pendientes para que el QR y la reserva queden habilitados.',
        ),
        OperationGuideStep(
          icon: Icons.assignment_outlined,
          title: '2. Ubicar la reserva',
          description:
              'Busca por codigo o cliente, revisa sede, horario Peru y si la reserva lleva recojo, entrega o atencion directa.',
        ),
        OperationGuideStep(
          icon: Icons.qr_code_scanner_outlined,
          title: '3. Ejecutar flujo QR/PIN',
          description:
              'Escanea QR, genera ID de equipaje, registra fotos de bultos y luego genera PIN solo cuando corresponda.',
        ),
        OperationGuideStep(
          icon: Icons.route_outlined,
          title: '4. Seguir recojos o deliveries',
          description:
              'Si la reserva involucra courier, monitorea ETA, asignacion y cambios de estado desde tracking logistico.',
        ),
        OperationGuideStep(
          icon: Icons.support_agent_outlined,
          title: '5. Cerrar incidencias',
          description:
              'Si algo no cuadra, abre incidencia y deja trazabilidad antes de mover el estado manualmente.',
        ),
      ],
      warning:
          'No saltes de QR a entrega sin registrar equipaje o validar el PIN. Ese es el punto mas sensible del flujo.',
      quickActions: [
        OperationGuideQuickAction(
          label: 'Cobros en caja',
          route: '/operator/cash-payments',
        ),
        OperationGuideQuickAction(
          label: 'Reservas',
          route: '/operator/reservations',
        ),
        OperationGuideQuickAction(
          label: 'QR y PIN',
          route: '/ops/qr-handoff',
        ),
      ],
    );
  }

  if (route.startsWith('/operator/cash-payments') ||
      route.startsWith('/admin/cash-payments')) {
    return const OperationGuideData(
      title: 'Guia de cobro en caja',
      summary:
          'El objetivo es dejar el pago confirmado y la reserva lista para operar, sin aprobar montos o referencias incorrectas.',
      steps: [
        OperationGuideStep(
          icon: Icons.search_outlined,
          title: '1. Verifica la reserva correcta',
          description:
              'Confirma codigo, cliente, sede y monto esperado antes de aprobar el pago.',
        ),
        OperationGuideStep(
          icon: Icons.receipt_long_outlined,
          title: '2. Revisa evidencia o referencia',
          description:
              'Si el pago es caja, valida voucher, referencia o confirmacion fisica. Si no coincide, rechaza.',
        ),
        OperationGuideStep(
          icon: Icons.task_alt_outlined,
          title: '3. Aprueba y comprueba el estado',
          description:
              'Tras aprobar, la reserva debe reflejarse confirmada y el cliente ya debe ver su QR sin refrescos manuales.',
        ),
      ],
      warning:
          'Si apruebas un pago equivocado, habilitas una reserva que todavia no debia operar.',
    );
  }

  if (route.startsWith('/operator/reservations') ||
      route.startsWith('/admin/reservations')) {
    return const OperationGuideData(
      title: 'Guia de reservas operativas',
      summary:
          'Usa esta pantalla para ubicar la reserva, entender el caso y llevarla al modulo correcto sin saltarte validaciones.',
      steps: [
        OperationGuideStep(
          icon: Icons.filter_alt_outlined,
          title: '1. Busca y confirma el caso',
          description:
              'Ubica la reserva por codigo, sede o cliente y revisa el estado actual antes de actuar.',
        ),
        OperationGuideStep(
          icon: Icons.info_outline,
          title: '2. Decide el flujo',
          description:
              'Si el cliente llega presencialmente ve a QR/PIN. Si solicito courier, pasa a tracking o a solicitud logistica.',
        ),
        OperationGuideStep(
          icon: Icons.history_outlined,
          title: '3. Revisa trazabilidad',
          description:
              'Valida timeline, QR, ID de equipaje, PIN y estado de pago antes de mover la reserva.',
        ),
      ],
      quickActions: [
        OperationGuideQuickAction(
          label: 'Abrir QR/PIN',
          route: '/ops/qr-handoff',
        ),
        OperationGuideQuickAction(
          label: 'Ver tracking',
          route: '/operator/tracking',
        ),
      ],
    );
  }

  if (route.startsWith('/ops/qr-handoff')) {
    return const OperationGuideData(
      title: 'Guia del flujo QR y PIN',
      summary:
          'Este modulo cubre el momento mas delicado: recepcion, almacen, recojo presencial y entrega con courier.',
      steps: [
        OperationGuideStep(
          icon: Icons.qr_code_scanner_outlined,
          title: '1. Escanear y validar QR',
          description:
              'Primero identifica la reserva correcta y el idioma del cliente antes de continuar.',
        ),
        OperationGuideStep(
          icon: Icons.luggage_outlined,
          title: '2. Generar ID de equipaje',
          description:
              'Crea el bag tag y confirma cantidad de bultos para evitar mezclar maletas.',
        ),
        OperationGuideStep(
          icon: Icons.photo_camera_back_outlined,
          title: '3. Registrar ingreso con fotos',
          description:
              'Al entrar a almacen debes guardar una foto por bulto. Despues ese registro ya no se puede editar.',
        ),
        OperationGuideStep(
          icon: Icons.pin_outlined,
          title: '4. Generar o validar PIN',
          description:
              'El PIN solo se usa cuando el equipaje esta listo para entrega o recojo seguro.',
        ),
        OperationGuideStep(
          icon: Icons.verified_user_outlined,
          title: '5. Cerrar entrega segura',
          description:
              'En delivery valida identidad, equipaje, aprobacion y finalmente el PIN antes de marcar completado.',
        ),
      ],
      warning:
          'Si falta foto, identidad, aprobacion o PIN, no cierres la entrega. El sistema esta pensado para bloquear justo esos huecos.',
    );
  }

  if (route.startsWith('/operator/tracking') ||
      route.startsWith('/admin/tracking') ||
      route.startsWith('/courier/services') ||
      route.startsWith('/courier/tracking')) {
    return const OperationGuideData(
      title: 'Guia de tracking logistico',
      summary:
          'Usa tracking para seguir recojos y entregas, no para sustituir validaciones QR/PIN o incidencias.',
      steps: [
        OperationGuideStep(
          icon: Icons.route_outlined,
          title: '1. Selecciona la orden correcta',
          description:
              'Verifica sede, cliente y tipo de servicio antes de contactar al courier.',
        ),
        OperationGuideStep(
          icon: Icons.schedule_outlined,
          title: '2. Revisa ETA y estado',
          description:
              'El ETA es estimado por ruta; si hay desvio operativo, deja nota o abre incidencia.',
        ),
        OperationGuideStep(
          icon: Icons.phone_in_talk_outlined,
          title: '3. Coordina si hay desvio',
          description:
              'Si el courier se atrasa o el punto no coincide, comunica al cliente y a soporte desde el mismo flujo.',
        ),
      ],
    );
  }

  if (route.startsWith('/operator/incidents') ||
      route.startsWith('/admin/incidents') ||
      route.startsWith('/support/incidents')) {
    return const OperationGuideData(
      title: 'Guia de incidencias y soporte',
      summary:
          'Esta bandeja existe para que nada quede fuera de trazabilidad cuando el flujo normal falla.',
      steps: [
        OperationGuideStep(
          icon: Icons.visibility_outlined,
          title: '1. Entender el caso',
          description:
              'Abre la reserva, revisa tracking y contexto antes de responder o resolver.',
        ),
        OperationGuideStep(
          icon: Icons.chat_outlined,
          title: '2. Contactar al cliente',
          description:
              'Usa WhatsApp o llamada si necesitas confirmar identidad, ubicacion o una diferencia operativa.',
        ),
        OperationGuideStep(
          icon: Icons.task_alt_outlined,
          title: '3. Registrar resolucion',
          description:
              'Cierra el ticket solo cuando dejes constancia clara de la accion tomada.',
        ),
      ],
    );
  }

  return null;
}

Future<void> showOperationGuideSheet(
  BuildContext context, {
  required OperationGuideData guide,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final width = MediaQuery.of(context).size.width;
      final maxWidth = width >= 1000 ? 860.0 : width;
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(guide.summary),
                    if (guide.warning != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6E7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_outlined),
                            const SizedBox(width: 10),
                            Expanded(child: Text(guide.warning!)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ...guide.steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == guide.steps.length - 1 ? 0 : 12,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDCEAF0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFDBEEF3),
                                child: Icon(step.icon, color: const Color(0xFF14532D)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.title,
                                      style: Theme.of(context).textTheme.titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(step.description),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (guide.quickActions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: guide.quickActions
                            .map(
                              (action) => OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  if (GoRouterState.of(context).matchedLocation !=
                                      action.route) {
                                    context.go(action.route);
                                  }
                                },
                                icon: const Icon(Icons.arrow_forward_outlined),
                                label: Text(action.label),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class OperationGuideSummaryCard extends StatelessWidget {
  const OperationGuideSummaryCard({
    super.key,
    required this.guide,
    this.compact = false,
  });

  final OperationGuideData guide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visibleSteps = compact ? guide.steps.take(3).toList() : guide.steps;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  guide.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Chip(
                  label: Text('${guide.steps.length} pasos'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(guide.summary),
            const SizedBox(height: 12),
            ...visibleSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(step.icon, size: 20, color: const Color(0xFF14532D)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(step.description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (compact && guide.steps.length > visibleSteps.length)
              Text(
                'Abre la guia completa para ver el resto del flujo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => showOperationGuideSheet(
                    context,
                    guide: guide,
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Ver guia completa'),
                ),
                ...guide.quickActions.take(2).map(
                  (action) => OutlinedButton(
                    onPressed: () => context.go(action.route),
                    child: Text(action.label),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
