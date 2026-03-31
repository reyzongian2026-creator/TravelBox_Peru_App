import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/payment_constants.dart';
import '../../../core/env/app_env.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../shared/state/currency_preference.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../payments/data/culqi_token_service.dart';
import '../../payments/data/payment_repository.dart';
import '../data/reservation_repository_impl.dart';
import '../domain/reservation_repository.dart';
import 'reservation_providers.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.warehouseId});

  final String warehouseId;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  bool processing = false;
  String paymentMethod = AppEnv.forceCashPaymentsOnly
      ? PaymentConstants.methodCash
      : PaymentConstants.methodCard;
  final _sourceTokenController = TextEditingController();
  final _customerEmailController = TextEditingController();

  // Card fields for real Culqi tokenization.
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();

  bool get _useCulqiTokenization =>
      AppEnv.hasCulqiConfig &&
      !AppEnv.forceCashPaymentsOnly &&
      paymentMethod == PaymentConstants.methodCard;

  @override
  void dispose() {
    _sourceTokenController.dispose();
    _customerEmailController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reservationDraftProvider);
    final user = ref.watch(sessionControllerProvider).user;
    final forceCashOnly = AppEnv.forceCashPaymentsOnly;
    final selectedPaymentMethod = forceCashOnly
        ? PaymentConstants.methodCash
        : paymentMethod;

    if (draft == null || draft.warehouse.id != widget.warehouseId) {
      return Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            fallbackRoute: '/reservation/new/${widget.warehouseId}',
          ),
          title: Text(context.l10n.t('checkout_title')),
        ),
        body: Center(
          child: FilledButton(
            onPressed: () =>
                context.push('/reservation/new/${widget.warehouseId}'),
            child: Text(context.l10n.t('complete_data_first')),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(
          fallbackRoute: '/reservation/new/${widget.warehouseId}',
        ),
        title: Text(context.l10n.t('checkout_payment')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.warehouse.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CheckoutInfoRow(
                    icon: Icons.schedule_outlined,
                    label: _reservationWindowLabel(context),
                    value: _formatReservationWindow(context, draft),
                  ),
                  const SizedBox(height: 10),
                  _CheckoutInfoRow(
                    icon: Icons.luggage_outlined,
                    label: _reservationSummaryLabel(context),
                    value:
                        '${draft.bagCount} ${context.l10n.t('bultos')} - ${context.l10n.t('main_size')} ${draft.size}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryChip(
                        label:
                            '${context.l10n.t('checkout_summary_pickup')}: ${draft.pickupRequested ? context.l10n.t('yes') : context.l10n.t('no')}',
                      ),
                      _SummaryChip(
                        label:
                            '${context.l10n.t('checkout_summary_dropoff')}: ${draft.dropoffRequested ? context.l10n.t('yes') : context.l10n.t('no')}',
                      ),
                      _SummaryChip(
                        label:
                            '${context.l10n.t('checkout_summary_insurance')}: ${draft.extraInsurance ? context.l10n.t('yes') : context.l10n.t('no')}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.t('payment_method'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (forceCashOnly)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(context.l10n.t('cash_only')),
                      subtitle: Text(
                        context.l10n.t('checkout_digital_payments_disabled'),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: PaymentConstants.methodCard,
                          child: Text(context.l10n.t('card')),
                        ),
                        DropdownMenuItem(
                          value: PaymentConstants.methodYape,
                          child: Text(context.l10n.t('yape')),
                        ),
                        DropdownMenuItem(
                          value: PaymentConstants.methodWallet,
                          child: Text(context.l10n.t('walletplin')),
                        ),
                        DropdownMenuItem(
                          value: PaymentConstants.methodCounter,
                          child: Text(context.l10n.t('at_counter')),
                        ),
                        DropdownMenuItem(
                          value: PaymentConstants.methodCash,
                          child: Text(context.l10n.t('cash')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => paymentMethod = value);
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (!forceCashOnly &&
                      selectedPaymentMethod == PaymentConstants.methodCard &&
                      _useCulqiTokenization) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      maxLength: 19,
                      decoration: InputDecoration(
                        labelText: context.l10n.locale.languageCode == 'en'
                            ? 'Card number'
                            : 'Número de tarjeta',
                        hintText: '4111 1111 1111 1111',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cardExpiryController,
                            keyboardType: TextInputType.datetime,
                            maxLength: 5,
                            decoration: InputDecoration(
                              labelText: context.l10n.locale.languageCode == 'en'
                                  ? 'MM/YY'
                                  : 'MM/AA',
                              hintText: '12/28',
                              border: const OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _cardCvvController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                              border: const OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!forceCashOnly &&
                      ((selectedPaymentMethod == PaymentConstants.methodCard &&
                              !_useCulqiTokenization) ||
                          selectedPaymentMethod ==
                              PaymentConstants.methodYape)) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sourceTokenController,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: _sourceTokenLabel(context),
                        hintText: _sourceTokenHint(context),
                        helperText: _sourceTokenHelper(context),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (!forceCashOnly &&
                      (selectedPaymentMethod == PaymentConstants.methodCard ||
                          selectedPaymentMethod ==
                              PaymentConstants.methodYape ||
                          selectedPaymentMethod ==
                              PaymentConstants.methodWallet)) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _customerEmailLabel(context),
                        hintText: _customerEmailHint(context),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.t('final_total'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _totalBreakdownCaption(context),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CheckoutAmountRow(
                    label: context.l10n.t('checkout_breakdown_storage'),
                    value: _formatMoney(draft.storageSubtotal(), draft),
                  ),
                  if (draft.pickupCost() > 0)
                    _CheckoutAmountRow(
                      label: context.l10n.t('checkout_breakdown_pickup'),
                      value: _formatMoney(draft.pickupCost(), draft),
                    ),
                  if (draft.dropoffCost() > 0)
                    _CheckoutAmountRow(
                      label: context.l10n.t('checkout_breakdown_dropoff'),
                      value: _formatMoney(draft.dropoffCost(), draft),
                    ),
                  if (draft.insuranceCost() > 0)
                    _CheckoutAmountRow(
                      label: context.l10n.t('checkout_breakdown_insurance'),
                      value: _formatMoney(draft.insuranceCost(), draft),
                    ),
                  const Divider(height: 24),
                  _CheckoutAmountRow(
                    label: context.l10n.t('final_total'),
                    value: _formatMoney(draft.estimatePrice(), draft),
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                _isOfflinePaymentMethod(selectedPaymentMethod)
                    ? Icons.storefront_outlined
                    : Icons.payments_outlined,
              ),
              title: Text(_paymentHeadline(selectedPaymentMethod)),
              subtitle: Text(_paymentHelp(context, selectedPaymentMethod)),
            ),
          ),
          if (!forceCashOnly &&
              !_useCulqiTokenization &&
              (selectedPaymentMethod == PaymentConstants.methodCard ||
                  selectedPaymentMethod == PaymentConstants.methodYape))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: Text(_testingNoticeTitle(context)),
                  subtitle: Text(_testingNoticeBody(context)),
                ),
              ),
            ),
          if (selectedPaymentMethod == PaymentConstants.methodCounter ||
              selectedPaymentMethod == PaymentConstants.methodCash)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(context.l10n.t('counter_validation')),
                  subtitle: Text(
                    context.l10n.t('checkout_pending_offline_approval_notice'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: processing
                ? null
                : () async {
                    if (user == null) return;

                    // Validate card fields when using real Culqi tokenization.
                    if (_useCulqiTokenization) {
                      if (_cardNumberController.text.trim().isEmpty ||
                          _cardExpiryController.text.trim().isEmpty ||
                          _cardCvvController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.locale.languageCode == 'en'
                                  ? 'Please fill in all card fields.'
                                  : 'Completa todos los campos de tarjeta.',
                            ),
                          ),
                        );
                        return;
                      }
                    } else if (!forceCashOnly &&
                        (selectedPaymentMethod == PaymentConstants.methodCard ||
                            selectedPaymentMethod ==
                                PaymentConstants.methodYape) &&
                        _sourceTokenController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.t(
                              'checkout_source_token_required_notice',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() => processing = true);
                    try {
                      String? sourceTokenId;

                      // Tokenize card via Culqi if using real tokenization.
                      if (_useCulqiTokenization) {
                        final expiry = _cardExpiryController.text.trim();
                        final parts = expiry.split('/');
                        final month = int.tryParse(parts.firstOrNull ?? '') ?? 0;
                        final yearRaw = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
                        final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;

                        final email = _customerEmailController.text.trim().isNotEmpty
                            ? _customerEmailController.text.trim()
                            : user.email;

                        final tokenResult =
                            await CulqiTokenService.instance.createToken(
                          CulqiCardData(
                            cardNumber: _cardNumberController.text.trim(),
                            expirationMonth: month,
                            expirationYear: year,
                            cvv: _cardCvvController.text.trim(),
                            email: email,
                          ),
                        );

                        if (!tokenResult.success) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tokenResult.error ??
                                  'Error al tokenizar tarjeta.'),
                            ),
                          );
                          return;
                        }
                        sourceTokenId = tokenResult.tokenId;
                      } else {
                        sourceTokenId = forceCashOnly
                            ? null
                            : _sourceTokenController.text.trim();
                      }

                      final reservation = await ref
                          .read(reservationRepositoryProvider)
                          .createReservation(
                            userId: user.id,
                            draft: draft,
                            paymentMethod: forceCashOnly
                                ? PaymentConstants.methodCash
                                : selectedPaymentMethod,
                            sourceTokenId: sourceTokenId,
                            customerEmail: forceCashOnly
                                ? null
                                : _customerEmailController.text.trim(),
                          );

                      // Check if the payment requires 3DS authentication.
                      if (!forceCashOnly &&
                          selectedPaymentMethod == PaymentConstants.methodCard) {
                        final parsedResId = int.tryParse(reservation.id);
                        if (parsedResId != null) {
                          try {
                            final paymentRepo =
                                ref.read(paymentRepositoryProvider);
                            final status = await paymentRepo.getPaymentStatus(
                              reservationId: parsedResId,
                            );
                            if (status.isPending) {
                              // Could be 3DS — check via the full intent
                              // The reservation flow already triggered payment,
                              // so we just check status here.
                            }
                          } catch (_) {
                            // Non-critical; proceed to reservation page.
                          }
                        }
                      }

                      ref.invalidate(myReservationsProvider);
                      ref.invalidate(adminReservationsProvider);
                      ref.invalidate(adminReservationListProvider);
                      ref.invalidate(reservationByIdProvider(reservation.id));
                      ref.read(reservationDraftProvider.notifier).state = null;
                      if (!context.mounted) return;
                      context.go('/reservation/${reservation.id}?back=home');
                    } catch (error) {
                      if (!context.mounted) return;

                      // Handle 3DS redirect from payment flow errors that
                      // contain nextAction data.
                      if (_tryHandle3dsRedirect(error)) return;

                      final message = _errorMessage(error);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${context.l10n.t('checkout_payment_process_failed_prefix')}: '
                            '$message',
                          ),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => processing = false);
                      }
                    }
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              processing
                  ? context.l10n.t('checkout_processing')
                  : context.l10n.t('checkout_confirm_payment'),
            ),
          ),
        ],
      ),
    );
  }

  String _errorMessage(Object error) {
    return AppErrorFormatter.readable(
      error,
      (String key, {Map<String, dynamic>? params}) => context.l10n.t(key),
    );
  }

  /// Attempts to detect a 3DS redirect from a DioException whose response
  /// body contains nextAction with AUTHENTICATE_3DS. Returns true if handled.
  bool _tryHandle3dsRedirect(Object error) {
    Map<String, dynamic>? responseData;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        responseData = data;
      }
    }
    if (responseData == null) return false;

    final nextAction = responseData['nextAction'] as Map<String, dynamic>?;
    if (nextAction == null || nextAction['type'] != 'AUTHENTICATE_3DS') {
      return false;
    }

    final providerPayload =
        nextAction['providerPayload'] as Map<String, dynamic>? ?? {};
    final authUrl = providerPayload['authenticationUrl']?.toString();
    final paymentIntentId = nextAction['paymentIntentId']?.toString();
    final reservationId = nextAction['reservationId']?.toString();

    if (authUrl == null || authUrl.isEmpty) return false;
    if (paymentIntentId == null || reservationId == null) return false;

    if (!context.mounted) return false;
    context.push(
      '/payment/3ds-auth'
      '?paymentIntentId=$paymentIntentId'
      '&reservationId=$reservationId'
      '&authUrl=${Uri.encodeComponent(authUrl)}',
    );
    return true;
  }

  bool _isOfflinePaymentMethod(String method) {
    return PaymentConstants.isOffline(method);
  }

  String _paymentHeadline(String method) {
    if (_isOfflinePaymentMethod(method)) {
      return context.l10n.t('checkout_payment_headline_offline');
    }
    return context.l10n.t('checkout_payment_headline_online');
  }

  String _paymentHelp(BuildContext context, String method) {
    switch (method) {
      case PaymentConstants.methodCard:
        return context.l10n.t('checkout_payment_help_card');
      case PaymentConstants.methodYape:
        return context.l10n.t('checkout_payment_help_yape');
      case PaymentConstants.methodWallet:
        return context.l10n.t('checkout_payment_help_wallet');
      case PaymentConstants.methodCounter:
        return context.l10n.t('checkout_payment_help_counter');
      case PaymentConstants.methodCash:
        return context.l10n.t('checkout_payment_help_cash');
      default:
        return context.l10n.t('checkout_payment_help_default');
    }
  }

  String _formatReservationWindow(
    BuildContext context,
    ReservationDraft draft,
  ) {
    final locale = _dateLocale(context);
    final start = draft.startAt.toLocal();
    final end = draft.endAt.toLocal();
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    final dayFormatter = DateFormat('EEE d MMM', locale);
    final dateTimeFormatter = DateFormat('EEE d MMM, HH:mm', locale);
    final timeFormatter = DateFormat('HH:mm', locale);

    if (sameDay) {
      return '${_capitalize(dayFormatter.format(start))} · ${timeFormatter.format(start)} - ${timeFormatter.format(end)}';
    }
    return '${_capitalize(dateTimeFormatter.format(start))} - ${_capitalize(dateTimeFormatter.format(end))}';
  }

  String _formatMoney(double amount, ReservationDraft draft) {
    final currency = _transactionCurrency(draft);
    return formatCurrency(amount, currency);
  }

  CurrencyCode _transactionCurrency(ReservationDraft draft) {
    switch (draft.warehouse.currencyCode.trim().toUpperCase()) {
      case 'USD':
        return CurrencyCode.usd;
      case 'EUR':
        return CurrencyCode.eur;
      case 'PEN':
      default:
        return CurrencyCode.pen;
    }
  }

  String _dateLocale(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final countryCode = locale.countryCode;
    if (countryCode == null || countryCode.isEmpty) {
      return locale.languageCode;
    }
    return '${locale.languageCode}_$countryCode';
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  String _reservationWindowLabel(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Reservation schedule'
        : 'Fecha y horario';
  }

  String _reservationSummaryLabel(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Reservation details'
        : 'Detalle de la reserva';
  }

  String _sourceTokenLabel(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Culqi test token'
        : 'Token de prueba Culqi';
  }

  String _sourceTokenHint(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Example: tkn_test_xxx'
        : 'Ejemplo: tkn_test_xxx';
  }

  String _sourceTokenHelper(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Visible only for internal payment tests. The backend still sends this value as sourceTokenId.'
        : 'Visible solo para pruebas internas de pago. Internamente se seguirá enviando como sourceTokenId.';
  }

  String _customerEmailLabel(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Email to receive confirmation (optional)'
        : 'Correo para recibir la confirmación (opcional)';
  }

  String _customerEmailHint(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'traveler@email.com'
        : 'viajero@correo.com';
  }

  String _totalBreakdownCaption(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Review the reservation amount before confirming your payment.'
        : 'Revisa el desglose de tu reserva antes de confirmar el pago.';
  }

  String _testingNoticeTitle(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Internal test mode'
        : 'Modo de prueba interna';
  }

  String _testingNoticeBody(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'This field remains visible only while validating Culqi internally. For users, the final flow will hide this step.'
        : 'Este campo se mantiene visible solo mientras validamos Culqi internamente. Para usuarios finales, este paso se ocultará.';
  }
}

class _CheckoutInfoRow extends StatelessWidget {
  const _CheckoutInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CheckoutAmountRow extends StatelessWidget {
  const _CheckoutAmountRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, textAlign: TextAlign.end, style: style),
        ],
      ),
    );
  }
}
