import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/currency_preference.dart';

class CurrencySelector extends ConsumerWidget {
  const CurrencySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCurrency = ref.watch(currencyPreferenceProvider);

    return PopupMenuButton<CurrencyCode>(
      initialValue: currentCurrency,
      onSelected: (currency) {
        ref.read(currencyPreferenceProvider.notifier).setCurrency(currency);
      },
      itemBuilder: (context) => CurrencyCode.values.map((currency) {
        return PopupMenuItem(
          value: currency,
          child: Row(
            children: [
              Text(
                currency.symbol,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(currency.name),
              if (currency == currentCurrency) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentCurrency.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

class PriceDisplay extends StatelessWidget {
  const PriceDisplay({
    super.key,
    required this.priceInPEN,
    this.showCurrencySelector = false,
    this.style,
    this.suffix,
    this.showOriginalIfConverted = false,
    this.secondaryStyle,
    this.alignment = CrossAxisAlignment.start,
  });

  final double priceInPEN;
  final bool showCurrencySelector;
  final TextStyle? style;
  final String? suffix;
  final bool showOriginalIfConverted;
  final TextStyle? secondaryStyle;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final userCurrency = ref.watch(currencyPreferenceProvider);
        final convertedPrice = CurrencyRates.convert(
          priceInPEN,
          CurrencyCode.pen,
          userCurrency,
        );
        final primaryText = suffix == null || suffix!.trim().isEmpty
            ? formatCurrency(convertedPrice, userCurrency)
            : '${formatCurrency(convertedPrice, userCurrency)} $suffix';
        final originalText =
            showOriginalIfConverted && userCurrency != CurrencyCode.pen
            ? formatCurrency(priceInPEN, CurrencyCode.pen)
            : null;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: alignment,
              children: [
                Text(primaryText, style: style),
                if (originalText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    originalText,
                    style:
                        secondaryStyle ??
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
            if (showCurrencySelector) ...[
              const SizedBox(width: 4),
              const CurrencySelector(),
            ],
          ],
        );
      },
    );
  }
}

class PriceDisplayWithOriginal extends StatelessWidget {
  const PriceDisplayWithOriginal({
    super.key,
    required this.priceInPEN,
    this.suffix,
    this.style,
    this.secondaryStyle,
    this.alignment = CrossAxisAlignment.start,
  });

  final double priceInPEN;
  final String? suffix;
  final TextStyle? style;
  final TextStyle? secondaryStyle;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return PriceDisplay(
      priceInPEN: priceInPEN,
      suffix: suffix,
      showOriginalIfConverted: true,
      alignment: alignment,
      style:
          style ??
          Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      secondaryStyle: secondaryStyle,
    );
  }
}
