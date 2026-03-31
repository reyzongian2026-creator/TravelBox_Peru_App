import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../data/auth_repository_impl.dart';
import '../data/social_callback_url_cleaner.dart';
import 'widgets/auth_ui.dart';

class CompleteSocialEmailPage extends ConsumerStatefulWidget {
  const CompleteSocialEmailPage({super.key});

  @override
  ConsumerState<CompleteSocialEmailPage> createState() =>
      _CompleteSocialEmailPageState();
}

class _CompleteSocialEmailPageState
    extends ConsumerState<CompleteSocialEmailPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _sendingCode = false;
  bool _verifying = false;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionControllerProvider).user;
    final pendingRealEmail = user?.pendingRealEmail ?? '';
    final currentEmail = user?.email ?? '';
    if (pendingRealEmail.trim().isNotEmpty) {
      _emailController.text = pendingRealEmail;
      _codeSent = true;
    } else if (!currentEmail.toLowerCase().endsWith('@social.inkavoy.pe')) {
      _emailController.text = currentEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);

    return AuthSplitScaffold(
      heroLabel: 'InkaVoy',
      heroTitle: 'CONFIRMA TU CORREO',
      heroSubtitle:
          'Necesitamos un correo real para verificar tu cuenta de Facebook y continuar con tu experiencia.',
      showGuardianBear: false,
      showHeroIllustration: false,
      heroAnimation: 'idle',
      formChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No encontramos un correo oficial en tu cuenta de Facebook.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Registra tu correo para recibir un codigo de verificacion y poder continuar al tutorial.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF52606D),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD9E2EC)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF3867F4)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu cuenta seguira vinculada a Facebook, pero el correo temporal no se usara como correo principal. Registra aqui el correo real con el que deseas continuar.',
                    style: const TextStyle(
                      color: Color(0xFF334E68),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _emailController,
            enabled: !_codeSent && !_sendingCode && !_verifying,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electronico',
              hintText: 'tu@correo.com',
            ),
          ),
          const SizedBox(height: 14),
          AuthStripeButton(
            onPressed: (_sendingCode || _verifying) ? null : _requestCode,
            icon: Icons.mark_email_read_outlined,
            label: _sendingCode ? 'Enviando codigo...' : 'Enviar codigo',
            filled: true,
          ),
          if (_codeSent) ...[
            const SizedBox(height: 18),
            TextField(
              controller: _codeController,
              enabled: !_verifying,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Codigo de verificacion',
                hintText: 'Ingresa el codigo recibido',
                counterText: '',
              ),
            ),
            if (session.pendingVerificationCode?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  'Codigo visible para pruebas: ${session.pendingVerificationCode}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 14),
            AuthStripeButton(
              onPressed: _verifying ? null : _verifyCode,
              icon: Icons.verified_outlined,
              label: _verifying ? 'Verificando...' : 'Verificar codigo',
              filled: true,
            ),
            const SizedBox(height: 10),
            AuthStripeButton(
              onPressed: (_sendingCode || _verifying) ? null : _resendCode,
              icon: Icons.refresh_outlined,
              label: 'Reenviar codigo',
              filled: false,
            ),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: (_sendingCode || _verifying) ? null : _signOut,
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showError('Ingresa un correo valido para continuar.');
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestRealEmailCompletion(email: email);
      final currentUser = ref.read(sessionControllerProvider).user;
      if (currentUser != null) {
        await ref
            .read(sessionControllerProvider.notifier)
            .updateUser(
              currentUser.copyWith(
                emailVerified: false,
                requiresRealEmailCompletion: true,
                pendingRealEmail: email,
              ),
              pendingVerificationCode: result.verificationCodePreview,
            );
      }
      if (!mounted) return;
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      _showError(_readable(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError('Ingresa el codigo de 6 digitos.');
      return;
    }

    setState(() => _verifying = true);
    try {
      await ref.read(authRepositoryProvider).verifyEmail(code: code);
      await ref.read(sessionControllerProvider.notifier).markEmailVerified();
      if (!mounted) return;
      context.go(_postCompleteRoute(ref.read(sessionControllerProvider)));
    } catch (error) {
      _showError(_readable(error));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _sendingCode = true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .resendVerification();
      final currentUser = ref.read(sessionControllerProvider).user;
      if (currentUser != null) {
        await ref
            .read(sessionControllerProvider.notifier)
            .updateUser(
              currentUser,
              pendingVerificationCode: result.verificationCodePreview,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      _showError(_readable(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _signOut() async {
    await clearSocialCallbackUrl(route: '/login');
    await ref.read(sessionControllerProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  String _postCompleteRoute(SessionState session) {
    if (session.needsRealEmailCompletion) return '/complete-social-email';
    if (session.needsEmailVerification) return '/verify-email';
    if (session.needsOnboarding) return '/onboarding';
    if (session.needsProfileCompletion) return '/profile/complete';
    if (session.isAdmin) return '/admin/dashboard';
    if (session.isSupport) return '/support/incidents';
    if (session.canAccessAdmin) return '/operator/panel';
    if (session.isCourier) return '/courier/panel';
    return '/discovery';
  }

  bool _isValidEmail(String value) {
    return value.contains('@') && value.contains('.') && !value.endsWith('@');
  }

  String _readable(Object error) {
    return AppErrorFormatter.readable(
      error,
      (String key, {Map<String, dynamic>? params}) => key,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
