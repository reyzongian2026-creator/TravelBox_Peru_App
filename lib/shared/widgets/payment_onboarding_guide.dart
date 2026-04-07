import 'package:flutter/material.dart';
import '../../core/theme/brand_tokens.dart';
import '../../core/l10n/app_localizations_fixed.dart';

enum PaymentMethodGuideType { yape, plin, qr, card, cash }

class PaymentStep {
  final int number;
  final String title;
  final String description;
  final IconData icon;

  PaymentStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class PaymentOnboardingGuide extends StatefulWidget {
  final PaymentMethodGuideType methodType;
  final VoidCallback? onDismiss;
  final bool showAsDialog;

  const PaymentOnboardingGuide({
    super.key,
    required this.methodType,
    this.onDismiss,
    this.showAsDialog = true,
  });

  @override
  State<PaymentOnboardingGuide> createState() => _PaymentOnboardingGuideState();
}

class _PaymentOnboardingGuideState extends State<PaymentOnboardingGuide>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentStep = 0;

  final Map<PaymentMethodGuideType, List<PaymentStep>> _guides = {
    PaymentMethodGuideType.yape: [
      PaymentStep(
        number: 1,
        title: 'Selecciona Yape',
        description: 'Elige Yape como metodo de pago en la pantalla anterior',
        icon: Icons.qr_code_2,
      ),
      PaymentStep(
        number: 2,
        title: 'Revisa los datos',
        description: 'Verifica monto y destinatario antes de transferir',
        icon: Icons.verified,
      ),
      PaymentStep(
        number: 3,
        title: 'Abre tu app Yape',
        description: 'Abre Yape en tu telefono y escanea el codigo QR',
        icon: Icons.phone_android,
      ),
      PaymentStep(
        number: 4,
        title: 'Confirma la transferencia',
        description: 'Verifica los datos y completa el pago en Yape',
        icon: Icons.check_circle,
      ),
      PaymentStep(
        number: 5,
        title: 'Espera confirmacion',
        description: 'Veremos tu transferencia en hasta 5 minutos',
        icon: Icons.hourglass_bottom,
      ),
    ],
    PaymentMethodGuideType.plin: [
      PaymentStep(
        number: 1,
        title: 'Selecciona Plin',
        description: 'Elige Plin como metodo de pago',
        icon: Icons.phone_android,
      ),
      PaymentStep(
        number: 2,
        title: 'Abre Plin',
        description: 'Abre la app Plin en tu telefono',
        icon: Icons.phone_android,
      ),
      PaymentStep(
        number: 3,
        title: 'Transfiere',
        description: 'Realiza una transferencia al numero que se muestra',
        icon: Icons.send,
      ),
      PaymentStep(
        number: 4,
        title: 'Confirma aqui',
        description: 'Presiona "Ya transferi" cuando completes el pago',
        icon: Icons.check_circle,
      ),
      PaymentStep(
        number: 5,
        title: 'Listo',
        description: 'Tu pago sera confirmado en breve',
        icon: Icons.done_all,
      ),
    ],
    PaymentMethodGuideType.qr: [
      PaymentStep(
        number: 1,
        title: 'Selecciona QR Wallet',
        description: 'Elige QR Wallet como metodo de pago',
        icon: Icons.wallet,
      ),
      PaymentStep(
        number: 2,
        title: 'Escanea el codigo',
        description: 'Usa tu billetera digital para escanear el codigo QR',
        icon: Icons.qr_code_scanner,
      ),
      PaymentStep(
        number: 3,
        title: 'Confirma el monto',
        description: 'Verifica que el monto sea correcto en tu billetera',
        icon: Icons.verified,
      ),
      PaymentStep(
        number: 4,
        title: 'Completa el pago',
        description: 'Autoriza la transaccion en tu app',
        icon: Icons.check_circle,
      ),
      PaymentStep(
        number: 5,
        title: 'Espera confirmacion',
        description: 'Tu pago sera procesado en pocos minutos',
        icon: Icons.hourglass_bottom,
      ),
    ],
    PaymentMethodGuideType.card: [
      PaymentStep(
        number: 1,
        title: 'Selecciona Tarjeta',
        description: 'Elige tarjeta de credito o debito como metodo de pago',
        icon: Icons.credit_card,
      ),
      PaymentStep(
        number: 2,
        title: 'Ingresa los datos',
        description:
            'Completa el numero de tarjeta, fecha de vencimiento y CVV',
        icon: Icons.edit,
      ),
      PaymentStep(
        number: 3,
        title: 'Verifica tu identidad',
        description: 'Es posible que tu banco solicite autenticacion adicional',
        icon: Icons.security,
      ),
      PaymentStep(
        number: 4,
        title: 'Confirma el pago',
        description: 'Revisa los datos y confirma la transaccion',
        icon: Icons.check_circle,
      ),
      PaymentStep(
        number: 5,
        title: 'Pago procesado',
        description: 'Tu pago con tarjeta se confirma de forma inmediata',
        icon: Icons.done_all,
      ),
    ],
    PaymentMethodGuideType.cash: [
      PaymentStep(
        number: 1,
        title: 'Selecciona Efectivo',
        description: 'Elige efectivo como metodo de pago',
        icon: Icons.local_atm,
      ),
      PaymentStep(
        number: 2,
        title: 'Recibe tu codigo',
        description: 'Te daremos un codigo de pago unico',
        icon: Icons.confirmation_number,
      ),
      PaymentStep(
        number: 3,
        title: 'Visita el almacen',
        description: 'Acercate al almacen mas cercano con tu codigo',
        icon: Icons.store,
      ),
      PaymentStep(
        number: 4,
        title: 'Realiza el pago',
        description: 'Paga en efectivo presentando tu codigo',
        icon: Icons.payments,
      ),
      PaymentStep(
        number: 5,
        title: 'Confirmacion',
        description: 'Tu pago se confirmara en 1-2 dias habiles',
        icon: Icons.hourglass_bottom,
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<PaymentStep> get _steps => _guides[widget.methodType] ?? [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Como pagar con ${widget.methodType.name.toUpperCase()}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Paso ${_currentStep + 1} de ${_steps.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Steps carousel
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentStep = index);
            },
            itemCount: _steps.length,
            itemBuilder: (context, index) {
              final step = _steps[index];
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      step.icon,
                      size: 64,
                      color: TravelBoxBrand.primaryBlue,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      step.title,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _steps.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: index == _currentStep
                      ? TravelBoxBrand.primaryBlue
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Anterior'),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _currentStep == _steps.length - 1
                      ? () {
                          widget.onDismiss?.call();
                          if (mounted && widget.showAsDialog) {
                            Navigator.pop(context);
                          }
                        }
                      : () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                  child: Text(
                    _currentStep == _steps.length - 1
                        ? 'Comenzar'
                        : 'Siguiente',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
