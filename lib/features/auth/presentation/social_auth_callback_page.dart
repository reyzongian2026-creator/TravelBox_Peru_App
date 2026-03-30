import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/app_user.dart';
import '../../../shared/state/session_controller.dart';

class SocialAuthCallbackPage extends ConsumerStatefulWidget {
  const SocialAuthCallbackPage({super.key});

  @override
  ConsumerState<SocialAuthCallbackPage> createState() =>
      _SocialAuthCallbackPageState();
}

class _SocialAuthCallbackPageState
    extends ConsumerState<SocialAuthCallbackPage> {
  String? _error;
  bool _processing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  Future<void> _handleCallback() async {
    final uri = Uri.base;
    final payload = uri.queryParameters['payload']?.trim();
    final error = uri.queryParameters['error']?.trim();
    if (!mounted) return;

    if (error != null && error.isNotEmpty) {
      setState(() {
        _processing = false;
        _error = error;
      });
      return;
    }

    if (payload == null || payload.isEmpty) {
      setState(() {
        _processing = false;
        _error = 'No se recibio una sesion valida desde el proveedor social.';
      });
      return;
    }

    try {
      final decoded = _decodePayload(payload);
      final accessToken = decoded['accessToken']?.toString().trim() ?? '';
      final refreshToken = decoded['refreshToken']?.toString().trim() ?? '';
      final rawUser = decoded['user'];
      if (accessToken.isEmpty || refreshToken.isEmpty || rawUser is! Map) {
        throw const FormatException('Missing session fields');
      }

      final user = AppUser.fromJson(
        Map<String, dynamic>.from(rawUser),
      );

      await ref.read(sessionControllerProvider.notifier).signIn(
            user: user,
            accessToken: accessToken,
            refreshToken: refreshToken,
            pendingVerificationCode:
                decoded['verificationCodePreview']?.toString(),
          );
      if (!mounted) return;
      context.go(_postAuthRoute(ref.read(sessionControllerProvider)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'No se pudo completar el inicio de sesion social.';
      });
    }
  }

  Map<String, dynamic> _decodePayload(String payload) {
    final normalized = switch (payload.length % 4) {
      2 => '$payload==',
      3 => '$payload=',
      _ => payload,
    };
    final bytes = base64Url.decode(normalized);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  String _postAuthRoute(SessionState session) {
    if (session.needsEmailVerification) return '/verify-email';
    if (session.needsOnboarding) return '/onboarding';
    if (session.needsProfileCompletion) return '/profile/complete';
    if (session.isAdmin) return '/admin/dashboard';
    if (session.isSupport) return '/support/incidents';
    if (session.canAccessAdmin) return '/operator/panel';
    if (session.isCourier) return '/courier/panel';
    return '/discovery';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_processing) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'Completando inicio de sesion social...',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'No se pudo iniciar sesion.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Volver al inicio de sesion'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
