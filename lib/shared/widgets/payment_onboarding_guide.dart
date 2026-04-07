import 'package:flutter/material.dart';
import '../../core/theme/brand_tokens.dart';

/// A collapsible step-by-step guide for the payment process.
///
/// Shows a "Como funciona?" header that expands/collapses to reveal
/// numbered steps with icons. The steps adapt based on the selected
/// [method] string (matching [PaymentConstants] keys).
class PaymentOnboardingGuide extends StatefulWidget {
  /// Payment method key (e.g. 'yape', 'plin', 'wallet', 'card', 'cash').
  /// Steps are customised per method when relevant.
  final String method;

  /// Whether the guide starts expanded. Defaults to `false`.
  final bool initiallyExpanded;

  const PaymentOnboardingGuide({
    super.key,
    required this.method,
    this.initiallyExpanded = false,
  });

  @override
  State<PaymentOnboardingGuide> createState() =>
      _PaymentOnboardingGuideState();
}

class _PaymentOnboardingGuideState extends State<PaymentOnboardingGuide>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _expanded ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _iconController.forward();
      } else {
        _iconController.reverse();
      }
    });
  }

  List<_StepInfo> _stepsForMethod(String method) {
    // Step 3 changes depending on the payment method.
    final String step3Label;
    final IconData step3Icon;

    switch (method) {
      case 'card':
        step3Label = 'Ingresa los datos de tu tarjeta';
        step3Icon = Icons.credit_card;
      case 'cash':
        step3Label = 'Paga en efectivo en el almacen';
        step3Icon = Icons.storefront;
      case 'plin':
        step3Label = 'Transfiere desde tu app Plin';
        step3Icon = Icons.send;
      default: // yape, wallet, qr
        step3Label = 'Escanea el QR o transfiere';
        step3Icon = Icons.qr_code_scanner;
    }

    return [
      const _StepInfo(
        number: 1,
        label: 'Selecciona tu metodo de pago',
        icon: Icons.payment,
      ),
      const _StepInfo(
        number: 2,
        label: 'Revisa los datos',
        icon: Icons.fact_check,
      ),
      _StepInfo(
        number: 3,
        label: step3Label,
        icon: step3Icon,
      ),
      const _StepInfo(
        number: 4,
        label: 'Confirma en tu app bancaria',
        icon: Icons.verified,
      ),
      const _StepInfo(
        number: 5,
        label: 'Espera la confirmacion',
        icon: Icons.hourglass_top,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _stepsForMethod(widget.method);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TravelBoxBrand.radiusM),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(TravelBoxBrand.radiusM),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TravelBoxBrand.space16,
                vertical: TravelBoxBrand.space12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: TravelBoxBrand.space8),
                  Expanded(
                    child: Text(
                      'Como funciona?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5)
                        .animate(_iconController),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Collapsible body ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                TravelBoxBrand.space16,
                0,
                TravelBoxBrand.space16,
                TravelBoxBrand.space16,
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: TravelBoxBrand.space12),
                  ...steps.map((step) => _StepRow(step: step)),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

/// Internal model for a single step.
class _StepInfo {
  final int number;
  final String label;
  final IconData icon;

  const _StepInfo({
    required this.number,
    required this.label,
    required this.icon,
  });
}

/// Renders one numbered step row.
class _StepRow extends StatelessWidget {
  final _StepInfo step;

  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TravelBoxBrand.space4),
      child: Row(
        children: [
          // Number circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.number}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: TravelBoxBrand.space12),

          // Icon
          Icon(
            step.icon,
            size: 20,
            color: TravelBoxBrand.textMuted,
          ),
          const SizedBox(width: TravelBoxBrand.space8),

          // Label
          Expanded(
            child: Text(
              step.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: TravelBoxBrand.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
