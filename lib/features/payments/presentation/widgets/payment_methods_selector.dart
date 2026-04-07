import 'package:flutter/material.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../core/l10n/app_localizations_fixed.dart';

enum PaymentMethodType { yape, plin, qr, card, cash }

class PaymentMethodCard {
  final PaymentMethodType type;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String confirmationSpeed; // "Inmediato", "<5 min", "1-2 dias"
  final String? badge; // "Recomendado", "Mas rapido", null
  final bool enabled;

  PaymentMethodCard({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.confirmationSpeed,
    this.badge,
    this.enabled = true,
  });
}

class PaymentMethodsSelector extends StatefulWidget {
  final Function(PaymentMethodType) onMethodSelected;
  final PaymentMethodType? initialSelected;
  final bool Function(PaymentMethodType)? isMethodAvailable;

  const PaymentMethodsSelector({
    super.key,
    required this.onMethodSelected,
    this.initialSelected,
    this.isMethodAvailable,
  });

  @override
  State<PaymentMethodsSelector> createState() => _PaymentMethodsSelectorState();
}

class _PaymentMethodsSelectorState extends State<PaymentMethodsSelector> {
  late PaymentMethodType _selectedMethod;

  final List<PaymentMethodCard> _methods = [
    PaymentMethodCard(
      type: PaymentMethodType.yape,
      label: 'Yape',
      description: 'Transferencia instantanea',
      icon: Icons.qr_code_2,
      color: TravelBoxBrand.yape,
      confirmationSpeed: 'Inmediato',
      badge: 'Mas rapido',
      enabled: true,
    ),
    PaymentMethodCard(
      type: PaymentMethodType.plin,
      label: 'Plin',
      description: 'Transferencia instantanea',
      icon: Icons.phone_android,
      color: TravelBoxBrand.plin,
      confirmationSpeed: '<5 min',
      badge: 'Sin comision',
      enabled: true,
    ),
    PaymentMethodCard(
      type: PaymentMethodType.qr,
      label: 'QR Wallet',
      description: 'Codigo QR de billetera',
      icon: Icons.wallet,
      color: TravelBoxBrand.cardPayment,
      confirmationSpeed: '<5 min',
      enabled: true,
    ),
    PaymentMethodCard(
      type: PaymentMethodType.card,
      label: 'Tarjeta',
      description: 'Credito o debito',
      icon: Icons.credit_card,
      color: Colors.blue,
      confirmationSpeed: 'Inmediato',
      enabled: true,
    ),
    PaymentMethodCard(
      type: PaymentMethodType.cash,
      label: 'Efectivo',
      description: 'En el almacen',
      icon: Icons.local_atm,
      color: Colors.green,
      confirmationSpeed: '1-2 dias',
      enabled: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialSelected ?? PaymentMethodType.yape;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.t('select_payment_method'),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _methods.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final method = _methods[index];
            final isSelected = _selectedMethod == method.type;
            final isAvailable =
                widget.isMethodAvailable?.call(method.type) ?? method.enabled;

            return GestureDetector(
              onTap: isAvailable
                  ? () {
                      setState(() => _selectedMethod = method.type);
                      widget.onMethodSelected(method.type);
                    }
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: isSelected
                        ? method.color
                        : theme.colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: method.color.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(method.icon, color: method.color, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method.label,
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                method.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (method.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: method.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              method.badge!,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: method.color),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.timer,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Confirmacion: ${method.confirmationSpeed}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
