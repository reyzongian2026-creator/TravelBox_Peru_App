import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/form_validators.dart';
import '../../../shared/widgets/travelbox_logo.dart';
import '../data/auth_repository_impl.dart';
import 'widgets/auth_ui.dart';

class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({super.key});

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _requestFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _codeRequested = false;
  bool _newPasswordVisible = false;
  bool _confirmNewPasswordVisible = false;
  String? _resetCodePreview;
  String? _expiresAt;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthPageScaffold(
      maxWidth: 620,
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
                  onPressed: _loading ? null : () => context.go('/login'),
                  tooltip: l10n.t('back'),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.t('reset_password_title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF102A43),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('reset_password_description'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Form(
              key: _requestFormKey,
              child: TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: l10n.t('email')),
                keyboardType: TextInputType.emailAddress,
                validator: FormValidators.email,
              ),
            ),
            const SizedBox(height: 12),
            AuthStripeButton(
              onPressed: _loading ? null : _requestCode,
              icon: Icons.mark_email_read_outlined,
              label: _loading
                  ? l10n.t('processing')
                  : l10n.t('send_reset_code'),
              filled: true,
            ),
            if (_resetCodePreview != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  '${l10n.t('mock_code')}: $_resetCodePreview',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            if (_expiresAt != null) ...[
              const SizedBox(height: 6),
              Text('${l10n.t('expires')}: $_expiresAt'),
            ],
            if (_codeRequested) ...[
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),
              Form(
                key: _confirmFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: l10n.t('reset_code'),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return l10n.t('password_reset_code_required');
                        }
                        if (text.length < 4) {
                          return l10n.t('invalid_code');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: l10n.t('new_password'),
                        suffixIcon: IconButton(
                          tooltip: _newPasswordVisible
                              ? l10n.t('hide_password')
                              : l10n.t('show_password'),
                          onPressed: () => setState(
                            () => _newPasswordVisible = !_newPasswordVisible,
                          ),
                          icon: Icon(
                            _newPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      obscureText: !_newPasswordVisible,
                      validator: FormValidators.strongPassword,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: l10n.t('confirm_new_password'),
                        suffixIcon: IconButton(
                          tooltip: _confirmNewPasswordVisible
                              ? l10n.t('hide_password')
                              : l10n.t('show_password'),
                          onPressed: () => setState(
                            () => _confirmNewPasswordVisible =
                                !_confirmNewPasswordVisible,
                          ),
                          icon: Icon(
                            _confirmNewPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      obscureText: !_confirmNewPasswordVisible,
                      validator: (value) => FormValidators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AuthStripeButton(
                      onPressed: _loading ? null : _confirmReset,
                      icon: Icons.lock_reset_outlined,
                      label: _loading
                          ? l10n.t('updating')
                          : l10n.t('update_password'),
                      filled: true,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            AuthStripeButton(
              onPressed: _loading ? null : () => context.go('/login'),
              icon: Icons.login_outlined,
              label: l10n.t('back_to_login'),
              filled: false,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestCode() async {
    final valid = _requestFormKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: _emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        _resetCodePreview = result.resetCodePreview;
        _expiresAt = result.expiresAtIso;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('send_code_failed')}: '
            '${AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    final valid = _confirmFormKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('update_failed')}: '
            '${AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
