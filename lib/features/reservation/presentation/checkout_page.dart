import 'dart:async';

import 'package:dio/dio.dart';
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
import '../../../shared/utils/app_error.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/widgets/critical_operation_overlay.dart';
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

  String? _selectedDigitalSubmethod; // card, yape, plin, qr — for display only

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
                    'Elige tu metodo de pago',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selecciona como deseas pagar tu reserva',
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
                      'PAGO DIGITAL',
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
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        _PaymentGridCard(
                          icon: Icons.credit_card,
                          label: 'Tarjeta',
                          sublabel: 'Visa / MC',
                          selected: selectedPaymentMethod == PaymentConstants.methodCard && _selectedDigitalSubmethod != 'yape' && _selectedDigitalSubmethod != 'plin' && _selectedDigitalSubmethod != 'qr',
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodCard; _selectedDigitalSubmethod = 'card'; }),
                        ),
                        _PaymentGridCard(
                          icon: Icons.qr_code_2,
                          label: 'Yape',
                          sublabel: 'QR Yape',
                          selected: _selectedDigitalSubmethod == 'yape',
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodCard; _selectedDigitalSubmethod = 'yape'; }),
                        ),
                        _PaymentGridCard(
                          icon: Icons.phone_android,
                          label: 'Plin',
                          sublabel: 'Billetera',
                          selected: _selectedDigitalSubmethod == 'plin',
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodCard; _selectedDigitalSubmethod = 'plin'; }),
                        ),
                        _PaymentGridCard(
                          icon: Icons.qr_code,
                          label: 'QR',
                          sublabel: 'Universal',
                          selected: _selectedDigitalSubmethod == 'qr',
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodCard; _selectedDigitalSubmethod = 'qr'; }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PAGO PRESENCIAL',
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
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        _PaymentGridCard(
                          icon: Icons.storefront_outlined,
                          label: 'Mostrador',
                          sublabel: 'En el local',
                          selected: selectedPaymentMethod == PaymentConstants.methodCounter,
                          onTap: () => setState(() { paymentMethod = PaymentConstants.methodCounter; _selectedDigitalSubmethod = null; }),
                        ),
                        _PaymentGridCard(
                          icon: Icons.payments_outlined,
                          label: 'Efectivo',
                          sublabel: 'Al llegar',
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
              color: Colors.black.withOpacity(0.08),
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
                      : 'Continuar compra',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmPayment({
    required dynamic user,
    required dynamic draft,
    required String selectedPaymentMethod,
    required bool forceCashOnly,
  }) async {
    setState(() => processing = true);
    OverlayEntry? overlay;
    dynamic reservation;
    try {
      if (context.mounted) {
        overlay = CriticalOperationOverlay.show(
          context,
          message: 'Procesando tu pago...',
          submessage: 'Esto puede tardar unos segundos',
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
      if (overlay != null) {
        CriticalOperationOverlay.dismiss(overlay);
      }
      if (mounted) {
        setState(() => processing = false);
      }
    }
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
          return 'Se abrira el checkout de Izipay donde podras escanear el codigo QR con tu app de Yape.';
        case 'plin':
          return 'Se abrira el checkout de Izipay donde podras completar tu pago con Plin.';
        case 'qr':
          return 'Se abrira el checkout de Izipay donde podras escanear un QR con cualquier app bancaria.';
        default:
          return 'Se abrira el checkout seguro de Izipay donde podras ingresar los datos de tu tarjeta.';
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sublabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.onPrimaryContainer.withOpacity(0.7) : scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
