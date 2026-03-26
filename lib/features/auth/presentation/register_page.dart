import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/form_validators.dart';
import '../../../shared/utils/country_catalog.dart';
import 'auth_controller.dart';
import 'widgets/auth_ui.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(text: '+51');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _nationality = 'Peru';
  String _preferredLanguage = 'es';
  bool _termsAccepted = false;
  bool _showValidation = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  String _getDefaultLanguageForCountry(String country) {
    final countryInfo = resolveCountryDialingByName(country);
    return countryInfo.defaultLanguage;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;
    final responsive = context.responsive;
    final titleSize = responsive.adaptiveFont(
      mobileSmall: 30,
      mobile: 33,
      tablet: 35,
      desktopSmall: 37,
      desktop: 38,
    );
    final headlineColor = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF2948B0);
    final descriptionColor = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : Colors.black.withValues(alpha: 0.35);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      final success = previous?.isLoading == true && next.hasValue;
      final failed = previous?.isLoading == true && next.hasError;
      if (success) {
        final session = ref.read(sessionControllerProvider);
        if (session.needsEmailVerification) {
          context.go('/verify-email');
        } else if (session.needsOnboarding) {
          context.go('/onboarding');
        } else if (session.needsProfileCompletion) {
          context.go('/profile/complete');
        } else {
          context.go('/discovery');
        }
      }
      if (failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.t('register_failed')}: '
              '${AppErrorFormatter.readable(next.error!, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}',
            ),
          ),
        );
      }
    });

    return AuthSplitScaffold(
      heroLabel: 'TravelBox',
      heroTitle: context.l10n.t('register_hero_title'),
      heroSubtitle: context.l10n.t('register_hero_subtitle'),
      showGuardianBear: false,
      formChild: Form(
        key: _formKey,
        autovalidateMode: _showValidation
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isMobile)
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: TravelBoxBrand.brandGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    l10n.t('app_name').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            if (isMobile) const SizedBox(height: 12),
            Text(
              l10n.t('register_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: headlineColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('register_description'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: descriptionColor,
                height: 1.35,
                fontSize: responsive.isMobile ? 12.8 : 13,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: authState.isLoading
                    ? null
                    : () => context.go('/login'),
                child: Text(l10n.t('have_account')),
              ),
            ),
            _twoColumn(
              _textLineField(
                controller: _firstNameController,
                hint: l10n.t('first_name'),
                validator: (value) => FormValidators.requiredText(
                  value,
                  label: l10n.t('first_name').toLowerCase(),
                ),
              ),
              _textLineField(
                controller: _lastNameController,
                hint: l10n.t('last_name'),
                validator: (value) => FormValidators.requiredText(
                  value,
                  label: l10n.t('last_name').toLowerCase(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _textLineField(
              controller: _emailController,
              hint: l10n.t('email_hint'),
              validator: FormValidators.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            _textLineField(
              controller: _phoneController,
              hint: l10n.t('phone_hint'),
              validator: _phoneValidator,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _twoColumn(
              _dropdownLineField(
                value: _nationality,
                hint: l10n.t('nationality'),
                items: [
                  DropdownMenuItem(
                    value: 'Peru',
                    child: Text(context.l10n.t('peru')),
                  ),
                  DropdownMenuItem(
                    value: 'Argentina',
                    child: Text(context.l10n.t('argentina')),
                  ),
                  DropdownMenuItem(
                    value: 'Chile',
                    child: Text(context.l10n.t('chile')),
                  ),
                  DropdownMenuItem(
                    value: 'Colombia',
                    child: Text(context.l10n.t('colombia')),
                  ),
                  DropdownMenuItem(
                    value: 'Mexico',
                    child: Text(context.l10n.t('mexico')),
                  ),
                  DropdownMenuItem(
                    value: 'USA',
                    child: Text(context.l10n.t('usa')),
                  ),
                  DropdownMenuItem(
                    value: 'Other',
                    child: Text(context.l10n.t('otra')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _nationality = value;
                      if (value != 'Other') {
                        _preferredLanguage = _getDefaultLanguageForCountry(
                          value,
                        );
                      }
                    });
                  }
                },
              ),
              _dropdownLineField(
                value: _preferredLanguage,
                hint: l10n.t('app_language'),
                items: [
                  DropdownMenuItem(
                    value: 'es',
                    child: Text(context.l10n.t('espanol')),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(context.l10n.t('english')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _preferredLanguage = value);
                  }
                },
              ),
            ),
            SizedBox(height: 10),
            _textLineField(
              controller: _passwordController,
              hint: l10n.t('password_hint'),
              validator: FormValidators.strongPassword,
              obscureText: !_passwordVisible,
              suffixIcon: IconButton(
                tooltip: _passwordVisible
                    ? l10n.t('hide_password')
                    : l10n.t('show_password'),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _textLineField(
              controller: _confirmPasswordController,
              hint: l10n.t('confirm_password'),
              obscureText: !_confirmPasswordVisible,
              suffixIcon: IconButton(
                tooltip: _confirmPasswordVisible
                    ? l10n.t('hide_password')
                    : l10n.t('show_password'),
                onPressed: () => setState(
                  () => _confirmPasswordVisible = !_confirmPasswordVisible,
                ),
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: (value) => FormValidators.confirmPassword(
                value,
                _passwordController.text,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: authState.isLoading
                      ? null
                      : (value) =>
                            setState(() => _termsAccepted = value ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: _AcceptTermsLabel(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AuthStripeButton(
              onPressed: authState.isLoading ? null : _submit,
              icon: Icons.how_to_reg_outlined,
              label: authState.isLoading
                  ? l10n.t('register_loading')
                  : l10n.t('register_action'),
              filled: true,
            ),
            const SizedBox(height: 10),
            AuthStripeButton(
              onPressed: authState.isLoading
                  ? null
                  : () => context.go('/login'),
              icon: Icons.login_outlined,
              label: l10n.t('have_account'),
              filled: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _textLineField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return AuthLineField(
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: AuthUi.lineFieldDecoration(
          hint,
        ).copyWith(suffixIcon: suffixIcon),
      ),
    );
  }

  Widget _dropdownLineField({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return AuthLineField(
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        decoration: AuthUi.lineFieldDecoration(hint),
      ),
    );
  }

  Widget _twoColumn(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(children: [left, const SizedBox(height: 10), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  String? _phoneValidator(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return context.l10n.t('invalid_phone');
    }
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(raw)) {
      return context.l10n.t('phone_international_format');
    }
    return null;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !_termsAccepted) {
      setState(() => _showValidation = true);
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('terms_required'))),
        );
      }
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .register(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
          nationality: _nationality,
          preferredLanguage: _preferredLanguage,
          phone: _phoneController.text.trim(),
          termsAccepted: _termsAccepted,
        );
  }
}

class _AcceptTermsLabel extends StatelessWidget {
  const _AcceptTermsLabel();

  @override
  Widget build(BuildContext context) {
    return Text(context.l10n.t('accept_terms'));
  }
}
