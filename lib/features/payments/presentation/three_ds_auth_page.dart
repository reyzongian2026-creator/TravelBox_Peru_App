import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/app_back_button.dart';
import '../data/payment_repository.dart';

/// Page shown when a payment requires 3D Secure authentication.
///
/// Opens the authentication URL in an external browser and polls the
/// backend for payment status until confirmed or failed.
class ThreeDsAuthPage extends ConsumerStatefulWidget {
  const ThreeDsAuthPage({
    super.key,
    required this.paymentIntentId,
    required this.reservationId,
    required this.authUrl,
  });

  final String paymentIntentId;
  final String reservationId;
  final String authUrl;

  @override
  ConsumerState<ThreeDsAuthPage> createState() => _ThreeDsAuthPageState();
}

class _ThreeDsAuthPageState extends ConsumerState<ThreeDsAuthPage>
    with WidgetsBindingObserver {
  bool _launched = false;
  bool _polling = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _launchAuthUrl();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns to the app after completing 3DS in the browser,
    // start polling for the payment result.
    if (state == AppLifecycleState.resumed && _launched && !_polling) {
      _startPolling();
    }
  }

  Future<void> _launchAuthUrl() async {
    final uri = Uri.tryParse(widget.authUrl);
    if (uri == null) {
      setState(() => _error = 'URL de autenticación inválida.');
      return;
    }

    // Only allow trusted payment provider domains
    final host = uri.host.toLowerCase();
    final allowedDomains = [
      'izipay.pe',
      'api.micuentaweb.pe',
      'secure.micuentaweb.pe',
      'static.micuentaweb.pe',
      'api.inkavoy.pe',
    ];
    final isTrusted = allowedDomains.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    );
    if (!isTrusted) {
      setState(() => _error = 'Dominio de autenticación no permitido.');
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        setState(() => _error = 'No se pudo abrir el navegador.');
        return;
      }
      setState(() => _launched = true);
    } catch (e) {
      setState(() => _error = 'Error al abrir el navegador: $e');
    }
  }

  void _startPolling() {
    if (_polling) return;
    setState(() => _polling = true);

    // Poll every 3 seconds, up to 60 attempts (3 minutes).
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      if (attempts > 60) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _polling = false;
            _error = 'Tiempo de espera agotado. Verifica el estado de tu pago.';
          });
        }
        return;
      }

      try {
        final paymentRepo = ref.read(paymentRepositoryProvider);
        final intentId = int.tryParse(widget.paymentIntentId);
        final status = await paymentRepo.getPaymentStatus(
          paymentIntentId: intentId,
        );

        if (!mounted) {
          timer.cancel();
          return;
        }

        if (status.isConfirmed) {
          timer.cancel();
          context.go('/reservation/${widget.reservationId}?back=home');
          return;
        }

        if (status.isFailed) {
          timer.cancel();
          setState(() {
            _polling = false;
            _error = 'El pago fue rechazado después de la autenticación.';
          });
          return;
        }
      } catch (_) {
        // Keep polling on transient errors.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(
          fallbackRoute: '/reservation/${widget.reservationId}',
        ),
        title: Text(context.l10n.locale.languageCode == 'en'
            ? '3D Secure Authentication'
            : 'Autenticación 3D Secure'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _launchAuthUrl();
                  },
                  child: Text(context.l10n.locale.languageCode == 'en'
                      ? 'Retry'
                      : 'Reintentar'),
                ),
              ] else if (_polling) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  context.l10n.locale.languageCode == 'en'
                      ? 'Verifying payment...'
                      : 'Verificando pago...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.locale.languageCode == 'en'
                      ? 'Please wait while we confirm your payment.'
                      : 'Espera mientras confirmamos tu pago.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ] else ...[
                const Icon(Icons.open_in_browser, size: 56),
                const SizedBox(height: 16),
                Text(
                  context.l10n.locale.languageCode == 'en'
                      ? 'Complete the verification in your browser'
                      : 'Completa la verificación en tu navegador',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.locale.languageCode == 'en'
                      ? 'Return to this screen after completing the 3D Secure step.'
                      : 'Regresa a esta pantalla después de completar el paso 3D Secure.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _startPolling,
                  child: Text(context.l10n.locale.languageCode == 'en'
                      ? 'I completed the verification'
                      : 'Ya completé la verificación'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _launchAuthUrl,
                  child: Text(context.l10n.locale.languageCode == 'en'
                      ? 'Open browser again'
                      : 'Abrir navegador de nuevo'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
