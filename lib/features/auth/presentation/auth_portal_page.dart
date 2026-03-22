import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env/app_env.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/form_validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_ui.dart';
import 'widgets/auth_teddy_animation.dart';

enum AuthPortalMode { login, register }

enum _AccessMode { client, internal }

class AuthPortalPage extends ConsumerStatefulWidget {
  const AuthPortalPage({super.key, this.initialMode = AuthPortalMode.login});
  final AuthPortalMode initialMode;

  @override
  ConsumerState<AuthPortalPage> createState() => _AuthPortalPageState();
}

class _AuthPortalPageState extends ConsumerState<AuthPortalPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _loginEmailFocusNode = FocusNode();
  final _loginPasswordFocusNode = FocusNode();

  late _AccessMode _accessMode;
  bool _showValidation = false;
  bool _keepSignedIn = true;
  bool _loginPasswordVisible = false;
  String _teddyAnimation = 'idle';
  double _teddyLookOffsetX = -1;
  Timer? _animationResetTimer;

  @override
  void initState() {
    super.initState();
    _accessMode = _AccessMode.internal;
    _loginEmailFocusNode.addListener(_syncTeddyFromFocus);
    _loginPasswordFocusNode.addListener(_syncTeddyFromFocus);
  }

  @override
  void dispose() {
    _animationResetTimer?.cancel();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _loginEmailFocusNode.dispose();
    _loginPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      final success = previous?.isLoading == true && next.hasValue;
      final failure = previous?.isLoading == true && next.hasError;
      if (success) {
        _setTeddyAnimation(
          'success',
          resetAfter: const Duration(milliseconds: 900),
        );
        context.go(_postAuthRoute(ref.read(sessionControllerProvider)));
      }
      if (failure) {
        _setTeddyAnimation(
          'fail',
          resetAfter: const Duration(milliseconds: 1200),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.t('auth_continue_failed')}: '
              '${AppErrorFormatter.readable(next.error!, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}',
            ),
          ),
        );
      }
    });

    return AuthSplitScaffold(
      heroLabel: context.l10n.t('app_name'),
      heroTitle: context.l10n.t('app_name').toUpperCase(),
      heroSubtitle: context.l10n.t('auth_portal_hero_subtitle'),
      showGuardianBear: false,
      showCompactHero: false,
      heroAnimation: _teddyAnimation,
      formChild: _AuthPanel(
        accessMode: _accessMode,
        authState: authState,
        keepSignedIn: _keepSignedIn,
        loginFormKey: _loginFormKey,
        loginEmailController: _loginEmailController,
        loginPasswordController: _loginPasswordController,
        loginEmailFocusNode: _loginEmailFocusNode,
        loginPasswordFocusNode: _loginPasswordFocusNode,
        teddyAnimation: _teddyAnimation,
        teddyLookOffsetX: _teddyLookOffsetX,
        loginPasswordVisible: _loginPasswordVisible,
        showValidation: _showValidation,
        onModeChanged: (mode) => setState(() => _accessMode = mode),
        onKeepSignedInChanged: (value) => setState(() => _keepSignedIn = value),
        onToggleLoginPasswordVisibility: (value) =>
            setState(() => _loginPasswordVisible = value),
        onClientLogin: _handleLogin,
        onInternalLogin: _handleLogin,
        onGoogleLogin: () => _handleSocialLogin('GOOGLE'),
        onFacebookLogin: () => _handleSocialLogin('FACEBOOK'),
        onEmailTyping: _handleEmailTyping,
        onPasswordTyping: _handlePasswordTyping,
        isFacebookEnabled: AppEnv.firebaseFacebookProviderEnabled,
        onEmailRegisterPressed: () => context.go('/register'),
        onPasswordResetPressed: () => context.go('/password-reset'),
      ),
    );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    _setTeddyAnimation(
      'hands_down',
      resetAfter: const Duration(milliseconds: 450),
    );
    final isValid = _loginFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      _setTeddyAnimation(
        'fail',
        resetAfter: const Duration(milliseconds: 1100),
      );
      setState(() => _showValidation = true);
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _loginEmailController.text.trim(),
          password: _loginPasswordController.text,
        );
  }

  void _syncTeddyFromFocus() {
    if (!mounted) return;
    if (_loginPasswordFocusNode.hasFocus) {
      if (_teddyLookOffsetX != 0) {
        setState(() => _teddyLookOffsetX = 0);
      }
      _setTeddyAnimation('hands_up');
      return;
    }
    if (_loginEmailFocusNode.hasFocus) {
      _setLookOffsetFromEmail(_loginEmailController.text);
      _animateEmailTracking(forceReplay: _teddyAnimation == 'test');
      return;
    }
    if (_teddyLookOffsetX != -1) {
      setState(() => _teddyLookOffsetX = -1);
    }
    _animateIdleFromCurrent();
  }

  void _animateEmailTracking({bool forceReplay = false}) {
    if (_teddyAnimation == 'hands_up') {
      _setTeddyAnimation('hands_down', forceReplay: true);
      _animationResetTimer?.cancel();
      _animationResetTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (_loginPasswordFocusNode.hasFocus) {
          _setTeddyAnimation('hands_up');
          return;
        }
        if (_loginEmailFocusNode.hasFocus) {
          _setTeddyAnimation('test', forceReplay: true);
          return;
        }
        _setTeddyAnimation('idle');
      });
      return;
    }
    _setTeddyAnimation('test', forceReplay: forceReplay);
  }

  void _animateIdleFromCurrent() {
    if (_teddyAnimation == 'hands_up') {
      _setTeddyAnimation(
        'hands_down',
        forceReplay: true,
        resetAfter: const Duration(milliseconds: 140),
      );
      return;
    }
    _setTeddyAnimation('idle');
  }

  void _setTeddyAnimation(
    String value, {
    Duration? resetAfter,
    bool forceReplay = false,
  }) {
    _animationResetTimer?.cancel();
    if (!mounted) {
      return;
    }
    if (_teddyAnimation != value) {
      setState(() => _teddyAnimation = value);
    } else if (forceReplay) {
      setState(() => _teddyAnimation = 'idle');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _teddyAnimation = value);
      });
    }
    if (resetAfter != null) {
      _animationResetTimer = Timer(resetAfter, _syncTeddyFromFocus);
    }
  }

  void _handleEmailTyping(String value) {
    if (!_loginEmailFocusNode.hasFocus) {
      return;
    }
    _setLookOffsetFromEmail(value);
    _animateEmailTracking(forceReplay: true);
  }

  void _handlePasswordTyping(String value) {
    if (_loginPasswordFocusNode.hasFocus) {
      if (_teddyLookOffsetX != 0) {
        setState(() => _teddyLookOffsetX = 0);
      }
      _setTeddyAnimation('hands_up');
    }
  }

  void _setLookOffsetFromEmail(String value) {
    final normalizedLength = value.trim().length;
    final ratio = (normalizedLength / 26).clamp(0.0, 1.0);
    final target = -1 + (2 * ratio);
    if ((_teddyLookOffsetX - target).abs() < 0.04) {
      return;
    }
    setState(() => _teddyLookOffsetX = target);
  }

  Future<void> _handleSocialLogin(String provider) async {
    await ref
        .read(authControllerProvider.notifier)
        .signInWithSocial(provider: provider, termsAccepted: true);
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
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.accessMode,
    required this.authState,
    required this.keepSignedIn,
    required this.loginFormKey,
    required this.loginEmailController,
    required this.loginPasswordController,
    required this.loginEmailFocusNode,
    required this.loginPasswordFocusNode,
    required this.teddyAnimation,
    required this.teddyLookOffsetX,
    required this.loginPasswordVisible,
    required this.showValidation,
    required this.onModeChanged,
    required this.onKeepSignedInChanged,
    required this.onToggleLoginPasswordVisibility,
    required this.onClientLogin,
    required this.onInternalLogin,
    required this.onGoogleLogin,
    required this.onFacebookLogin,
    required this.onEmailTyping,
    required this.onPasswordTyping,
    required this.isFacebookEnabled,
    required this.onEmailRegisterPressed,
    required this.onPasswordResetPressed,
  });

  final _AccessMode accessMode;
  final AsyncValue<void> authState;
  final bool keepSignedIn;
  final GlobalKey<FormState> loginFormKey;
  final TextEditingController loginEmailController;
  final TextEditingController loginPasswordController;
  final FocusNode loginEmailFocusNode;
  final FocusNode loginPasswordFocusNode;
  final String teddyAnimation;
  final double teddyLookOffsetX;
  final bool loginPasswordVisible;
  final bool showValidation;
  final ValueChanged<_AccessMode> onModeChanged;
  final ValueChanged<bool> onKeepSignedInChanged;
  final ValueChanged<bool> onToggleLoginPasswordVisibility;
  final Future<void> Function() onClientLogin;
  final Future<void> Function() onInternalLogin;
  final Future<void> Function() onGoogleLogin;
  final Future<void> Function() onFacebookLogin;
  final ValueChanged<String> onEmailTyping;
  final ValueChanged<String> onPasswordTyping;
  final bool isFacebookEnabled;
  final VoidCallback onEmailRegisterPressed;
  final VoidCallback onPasswordResetPressed;

  @override
  Widget build(BuildContext context) {
    final isClient = accessMode == _AccessMode.client;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final responsive = context.responsive;
    final width = media.size.width;
    final isMobile = media.size.shortestSide < 600;
    final topGap = width >= 980 ? 34.0 : (responsive.isMobile ? 4.0 : 10.0);
    final titleSize = responsive.adaptiveFont(
      mobileSmall: 30,
      mobile: 34,
      tablet: 37,
      desktopSmall: 40,
      desktop: 42,
    );
    final accessTitleSize = responsive.adaptiveFont(
      mobileSmall: 17,
      mobile: 18,
      tablet: 19,
      desktopSmall: 20,
      desktop: 20,
    );
    final headlineColor = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1C2434);
    final descriptionColor = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : Colors.black.withValues(alpha: 0.36);
    return Form(
      key: loginFormKey,
      autovalidateMode: showValidation
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topGap),
          if (isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                context.l10n.t('app_name').toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          if (isMobile) const SizedBox(height: 8),
          Center(
            child: AuthTeddyAnimation(
              animation: teddyAnimation,
              compact: width < 520,
              lookOffsetX: teddyLookOffsetX,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('login_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: headlineColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('login_description'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: descriptionColor,
              height: 1.35,
              fontSize: responsive.isMobile ? 12.8 : 13,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<_AccessMode>(
            segments: [
              ButtonSegment(
                value: _AccessMode.client,
                label: Text(l10n.t('mode_client')),
              ),
              ButtonSegment(
                value: _AccessMode.internal,
                label: Text(l10n.t('mode_internal')),
              ),
            ],
            selected: {accessMode},
            onSelectionChanged: (s) => onModeChanged(s.first),
          ),
          const SizedBox(height: 16),
          Text(
            isClient ? l10n.t('access_client') : l10n.t('access_internal'),
            style: TextStyle(
              fontSize: accessTitleSize,
              fontWeight: FontWeight.w700,
              color: headlineColor,
            ),
          ),
          const SizedBox(height: 10),
          AuthLineField(
            child: TextFormField(
              controller: loginEmailController,
              focusNode: loginEmailFocusNode,
              onTap: () => onEmailTyping(loginEmailController.text),
              onChanged: onEmailTyping,
              validator: FormValidators.email,
              keyboardType: TextInputType.emailAddress,
              decoration: AuthUi.lineFieldDecoration(l10n.t('email_hint')),
            ),
          ),
          const SizedBox(height: 10),
          AuthLineField(
            child: TextFormField(
              controller: loginPasswordController,
              focusNode: loginPasswordFocusNode,
              onTap: () => onPasswordTyping(loginPasswordController.text),
              onChanged: onPasswordTyping,
              obscureText: !loginPasswordVisible,
              validator: FormValidators.password,
              decoration: AuthUi.lineFieldDecoration(l10n.t('password_hint'))
                  .copyWith(
                    suffixIcon: IconButton(
                      tooltip: loginPasswordVisible
                          ? l10n.t('hide_password')
                          : l10n.t('show_password'),
                      onPressed: () => onToggleLoginPasswordVisibility(
                        !loginPasswordVisible,
                      ),
                      icon: Icon(
                        loginPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 8),
          if (width < 430)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: keepSignedIn,
                      onChanged: authState.isLoading
                          ? null
                          : (value) =>
                                onKeepSignedInChanged(value ?? keepSignedIn),
                    ),
                    const Expanded(child: _KeepSignedInLabel()),
                  ],
                ),
                if (isClient)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : onEmailRegisterPressed,
                      child: Text(l10n.t('create_account')),
                    ),
                  ),
              ],
            )
          else
            Row(
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Checkbox(
                        value: keepSignedIn,
                        onChanged: authState.isLoading
                            ? null
                            : (value) =>
                                  onKeepSignedInChanged(value ?? keepSignedIn),
                      ),
                      const Expanded(child: _KeepSignedInLabel()),
                    ],
                  ),
                ),
                if (isClient)
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : onEmailRegisterPressed,
                    child: Text(l10n.t('create_account')),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          AuthStripeButton(
            onPressed: authState.isLoading
                ? null
                : (isClient ? onClientLogin : onInternalLogin),
            icon: isClient ? Icons.person_outline : Icons.badge_outlined,
            label: authState.isLoading
                ? l10n.t('auth_validating')
                : isClient
                ? l10n.t('login_as_client')
                : l10n.t('login_as_internal'),
            filled: true,
          ),
          if (isClient) ...[
            const SizedBox(height: 14),
            if (width < 380)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: _SocialGhostButton(
                      icon: Icons.g_mobiledata,
                      label: 'Google',
                      onTap: authState.isLoading ? null : onGoogleLogin,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _SocialGhostButton(
                      icon: Icons.facebook,
                      label: 'Facebook',
                      onTap: authState.isLoading || !isFacebookEnabled
                          ? null
                          : onFacebookLogin,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _SocialGhostButton(
                      icon: Icons.g_mobiledata,
                      label: 'Google',
                      onTap: authState.isLoading ? null : onGoogleLogin,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SocialGhostButton(
                      icon: Icons.facebook,
                      label: 'Facebook',
                      onTap: authState.isLoading || !isFacebookEnabled
                          ? null
                          : onFacebookLogin,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: authState.isLoading ? null : onEmailRegisterPressed,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.t('create_client_account')),
            ),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: authState.isLoading ? null : onPasswordResetPressed,
            icon: const Icon(Icons.lock_reset_outlined),
            label: Text(
              isClient ? l10n.t('recover_password') : l10n.t('forgot_password'),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepSignedInLabel extends StatelessWidget {
  const _KeepSignedInLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.t('keep_signed_in'),
      style: const TextStyle(fontSize: 13),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SocialGhostButton extends StatelessWidget {
  const _SocialGhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
