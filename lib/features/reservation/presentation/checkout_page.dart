import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/payment_constants.dart';
import '../../../core/env/app_env.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../data/reservation_repository_impl.dart';
import 'reservation_providers.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  CheckoutPage({super.key, required this.warehouseId});

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

  @override
  void dispose() {
    _sourceTokenController.dispose();
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
            child: ListTile(
              title: Text(draft.warehouse.name),
              subtitle: Text(
                '${draft.startAt} - ${draft.endAt}\n'
                '${draft.bagCount} ${context.l10n.t('bultos')}, ${context.l10n.t('main_size')} ${draft.size}\n'
                '${context.l10n.t('checkout_summary_pickup')}: ${draft.pickupRequested ? context.l10n.t('yes') : context.l10n.t('no')}'
                ' - ${context.l10n.t('checkout_summary_dropoff')}: ${draft.dropoffRequested ? context.l10n.t('yes') : context.l10n.t('no')}'
                ' - ${context.l10n.t('checkout_summary_insurance')}: ${draft.extraInsurance ? context.l10n.t('yes') : context.l10n.t('no')}',
              ),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.t('payment_method')),
                  SizedBox(height: 8),
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
                      decoration: InputDecoration(border: OutlineInputBorder()),
                    ),
                  if (!forceCashOnly &&
                      (selectedPaymentMethod == PaymentConstants.methodCard ||
                          selectedPaymentMethod ==
                              PaymentConstants.methodYape)) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sourceTokenController,
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'checkout_source_token_label',
                        ),
                        hintText: context.l10n.t('checkout_source_token_hint'),
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
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'checkout_customer_email_optional_label',
                        ),
                        hintText: context.l10n.t(
                          'checkout_customer_email_optional_hint',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(context.l10n.t('final_total')),
              subtitle: Text(
                '${context.l10n.t('checkout_breakdown_storage')} ${NumberFormat.simpleCurrency(locale: 'es_PE').format(draft.storageSubtotal())} '
                '+ ${context.l10n.t('checkout_breakdown_pickup')} ${NumberFormat.simpleCurrency(locale: 'es_PE').format(draft.pickupCost())} '
                '+ ${context.l10n.t('checkout_breakdown_dropoff')} ${NumberFormat.simpleCurrency(locale: 'es_PE').format(draft.dropoffCost())} '
                '+ ${context.l10n.t('checkout_breakdown_insurance')} ${NumberFormat.simpleCurrency(locale: 'es_PE').format(draft.insuranceCost())}',
              ),
              trailing: Text(
                NumberFormat.simpleCurrency(locale: 'es_PE').format(draft.estimatePrice()),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                _isOfflinePaymentMethod(selectedPaymentMethod)
                    ? Icons.storefront_outlined
                    : Icons.payments_outlined,
              ),
              title: Text(_paymentHeadline(selectedPaymentMethod)),
              subtitle: Text(_paymentHelp(selectedPaymentMethod)),
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
                    if (!forceCashOnly &&
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
                      final reservation = await ref
                          .read(reservationRepositoryProvider)
                          .createReservation(
                            userId: user.id,
                            draft: draft,
                            paymentMethod: forceCashOnly
                                ? PaymentConstants.methodCash
                                : selectedPaymentMethod,
                            sourceTokenId: forceCashOnly
                                ? null
                                : _sourceTokenController.text.trim(),
                            customerEmail: forceCashOnly
                                ? null
                                : _customerEmailController.text.trim(),
                          );
                      ref.invalidate(myReservationsProvider);
                      ref.invalidate(adminReservationsProvider);
                      ref.invalidate(adminReservationListProvider);
                      ref.invalidate(reservationByIdProvider(reservation.id));
                      ref.read(reservationDraftProvider.notifier).state = null;
                      if (!context.mounted) return;
                      context.go('/reservation/${reservation.id}?back=home');
                    } catch (error) {
                      if (!context.mounted) return;
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
    return AppErrorFormatter.readable(error);
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

  String _paymentHelp(String method) {
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
}
