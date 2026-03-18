import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/payment_constants.dart';
import '../../../core/env/app_env.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../shared/state/session_controller.dart';
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
                '${draft.bagCount} bultos, tamano ${draft.size}\n'
                'Recojo: ${draft.pickupRequested ? 'Si' : 'No'} - Entrega: ${draft.dropoffRequested ? 'Si' : 'No'} - Seguro: ${draft.extraInsurance ? 'Si' : 'No'}',
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
                        'Pagos digitales temporalmente deshabilitados. El operador validara el cobro manualmente.',
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
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (!forceCashOnly &&
                      (selectedPaymentMethod == PaymentConstants.methodCard ||
                          selectedPaymentMethod ==
                              PaymentConstants.methodYape)) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sourceTokenController,
                      decoration: const InputDecoration(
                        labelText: 'sourceTokenId (Culqi, obligatorio)',
                        hintText: 'tkn_test_xxx',
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
                      decoration: const InputDecoration(
                        labelText: 'Email cliente (opcional)',
                        hintText: 'cliente@correo.com',
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
                'Almacenaje S/${draft.storageSubtotal().toStringAsFixed(2)} '
                '+ Recojo S/${draft.pickupCost().toStringAsFixed(2)} '
                '+ Entrega S/${draft.dropoffCost().toStringAsFixed(2)} '
                '+ Seguro S/${draft.insuranceCost().toStringAsFixed(2)}',
              ),
              trailing: Text(
                'S/${draft.estimatePrice().toStringAsFixed(2)}',
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
                  subtitle: const Text(
                    'Tu pago quedara PENDING hasta que cajero u operador lo apruebe en el panel de cobros.',
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
                        const SnackBar(
                          content: Text(
                            'Para tarjeta o Yape debes enviar un sourceTokenId valido antes de confirmar.',
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
                          content: Text('No se pudo procesar pago: $message'),
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
            child: Text(processing ? 'Procesando...' : 'Confirmar pago'),
          ),
        ],
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final backendMessage = data['message']?.toString();
        if (backendMessage != null && backendMessage.trim().isNotEmpty) {
          return backendMessage.trim();
        }
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }
    return error.toString();
  }

  bool _isOfflinePaymentMethod(String method) {
    return PaymentConstants.isOffline(method);
  }

  String _paymentHeadline(String method) {
    if (_isOfflinePaymentMethod(method)) {
      return 'Pago presencial con validacion manual';
    }
    return 'Pago inmediato para habilitar el QR';
  }

  String _paymentHelp(String method) {
    switch (method) {
      case PaymentConstants.methodCard:
        return 'Tarjeta confirma el pago en linea y habilita el QR de check-in. Requiere sourceTokenId de Culqi.';
      case PaymentConstants.methodYape:
        return 'Yape confirma el pago en linea y habilita el QR de check-in. Requiere sourceTokenId de Culqi.';
      case PaymentConstants.methodWallet:
        return 'Wallet/Plin deja la reserva confirmada sin pasar por caja.';
      case PaymentConstants.methodCounter:
        return 'Debes pagar en el almacen y esperar aprobacion del encargado.';
      case PaymentConstants.methodCash:
        return 'Debes entregar efectivo y el operador validara el cobro desde su panel.';
      default:
        return 'Selecciona un metodo para continuar.';
    }
  }
}


