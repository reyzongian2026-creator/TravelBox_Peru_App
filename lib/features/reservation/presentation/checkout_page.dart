import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../core/constants/payment_constants.dart';
import '../../../core/env/app_env.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../shared/state/currency_preference.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/widgets/critical_operation_overlay.dart';
import '../../../shared/widgets/payment_celebration_overlay.dart';
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
  final _customerPhoneController = TextEditingController();
  final _promoCodeController = TextEditingController();
  String? _normalizedPhone;

  bool processing = false;
  bool _submitting = false; // synchronous guard against double-tap
  bool _paymentJustConfirmed = false; // set when payment is confirmed, used to trigger celebration
  String? _emailError;
  int? _selectedSavedCardId;
  String paymentMethod = AppEnv.forceCashPaymentsOnly
      ? PaymentConstants.methodCash
      : PaymentConstants.methodCard;

  String? _selectedDigitalSubmethod; // card, yape, plin, qr — for display only

  // Promo code state
  PromoCodeResult? _promoResult;
  bool _promoLoading = false;
  String? _appliedPromoCode;

  // Wallet state
  double _walletBalance = 0;
  bool _useWallet = false;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final balance = await paymentRepo.getWalletBalance();
      if (mounted) setState(() => _walletBalance = balance);
    } catch (_) {}
  }

  @override
  void dispose() {
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _promoCodeController.dispose();
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
                    context.l10n.t('checkout_choose_method'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.t('checkout_choose_method_subtitle'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (forceCashOnly)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(context.l10n.t('cash_only')),
                      subtitle: Text(
                        context.l10n.t('checkout_digital_payments_disabled'),
                      ),
                    )
                  else ...[
                    Text(
                      context.l10n.t('checkout_digital_section'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.0,
                      children: [
                        _PaymentGridCard(
                          icon: Icons.credit_card,
                          label: context.l10n.t('checkout_method_card_label'),
                          sublabel: context.l10n.t('checkout_method_card_sublabel'),
                          selected: selectedPaymentMethod == PaymentConstants.methodCard,
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodCard; _selectedDigitalSubmethod = 'card'; }),
                        ),
                        _PaymentGridCard(
                          icon: Icons.qr_code_2,
                          label: 'Yape',
                          sublabel: context.l10n.t('checkout_method_yape_sublabel'),
                          selected: _selectedDigitalSubmethod == 'yape',
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodYape; _selectedDigitalSubmethod = 'yape'; }),
                        ),
                        _PaymentGridCard(
                          icon: Icons.phone_android,
                          label: 'Plin',
                          sublabel: context.l10n.t('checkout_method_plin_sublabel'),
                          selected: _selectedDigitalSubmethod == 'plin',
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodPlin; _selectedDigitalSubmethod = 'plin'; }),
                        ),
                        _PaymentGridCard(
                          icon: Icons.qr_code,
                          label: 'QR',
                          sublabel: context.l10n.t('checkout_method_qr_sublabel'),
                          selected: _selectedDigitalSubmethod == 'qr',
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodWallet; _selectedDigitalSubmethod = 'qr'; }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.t('checkout_onsite_section'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.0,
                      children: [
                        _PaymentGridCard(
                          icon: Icons.storefront_outlined,
                          label: context.l10n.t('checkout_method_counter_label'),
                          sublabel: context.l10n.t('checkout_method_counter_sublabel'),
                          selected: selectedPaymentMethod == PaymentConstants.methodCounter,
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodCounter; _selectedDigitalSubmethod = null; }),
                        ),
                        _PaymentGridCard(
                          icon: Icons.payments_outlined,
                          label: context.l10n.t('checkout_method_cash_label'),
                          sublabel: context.l10n.t('checkout_method_cash_sublabel'),
                          selected: selectedPaymentMethod == PaymentConstants.methodCash,
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodCash; _selectedDigitalSubmethod = null; }),
                        ),
                      ],
                    ),
                  ],
                  if (!forceCashOnly &&
                      !_isOfflinePaymentMethod(selectedPaymentMethod)) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _customerEmailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) {
                        final trimmed = value.trim();
                        setState(() {
                          if (trimmed.isEmpty) {
                            _emailError = null;
                          } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(trimmed)) {
                            _emailError = context.l10n.t('invalid_email');
                          } else {
                            _emailError = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: _customerEmailLabel(context),
                        hintText: _customerEmailHint(context),
                        helperText: _emailError == null ? _checkoutEmailHelper(context) : null,
                        errorText: _emailError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _customerPhoneController,
                      decoration: InputDecoration(
                        labelText: context.l10n.t('phone_number_label'),
                        hintText: context.l10n.t('phone_hint'),
                        prefixIcon: const Icon(Icons.phone),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.t('phone_required');
                        }
                        final phone = value.replaceAll(RegExp(r'[^\d+]'), '');
                        if (!RegExp(r'^\+?51\d{9}$').hasMatch(phone)) {
                          return context.l10n.t('phone_invalid');
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _normalizedPhone = value?.replaceAll(RegExp(r'[^\d+]'), '');
                      },
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
                  if (_promoResult != null && _promoResult!.valid && _promoResult!.calculatedDiscount != null)
                    _CheckoutAmountRow(
                      label: context.l10n.t('promo_discount'),
                      value: '- ${_formatMoney(_promoResult!.calculatedDiscount!, draft)}',
                      emphasize: false,
                    ),
                  if (_useWallet && _walletBalance > 0)
                    _CheckoutAmountRow(
                      label: context.l10n.t('wallet_credit'),
                      value: '- ${_formatMoney(_walletBalance.clamp(0, _effectiveTotal(draft)), draft)}',
                      emphasize: false,
                    ),
                  _CheckoutAmountRow(
                    label: context.l10n.t('final_total'),
                    value: _formatMoney(
                      _computeFinalTotal(draft),
                      draft,
                    ),
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Promo code input ──────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.t('promo_code_title'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: context.l10n.t('promo_code_hint'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          enabled: _appliedPromoCode == null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_appliedPromoCode == null)
                        FilledButton(
                          onPressed: _promoLoading ? null : () => _validatePromoCode(draft.estimatePrice()),
                          child: _promoLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(context.l10n.t('promo_apply')),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _promoResult = null;
                              _appliedPromoCode = null;
                              _promoCodeController.clear();
                            });
                          },
                          child: Text(context.l10n.t('promo_remove')),
                        ),
                    ],
                  ),
                  if (_promoResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _promoResult!.message ?? '',
                      style: TextStyle(
                        color: _promoResult!.valid ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Wallet credit toggle ──────────────────────────
          if (_walletBalance > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.t('wallet_credit'),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'S/ ${_walletBalance.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _useWallet,
                      onChanged: (v) => setState(() => _useWallet = v),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (!forceCashOnly && !_isOfflinePaymentMethod(selectedPaymentMethod))
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(_paymentHelp(context, selectedPaymentMethod)),
              ),
            ),
          if (selectedPaymentMethod == PaymentConstants.methodCounter ||
              selectedPaymentMethod == PaymentConstants.methodCash)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.l10n.t('counter_validation')),
                subtitle: Text(
                  context.l10n.t('checkout_pending_offline_approval_notice'),
                ),
              ),
            ),
          const SizedBox(height: 80), // space for bottom button
        ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: processing
                ? null
                : () => _handleConfirmPayment(
                      user: user!,
                      draft: draft,
                      selectedPaymentMethod: selectedPaymentMethod,
                      forceCashOnly: forceCashOnly,
                    ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              processing
                  ? context.l10n.t('checkout_processing')
                  : _isOfflinePaymentMethod(selectedPaymentMethod)
                      ? context.l10n.t('checkout_confirm_payment')
                      : context.l10n.t('checkout_continue_purchase'),
            ),
          ),
        ),
      ),
    );
  }

  double _effectiveTotal(dynamic draft) {
    double total = draft.estimatePrice();
    if (_promoResult != null && _promoResult!.valid && _promoResult!.calculatedDiscount != null) {
      total -= _promoResult!.calculatedDiscount!;
    }
    return total.clamp(0, double.infinity);
  }

  double _computeFinalTotal(dynamic draft) {
    double total = _effectiveTotal(draft);
    if (_useWallet && _walletBalance > 0) {
      total -= _walletBalance.clamp(0, total);
    }
    return total.clamp(0, double.infinity);
  }

  Future<void> _validatePromoCode(double orderAmount) async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _promoLoading = true);
    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final result = await paymentRepo.validatePromoCode(code: code, amount: orderAmount);
      setState(() {
        _promoResult = result;
        if (result.valid) {
          _appliedPromoCode = code;
        }
      });
    } catch (_) {
      setState(() {
        _promoResult = PromoCodeResult(valid: false, message: context.l10n.t('checkout_promo_error'));
      });
    } finally {
      setState(() => _promoLoading = false);
    }
  }

  Future<void> _handleConfirmPayment({
    required dynamic user,
    required dynamic draft,
    required String selectedPaymentMethod,
    required bool forceCashOnly,
  }) async {
    if (_submitting) return;
    _submitting = true;

    // Generate idempotency key to prevent duplicate payments
    final idempotencyKey = '${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(999999).toString().padLeft(6, '0')}';
    debugPrint('[Checkout] idempotency=$idempotencyKey');

    // Normalize phone early so onSaved fires
    _normalizedPhone ??= _customerPhoneController.text.replaceAll(RegExp(r'[^\d+]'), '');

    // Block submission if email field has validation error
    final email = _customerEmailController.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      _submitting = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('invalid_email'))),
      );
      return;
    }

    setState(() => processing = true);
    OverlayEntry? overlay;
    bool overlayDismissed = false;
    dynamic reservation;
    try {
      final isManualTransfer = const {
        PaymentConstants.methodYape,
        PaymentConstants.methodPlin,
        PaymentConstants.methodWallet,
      }.contains(selectedPaymentMethod);
      if (context.mounted) {
        overlay = CriticalOperationOverlay.show(
          context,
          message: isManualTransfer
              ? context.l10n.t('checkout_overlay_generating_qr')
              : context.l10n.t('checkout_overlay_processing_payment'),
          submessage: context.l10n.t('checkout_overlay_submessage'),
        );
      }

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
        onBeforeManualTransferDialog: () {
          if (overlay != null && !overlayDismissed) {
            CriticalOperationOverlay.dismiss(overlay);
            overlayDismissed = true;
          }
        },
      );

      ref.invalidate(myReservationsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminReservationListProvider);
      ref.invalidate(
        reservationByIdProvider(reservation.id.toString()),
      );
      ref.read(reservationDraftProvider.notifier).state = null;

      if (!context.mounted) return;
      if (_paymentJustConfirmed || (checkoutMessage != null && checkoutMessage.contains('verified'))) {
        PaymentCelebration.show(context);
        await Future.delayed(const Duration(milliseconds: 500));
        _paymentJustConfirmed = false;
        if (!context.mounted) return;
      }
      if (checkoutMessage != null && checkoutMessage.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(checkoutMessage)));
      }
      if (!context.mounted) return;
      context.go(
        '/reservation/${reservation.id.toString()}?back=home',
      );
    } catch (error) {
      if (!context.mounted) return;

      if (_isPreconditionError(error)) {
        final redirectRoute = _preconditionRedirectRoute(error);
        if (redirectRoute != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage(error))),
          );
          context.go(redirectRoute);
          return;
        }
      }

      if (_isPaymentAlreadyConfirmedError(error)) {
        if (reservation != null) {
          ref.invalidate(myReservationsProvider);
          ref.invalidate(adminReservationsProvider);
          ref.invalidate(adminReservationListProvider);
          ref.invalidate(
            reservationByIdProvider(reservation.id.toString()),
          );
          ref.read(reservationDraftProvider.notifier).state = null;
          context.go(
            '/reservation/${reservation.id.toString()}?back=home',
          );
          return;
        }
      }

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
      if (overlay != null && !overlayDismissed) {
        CriticalOperationOverlay.dismiss(overlay);
      }
      _submitting = false;
      if (mounted) {
        setState(() => processing = false);
      }
    }
  }

  Future<String?> _processOnlinePayment({
    required String reservationId,
    required String paymentMethod,
    required bool forceCashOnly,
    VoidCallback? onBeforeManualTransferDialog,
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

    final intent = await paymentRepo.createIntent(
      reservationId: parsedReservationId,
      promoCode: _appliedPromoCode,
      walletAmount: _useWallet ? _walletBalance : null,
    );
    final paymentIntentId = int.tryParse(intent.id);

    final customerPhone = _normalizedPhone ?? _customerPhoneController.text.replaceAll(RegExp(r'[^\d+]'), '');
    final confirmation = await _confirmPaymentWithRetry(
      paymentRepo: paymentRepo,
      paymentIntentId: paymentIntentId,
      reservationId: parsedReservationId,
      paymentMethod: paymentMethod,
      customerEmail: _normalizedCustomerEmail(
        ref.read(sessionControllerProvider).user?.email,
      ),
      customerPhone: customerPhone.isNotEmpty ? customerPhone : null,
    );

    if (confirmation.isConfirmed) {
      return confirmation.message;
    }

    if (confirmation.requiresManualTransfer) {
      if (!mounted) return null;
      onBeforeManualTransferDialog?.call();
      // Let the framework remove the overlay before showing the dialog
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return null;
      // The dialog handles all 3 phases internally (QR → Validating → Success/Pending)
      final confirmed = await _showManualTransferDialog(
        confirmation,
        paymentIntentId: int.tryParse(confirmation.id) ?? paymentIntentId,
        reservationId: parsedReservationId,
      );
      if (confirmed == true) {
        _paymentJustConfirmed = true;
        return context.l10n.t('checkout_payment_verified');
      }
      return context.l10n.t('checkout_payment_being_verified');
    }

    if (confirmation.requiresIzipayCheckout) {
      final checkoutOutcome = await _openIzipayCheckout(confirmation);

      // If the user completed payment in the popup, validate with backend
      if (checkoutOutcome.isCompleted &&
          checkoutOutcome.rawClientAnswer != null &&
          checkoutOutcome.hash != null &&
          checkoutOutcome.rawClientAnswer!.isNotEmpty &&
          checkoutOutcome.hash!.isNotEmpty) {
        try {
          final validationResult = await paymentRepo.validateCheckoutResult(
            krAnswer: checkoutOutcome.rawClientAnswer!,
            krHash: checkoutOutcome.hash!,
            paymentIntentId: int.tryParse(confirmation.id) ?? paymentIntentId,
            reservationId: parsedReservationId,
          );
          if (validationResult.isConfirmed) {
            _paymentJustConfirmed = true;
            return _checkoutResultMessage(checkoutOutcome) ??
                validationResult.message;
          }
          if (validationResult.isFailed) {
            throw StateError(
              _checkoutFailureMessage(
                checkoutOutcome.message,
                validationResult.status,
              ),
            );
          }
        } catch (e) {
          // Validation failed — fall through to polling as backup
          if (e is StateError) rethrow;
        }
      }

      // Fallback: poll for status (webhook may confirm it)
      final status = await _waitForPaymentFinalStatus(
        paymentIntentId: int.tryParse(confirmation.id) ?? paymentIntentId,
        reservationId: parsedReservationId,
        attempts: checkoutOutcome.isCanceled ? 4 : 18,
      );

      if (status.isConfirmed) {
        _paymentJustConfirmed = true;
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
      _paymentJustConfirmed = true;
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

  /// Confirms payment with exponential backoff retry on rate limiting (HTTP 429).
  Future<PaymentIntentResult> _confirmPaymentWithRetry({
    required PaymentRepository paymentRepo,
    int? paymentIntentId,
    int? reservationId,
    required String paymentMethod,
    String? customerEmail,
    String? customerPhone,
    int maxAttempts = 3,
  }) async {
    int attempts = 0;
    Duration backoff = const Duration(seconds: 1);

    while (true) {
      try {
        return await paymentRepo.confirmPayment(
          paymentIntentId: paymentIntentId,
          reservationId: reservationId,
          paymentMethod: paymentMethod,
          customerEmail: customerEmail,
          customerPhone: customerPhone,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          attempts++;
          if (attempts >= maxAttempts) {
            throw StateError(context.l10n.t('rate_limit_exceeded'));
          }
          await Future.delayed(backoff);
          backoff = Duration(seconds: backoff.inSeconds * 2);
        } else {
          rethrow;
        }
      }
    }
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

  /// Shows the 3-phase manual transfer dialog.
  /// Returns `true` if the payment was confirmed during the dialog,
  /// `false` / `null` if it is still pending.
  Future<bool?> _showManualTransferDialog(
    PaymentIntentResult confirmation, {
    required int? paymentIntentId,
    required int reservationId,
  }) async {
    final action = confirmation.nextAction ?? <String, dynamic>{};
    final method = (action['method']?.toString() ?? 'yape').toLowerCase();
    final phone = action['phone']?.toString() ?? '';
    final recipientName = action['recipientName']?.toString() ?? '';
    final rawQrUrl = action['qrUrl']?.toString() ?? '';
    final qrUrl = rawQrUrl.startsWith('http')
        ? rawQrUrl
        : rawQrUrl.isNotEmpty
            ? Uri.parse(AppEnv.resolvedApiBaseUrl).resolve(rawQrUrl).toString()
            : '';
    final amount = action['amount']?.toString() ?? '';
    final currency = action['currency']?.toString() ?? 'PEN';

    // Brand config per method
    final Color brandColor;
    final Color brandLight;
    final String brandName;
    final IconData brandIcon;
    final String stepVerb;
    switch (method) {
      case 'yape':
        brandColor = const Color(0xFF6B2D8B);
        brandLight = const Color(0xFFF3E8FA);
        brandName = 'Yape';
        brandIcon = Icons.qr_code_2;
        stepVerb = context.l10n.t('checkout_open_yape');
        break;
      case 'plin':
        brandColor = const Color(0xFF00BFA5);
        brandLight = const Color(0xFFE0F7F3);
        brandName = 'Plin';
        brandIcon = Icons.phone_android;
        stepVerb = context.l10n.t('checkout_open_plin');
        break;
      default:
        brandColor = const Color(0xFF1565C0);
        brandLight = const Color(0xFFE3F2FD);
        brandName = 'QR';
        brandIcon = Icons.qr_code;
        stepVerb = context.l10n.t('checkout_open_generic');
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ManualTransferDialog(
        brandColor: brandColor,
        brandLight: brandLight,
        brandName: brandName,
        brandIcon: brandIcon,
        stepVerb: stepVerb,
        recipientName: recipientName,
        phone: phone,
        qrUrl: qrUrl,
        amount: amount,
        currency: currency,
        paymentIntentId: paymentIntentId,
        reservationId: reservationId,
        waitForStatus: _waitForPaymentFinalStatus,
      ),
    );
  }

  Future<PaymentStatusResult> _waitForPaymentFinalStatus({
    required int? paymentIntentId,
    required int reservationId,
    int attempts = 12,
    int intervalSeconds = 2,
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
        await Future<void>.delayed(Duration(seconds: intervalSeconds));
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

  bool _isPreconditionError(Object error) {
    if (error is AppException) {
      return error.statusCode == 428;
    }
    if (error is DioException) {
      return error.response?.statusCode == 428;
    }
    return false;
  }

  String? _preconditionRedirectRoute(Object error) {
    String? backendCode;
    if (error is AppException && error.error.backendMessage != null) {
      backendCode = error.error.backendMessage;
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        backendCode = data['code']?.toString();
      }
    }
    if (backendCode != null) {
      if (backendCode.contains('EMAIL_NOT_VERIFIED')) {
        return '/verify-email';
      }
      if (backendCode.contains('PROFILE_COMPLETION_REQUIRED') ||
          backendCode.contains('PROFILE_INCOMPLETE')) {
        return '/profile/complete';
      }
    }
    return null;
  }

  bool _isPaymentAlreadyConfirmedError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final code = data['code']?.toString() ?? '';
        return code == 'PAYMENT_ALREADY_CONFIRMED' ||
            code == 'PAYMENT_ALREADY_PROCESSED';
      }
    }
    return false;
  }

  String _paymentHelp(BuildContext context, String method) {
    if (method == PaymentConstants.methodCard) {
      switch (_selectedDigitalSubmethod) {
        case 'yape':
          return context.l10n.t('checkout_help_yape');
        case 'plin':
          return context.l10n.t('checkout_help_plin');
        case 'qr':
          return context.l10n.t('checkout_help_qr');
        default:
          return context.l10n.t('checkout_help_card');
      }
    }
    switch (method) {
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
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          )
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    final child = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 12),
        Text(value, textAlign: TextAlign.end, style: style),
      ],
    );

    if (emphasize) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}

