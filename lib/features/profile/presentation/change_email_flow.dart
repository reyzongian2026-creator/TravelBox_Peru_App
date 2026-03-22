import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

class ChangeEmailFlowPage extends ConsumerStatefulWidget {
  const ChangeEmailFlowPage({super.key});

  @override
  ConsumerState<ChangeEmailFlowPage> createState() => _ChangeEmailFlowPageState();
}

class _ChangeEmailFlowPageState extends ConsumerState<ChangeEmailFlowPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isInitiateStep = true;
  bool _isLoading = false;
  String? _maskedEmail;
  DateTime? _expiresAt;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initiateEmailChange() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/email-change/initiate',
        data: {
          'newEmail': _emailController.text.trim(),
          'currentPassword': _passwordController.text,
        },
      );

      final data = response.data;
      if (data != null) {
        setState(() {
          _maskedEmail = data['maskedNewEmail'] as String?;
          _expiresAt = data['expiresAt'] != null
              ? DateTime.tryParse(data['expiresAt'] as String)
              : null;
          _isInitiateStep = false;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = _extractErrorMessage(e);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyEmailChange() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      await dio.post<Map<String, dynamic>>(
        '/auth/email-change/verify',
        data: {
          'email': _emailController.text.trim(),
          'verificationCode': _codeController.text.trim(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.t('email_change_success')),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = _extractErrorMessage(e);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return AppException.fromDioError(e).message;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final responsive = context.responsive;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isInitiateStep
              ? l10n.t('email_change_title')
              : l10n.t('email_change_verify_title'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.isMobile ? double.infinity : 400),
            child: SingleChildScrollView(
              padding: responsive.pageInsets(top: 24, bottom: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      _isInitiateStep ? Icons.email_outlined : Icons.verified_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isInitiateStep
                          ? l10n.t('email_change_subtitle')
                          : l10n.t('email_change_verify_subtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (_maskedEmail != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.email, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _maskedEmail!,
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_expiresAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.t('expires_at')}: ${_formatExpiry(_expiresAt!)}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.t('new_email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: _isInitiateStep,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.t('field_required');
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return l10n.t('invalid_email');
                        }
                        return null;
                      },
                    ),
                    if (_isInitiateStep) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: l10n.t('current_password'),
                          prefixIcon: const Icon(Icons.lock_outlined),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.t('field_required');
                          }
                          if (value.length < 8) {
                            return l10n.t('password_min_length');
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _initiateEmailChange(),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: l10n.t('verification_code'),
                          prefixIcon: const Icon(Icons.confirmation_number_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.t('field_required');
                          }
                          if (value.trim().length != 6) {
                            return l10n.t('code_must_be_6_digits');
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _verifyEmailChange(),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading
                          ? null
                          : (_isInitiateStep
                              ? _initiateEmailChange
                              : _verifyEmailChange),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isInitiateStep
                                  ? l10n.t('send_verification_code')
                                  : l10n.t('verify_and_change_email'),
                            ),
                    ),
                    if (!_isInitiateStep) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _isInitiateStep = true;
                                  _maskedEmail = null;
                                  _expiresAt = null;
                                  _codeController.clear();
                                  _errorMessage = null;
                                });
                              },
                        child: Text(l10n.t('cancel_and_start_over')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatExpiry(DateTime expiry) {
    return '${expiry.day}/${expiry.month}/${expiry.year} ${expiry.hour}:${expiry.minute.toString().padLeft(2, '0')}';
  }
}
