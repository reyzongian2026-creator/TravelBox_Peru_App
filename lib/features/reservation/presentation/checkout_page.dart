import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/constants/payment_constants.dart';
import '../../../core/env/app_env.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../shared/state/currency_preference.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../payments/data/izipay_checkout_service.dart';
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
  final _izipayCheckoutService = createIzipayCheckoutService();
  final _customerEmailController = TextEditingController();

  bool processing = false;
  int? _selectedSavedCardId;
  String paymentMethod = AppEnv.forceCashPaymentsOnly
      ? PaymentConstants.methodCash
      : PaymentConstants.methodCard;

  @override
  void dispose() {
    _customerEmailController.dispose();
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

    final responsive = context.responsive;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(
          fallbackRoute: '/reservation/new/${widget.warehouseId}',
        ),
        title: Text(context.l10n.t('checkout_payment')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
        padding: responsive.pageInsets(top: responsive.verticalPadding, bottom: 24),
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
                      isExpanded: true,
                      initialValue: selectedPaymentMethod,
                      items: [
                        DropdownMenuItem(
                          value: PaymentConstants.methodCard,
                          child: Text(context.l10n.t('card')),
                        ),
                        DropdownMenuItem(
                          value: PaymentConstants.methodSavedCard,
                          child: Text(context.l10n.t('saved_card')),
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
                  if (paymentMethod == PaymentConstants.methodSavedCard) ...[
                    const SizedBox(height: 12),
                    FutureBuilder<List<SavedCard>>(
                      future: ref.read(paymentRepositoryProvider).getSavedCards(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        final cards = snapshot.data ?? [];
                        if (cards.isEmpty) {
                          return Text(
                            context.l10n.t('no_saved_cards'),
                            style: const TextStyle(color: Colors.red),
                          );
                        }
                        return DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _selectedSavedCardId,
                          items: cards.map((card) {
                            return DropdownMenuItem<int>(
                              value: int.tryParse(card.id),
                              child: Text('${card.brand} **** ${card.lastFourDigits}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedSavedCardId = value);
                          },
                          decoration: InputDecoration(
                            labelText: context.l10n.t('select_card'),
                            border: const OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                  ],
                  if (!forceCashOnly &&
                      !_isOfflinePaymentMethod(selectedPaymentMethod)) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _customerEmailLabel(context),
                        hintText: _customerEmailHint(context),
                        helperText: _checkoutEmailHelper(context),
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

                    setState(() => processing = true);
                    dynamic reservation;
                    try {
                      reservation = await ref
                          .read(reservationRepositoryProvider)
                          .createReservation(
                            userId: user.id,
                            draft: draft,
                            paymentMethod: forceCashOnly
                                ? PaymentConstants.methodCash
                                : selectedPaymentMethod,
                            customerEmail: forceCashOnly
                                ? null
                                : _normalizedCustomerEmail(user.email),
                          );

                      final checkoutMessage = await _processOnlinePayment(
                        reservationId: reservation.id.toString(),
                        paymentMethod: selectedPaymentMethod,
                        forceCashOnly: forceCashOnly,
                      );

                      ref.invalidate(myReservationsProvider);
                      ref.invalidate(adminReservationsProvider);
                      ref.invalidate(adminReservationListProvider);
                      ref.invalidate(
                        reservationByIdProvider(reservation.id.toString()),
                      );
                      ref.read(reservationDraftProvider.notifier).state = null;

                      if (!context.mounted) return;
                      if (checkoutMessage != null && checkoutMessage.isNotEmpty) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(checkoutMessage)));
                      }
                      context.go(
                        '/reservation/${reservation.id.toString()}?back=home',
                      );
                    } catch (error) {
                      if (!context.mounted) return;

                      final message = _errorMessage(error);
                      if (reservation != null) {
                        ref.invalidate(myReservationsProvider);
                        ref.invalidate(adminReservationsProvider);
                        ref.invalidate(adminReservationListProvider);
                        ref.invalidate(
                          reservationByIdProvider(reservation.id.toString()),
                        );
                        ref.read(reservationDraftProvider.notifier).state = null;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${context.l10n.t('checkout_payment_process_failed_prefix')}: '
                              '$message',
                            ),
                          ),
                        );
                        context.go(
                          '/reservation/${reservation.id.toString()}?back=home',
                        );
                        return;
                      }

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
        ),
      ),
    );
  }

  Future<String?> _processOnlinePayment({
    required String reservationId,
    required String paymentMethod,
    required bool forceCashOnly,
  }) async {
    if (forceCashOnly || _isOfflinePaymentMethod(paymentMethod)) {
      return null;
    }

    final parsedReservationId = int.tryParse(reservationId);
    if (parsedReservationId == null) {
      throw StateError('No se pudo identificar la reserva creada.');
    }

    final paymentRepo = ref.read(paymentRepositoryProvider);

    // Caso de pago One-Click con tarjeta guardada
    if (paymentMethod == PaymentConstants.methodSavedCard) {
      if (_selectedSavedCardId == null) {
        throw StateError(context.l10n.t('error_no_card_selected'));
      }
      final paymentFailedMsg = context.l10n.t('payment_failed');
      final confirmation = await paymentRepo.payWithSavedCard(
        reservationId: parsedReservationId,
        savedCardId: _selectedSavedCardId!,
      );
      if (confirmation.isConfirmed) {
        return confirmation.message;
      }
      if (confirmation.isFailed) {
        throw StateError(confirmation.message ?? paymentFailedMsg);
      }
      return confirmation.message;
    }

    final intent = await paymentRepo.createIntent(reservationId: parsedReservationId);
    final paymentIntentId = int.tryParse(intent.id);

    final confirmation = await paymentRepo.confirmPayment(
      paymentIntentId: paymentIntentId,
      reservationId: parsedReservationId,
      paymentMethod: paymentMethod,
      customerEmail: _normalizedCustomerEmail(
        ref.read(sessionControllerProvider).user?.email,
      ),
    );

    if (confirmation.isConfirmed) {
      return confirmation.message;
    }

    if (confirmation.requiresIzipayCheckout) {
      final checkoutOutcome = await _openIzipayCheckout(confirmation);
      final status = await _waitForPaymentFinalStatus(
        paymentIntentId: int.tryParse(confirmation.id) ?? paymentIntentId,
        reservationId: parsedReservationId,
        attempts: checkoutOutcome.isCanceled ? 4 : 18,
      );

      if (status.isConfirmed) {
        return _checkoutResultMessage(checkoutOutcome);
      }
      if (status.isFailed) {
        throw StateError(
          _checkoutFailureMessage(
            checkoutOutcome.message,
            status.paymentStatus,
          ),
        );
      }
      return _pendingPaymentMessage(checkoutOutcome);
    }

    final status = await _waitForPaymentFinalStatus(
      paymentIntentId: paymentIntentId,
      reservationId: parsedReservationId,
      attempts: 8,
    );
    if (status.isConfirmed) {
      return confirmation.message;
    }
    if (status.isFailed) {
      throw StateError(
        _checkoutFailureMessage(
          confirmation.message,
          status.paymentStatus,
        ),
      );
    }
    return _defaultPendingPaymentMessage();
  }

  Future<IzipayCheckoutOutcome> _openIzipayCheckout(
    PaymentIntentResult confirmation,
  ) {
    final nextAction = confirmation.nextAction ?? <String, dynamic>{};
    final rawConfig = nextAction['checkoutConfig'];
    final checkoutConfig = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : <String, dynamic>{};

    final request = IzipayCheckoutRequest(
      scriptUrl: nextAction['scriptUrl']?.toString() ?? '',
      authorization: nextAction['authorization']?.toString() ?? '',
      publicKey: nextAction['publicKey']?.toString() ?? '',
      keyRsa: nextAction['keyRSA']?.toString() ?? 'RSA',
      checkoutConfig: checkoutConfig,
    );

    if (request.scriptUrl.isEmpty ||
        request.authorization.isEmpty ||
        request.checkoutConfig.isEmpty) {
      throw StateError('Izipay no devolvio una accion de checkout valida.');
    }
    return _izipayCheckoutService.openCheckout(request);
  }

  Future<PaymentStatusResult> _waitForPaymentFinalStatus({
    required int? paymentIntentId,
    required int reservationId,
    int attempts = 12,
  }) async {
    final paymentRepo = ref.read(paymentRepositoryProvider);
    PaymentStatusResult? latest;

    for (var index = 0; index < attempts; index++) {
      latest = await paymentRepo.getPaymentStatus(
        paymentIntentId: paymentIntentId,
        reservationId: reservationId,
      );
      if (latest.isConfirmed || latest.isFailed) {
        return latest;
      }
      if (index < attempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    return latest ??
        await paymentRepo.getPaymentStatus(
          paymentIntentId: paymentIntentId,
          reservationId: reservationId,
        );
  }

  String? _checkoutResultMessage(IzipayCheckoutOutcome outcome) {
    final response = outcome.response ?? <String, dynamic>{};
    final messageUser = response['messageUser']?.toString();
    final message = response['message']?.toString();
    final resolved = messageUser?.trim() ?? message?.trim();
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    return null;
  }

  String _pendingPaymentMessage(IzipayCheckoutOutcome outcome) {
    if (outcome.isCanceled) {
      return context.l10n.locale.languageCode == 'en'
          ? 'Your reservation was created, but the payment stayed pending after the checkout was closed.'
          : 'Tu reserva fue creada, pero el pago quedo pendiente despues de cerrar el checkout.';
    }
    return _defaultPendingPaymentMessage();
  }

  String _defaultPendingPaymentMessage() {
    return context.l10n.locale.languageCode == 'en'
        ? 'Your reservation was created and the payment is still pending validation.'
        : 'Tu reserva fue creada y el pago sigue pendiente de validacion.';
  }

  String _checkoutFailureMessage(String? message, String status) {
    final normalized = message?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return context.l10n.locale.languageCode == 'en'
        ? 'The payment was rejected by the gateway ($status).'
        : 'La pasarela rechazo el pago ($status).';
  }

  String? _normalizedCustomerEmail(String? fallbackEmail) {
    final typedEmail = _customerEmailController.text.trim();
    if (typedEmail.isNotEmpty) {
      return typedEmail;
    }
    final fallback = fallbackEmail?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  String _errorMessage(Object error) {
    return AppErrorFormatter.readable(
      error,
      (String key, {Map<String, dynamic>? params}) => context.l10n.t(key),
    );
  }

  bool _isOfflinePaymentMethod(String method) {
    return PaymentConstants.isOffline(method);
  }

  String _paymentHeadline(String method) {
    if (method == PaymentConstants.methodSavedCard) {
      return context.l10n.locale.languageCode == 'en'
          ? 'One-Click Payment'
          : 'Pago en un click';
    }
    if (_isOfflinePaymentMethod(method)) {
      return context.l10n.t('checkout_payment_headline_offline');
    }
    return context.l10n.t('checkout_payment_headline_online');
  }

  String _paymentHelp(BuildContext context, String method) {
    switch (method) {
      case PaymentConstants.methodSavedCard:
        return context.l10n.locale.languageCode == 'en'
            ? 'We will use your saved card to process the payment immediately without opening the checkout.'
            : 'Usaremos tu tarjeta guardada para procesar el pago inmediatamente sin abrir el checkout.';
      case PaymentConstants.methodCard:
        return context.l10n.locale.languageCode == 'en'
            ? 'Card payments are completed in the secure Izipay checkout before the reservation is confirmed.'
            : 'Los pagos con tarjeta se completan en el checkout seguro de Izipay antes de confirmar la reserva.';
      case PaymentConstants.methodYape:
        return context.l10n.locale.languageCode == 'en'
            ? 'Yape opens through Izipay so the final status can be validated from the backend.'
            : 'Yape se abre a traves de Izipay para validar el estado final desde el backend.';
      case PaymentConstants.methodWallet:
        return context.l10n.locale.languageCode == 'en'
            ? 'Plin and wallet flows are handled in Izipay and stay pending until the gateway confirms them.'
            : 'Los flujos de Plin y billetera se manejan en Izipay y quedan pendientes hasta que la pasarela los confirme.';
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

  String _customerEmailLabel(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Email for payment receipt (optional)'
        : 'Correo para el comprobante de pago (opcional)';
  }

  String _customerEmailHint(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'traveler@email.com'
        : 'viajero@correo.com';
  }

  String _checkoutEmailHelper(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'If you leave it blank, we will use the email from your account for Izipay.'
        : 'Si lo dejas vacio, usaremos el correo de tu cuenta para Izipay.';
  }

  String _totalBreakdownCaption(BuildContext context) {
    return context.l10n.locale.languageCode == 'en'
        ? 'Review the reservation amount before confirming your payment.'
        : 'Revisa el desglose de tu reserva antes de confirmar el pago.';
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