class _PaymentGridCard extends StatelessWidget {
  const _PaymentGridCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sublabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? scheme.onPrimaryContainer.withValues(alpha: 0.7) : scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferStep extends StatelessWidget {
  const _TransferStep({
    required this.number,
    required this.text,
    required this.brandColor,
  });

  final String number;
  final String text;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: brandColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-phase manual transfer dialog
// ─────────────────────────────────────────────────────────────────────────────

enum _TransferPhase { showQr, validating, success, pending }

typedef _WaitForStatus = Future<PaymentStatusResult> Function({
  required int? paymentIntentId,
  required int reservationId,
  int attempts,
  int intervalSeconds,
});

class _ManualTransferDialog extends StatefulWidget {
  const _ManualTransferDialog({
    required this.brandColor,
    required this.brandLight,
    required this.brandName,
    required this.brandIcon,
    required this.stepVerb,
    required this.recipientName,
    required this.phone,
    required this.qrUrl,
    required this.amount,
    required this.currency,
    required this.paymentIntentId,
    required this.reservationId,
    required this.waitForStatus,
  });

  final Color brandColor;
  final Color brandLight;
  final String brandName;
  final IconData brandIcon;
  final String stepVerb;
  final String recipientName;
  final String phone;
  final String qrUrl;
  final String amount;
  final String currency;
  final int? paymentIntentId;
  final int reservationId;
  final _WaitForStatus waitForStatus;

  @override
  State<_ManualTransferDialog> createState() => _ManualTransferDialogState();
}

class _ManualTransferDialogState extends State<_ManualTransferDialog> {
  _TransferPhase _phase = _TransferPhase.showQr;

  Future<void> _onTransferred() async {
    setState(() => _phase = _TransferPhase.validating);

    try {
      // Poll up to ~5 min (100 × 3s) for auto-confirmation
      final status = await widget.waitForStatus(
        paymentIntentId: widget.paymentIntentId,
        reservationId: widget.reservationId,
        attempts: 100,
        intervalSeconds: 3,
      );

      if (!mounted) return;
      if (status.isConfirmed) {
        setState(() => _phase = _TransferPhase.success);
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _phase = _TransferPhase.pending);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _TransferPhase.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: widget.brandColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Icon(widget.brandIcon, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.t('checkout_pay_with')} ${widget.brandName}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.currency} ${widget.amount}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body (switches per phase) ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_phase) {
                _TransferPhase.showQr => _QrPhaseBody(
                    key: const ValueKey('qr'),
                    widget: widget,
                    theme: theme,
                    l10n: l10n,
                    onTransferred: _onTransferred,
                  ),
                _TransferPhase.validating => _ValidatingPhaseBody(
                    key: const ValueKey('validating'),
                    theme: theme,
                    l10n: l10n,
                    brandName: widget.brandName,
                  ),
                _TransferPhase.success => _SuccessPhaseBody(
                    key: const ValueKey('success'),
                    theme: theme,
                    l10n: l10n,
                  ),
                _TransferPhase.pending => _PendingPhaseBody(
                    key: const ValueKey('pending'),
                    theme: theme,
                    l10n: l10n,
                    onClose: () => Navigator.of(context).pop(false),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Phase bodies ──────────────────────────────────────────────────────────────

class _QrPhaseBody extends StatelessWidget {
  const _QrPhaseBody({
    super.key,
    required this.widget,
    required this.theme,
    required this.l10n,
    required this.onTransferred,
  });

  final _ManualTransferDialog widget;
  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback onTransferred;

  String _maskPhone(String? phone) {
    if (phone == null || phone.length < 4) return '';
    return '+51 **** *** ${phone.substring(math.max(0, phone.length - 2))}';
  }

  String _getMethodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      case 'qr':
        return 'QR Wallet';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.recipientName.isNotEmpty || widget.phone.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: widget.brandLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.brandColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        if (widget.recipientName.isNotEmpty) ...[
                          Row(children: [
                            Icon(Icons.person_outline, size: 18, color: widget.brandColor),
                            const SizedBox(width: 8),
                            Text(l10n.t('checkout_recipient'),
                                style: theme.textTheme.labelSmall?.copyWith(color: widget.brandColor)),
                          ]),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(widget.recipientName,
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ],
                        if (widget.recipientName.isNotEmpty && widget.phone.isNotEmpty)
                          const SizedBox(height: 10),
                        if (widget.phone.isNotEmpty) ...[
                          Row(children: [
                            Icon(Icons.phone_outlined, size: 18, color: widget.brandColor),
                            const SizedBox(width: 8),
                            Text(l10n.t('checkout_phone_number'),
                                style: theme.textTheme.labelSmall?.copyWith(color: widget.brandColor)),
                          ]),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              widget.phone,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                // ── Payment verification details ──
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('payment_details'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PaymentDataRow(
                        label: l10n.t('amount'),
                        value: '${widget.currency} ${widget.amount}',
                        isHighlight: true,
                      ),
                      _PaymentDataRow(
                        label: l10n.t('recipient'),
                        value: widget.recipientName.isNotEmpty
                            ? widget.recipientName
                            : 'No disponible',
                      ),
                      _PaymentDataRow(
                        label: l10n.t('phone'),
                        value: _maskPhone(widget.phone),
                      ),
                      _PaymentDataRow(
                        label: l10n.t('method'),
                        value: _getMethodLabel(widget.brandName),
                      ),
                    ],
                  ),
                ),
                if (widget.qrUrl.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.qrUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => SizedBox(
                          width: 200,
                          height: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(l10n.t('checkout_qr_load_failed'), style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.t('checkout_transfer_steps_title'),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _TransferStep(number: '1', text: widget.stepVerb, brandColor: widget.brandColor),
                      const SizedBox(height: 8),
                      _TransferStep(
                          number: '2',
                          text: '${l10n.t('checkout_transfer_step2')} ${widget.currency} ${widget.amount}',
                          brandColor: widget.brandColor),
                      const SizedBox(height: 8),
                      _TransferStep(
                          number: '3',
                          text: l10n.t('checkout_transfer_step3'),
                          brandColor: widget.brandColor),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.schedule, color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.t('checkout_transfer_notice'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.amber.shade900, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onTransferred,
              style: FilledButton.styleFrom(
                backgroundColor: widget.brandColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l10n.t('checkout_transfer_done'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ValidatingPhaseBody extends StatelessWidget {
  const _ValidatingPhaseBody({
    super.key,
    required this.theme,
    required this.l10n,
    required this.brandName,
  });

  final ThemeData theme;
  final AppLocalizations l10n;
  final String brandName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 24),
          Text(
            '${l10n.t('checkout_validating_transfer')} $brandName...',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('checkout_validating_transfer_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat('HH:mm:ss').format(DateTime.now()),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPhaseBody extends StatelessWidget {
  const _SuccessPhaseBody({super.key, required this.theme, required this.l10n});

  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
          const SizedBox(height: 20),
          Text(
            l10n.t('checkout_payment_confirmed_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.green.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('checkout_payment_confirmed_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PendingPhaseBody extends StatelessWidget {
  const _PendingPhaseBody({
    super.key,
    required this.theme,
    required this.l10n,
    required this.onClose,
  });

  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_outlined,
              size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 20),
          Text(
            l10n.t('checkout_transfer_pending_title'),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('checkout_transfer_pending_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onClose,
              child: Text(l10n.t('checkout_view_reservation')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _PaymentDataRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: isHighlight
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: TravelBoxBrand.primaryBlue,
                  )
                : Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
