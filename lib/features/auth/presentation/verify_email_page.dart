import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/widgets/travelbox_logo.dart';
import '../data/auth_repository_impl.dart';
import 'widgets/auth_ui.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;

    return AuthPageScaffold(
      maxWidth: 600,
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TravelBoxLogo(compact: true, showSubtitle: false),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _loading ? null : _exitToLogin,
                  tooltip: l10n.t('verify_email_back_tooltip'),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.t('verify_email_title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF102A43),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              user?.email ?? l10n.t('pending_email'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(l10n.t('verify_email_description')),
            if (session.pendingVerificationCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  '${l10n.t('verify_email_mock_code_prefix')}: '
                  '${session.pendingVerificationCode}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: l10n.t('verification_code'),
              ),
            ),
            const SizedBox(height: 14),
            AuthStripeButton(
              onPressed: _loading ? null : _verify,
              icon: Icons.verified_outlined,
              label: _loading ? l10n.t('verifying') : l10n.t('verify_code'),
              filled: true,
            ),
            const SizedBox(height: 10),
            AuthStripeButton(
              onPressed: _loading ? null : _resend,
              icon: Icons.mark_email_read_outlined,
              label: l10n.t('resend_code'),
              filled: false,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().isEmpty) {
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyEmail(
            code: _codeController.text.trim(),
            email: ref.read(sessionControllerProvider).user?.email,
          );
      await ref.read(sessionControllerProvider.notifier).markEmailVerified();
      final session = ref.read(sessionControllerProvider);
      if (!mounted) return;
      if (session.needsOnboarding) {
        context.go('/onboarding');
      } else if (session.needsProfileCompletion) {
        context.go('/profile/complete');
      } else {
        context.go('/discovery');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('verify_email_verify_failed_prefix')}: '
            '${AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .resendVerification();
      final user = ref.read(sessionControllerProvider).user;
      if (user != null) {
        await ref
            .read(sessionControllerProvider.notifier)
            .updateUser(
              user.copyWith(emailVerified: result.emailVerified),
              pendingVerificationCode: result.verificationCodePreview,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('verify_email_resend_failed_prefix')}: '
            '${AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exitToLogin() async {
    await ref.read(sessionControllerProvider.notifier).signOut();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }
}
