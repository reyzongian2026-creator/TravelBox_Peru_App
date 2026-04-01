import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env/app_env.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/theme/brand_tokens.dart';
import '../data/social_callback_url_cleaner.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/form_validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_ui.dart';
import 'widgets/auth_llama_animation.dart';

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
  String _llamaAnimation = 'idle';
  double _llamaLookOffsetX = -1;
  Timer? _animationResetTimer;
  bool _consumingSocialPayload = false;

  @override
  void initState() {
    super.initState();
    _accessMode = _AccessMode.internal;
    _loginEmailFocusNode.addListener(_syncLlamaFromFocus);
    _loginPasswordFocusNode.addListener(_syncLlamaFromFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeSocialCallbackPayloadIfPresent();
    });
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
        _setLlamaAnimation(
          'success',
          resetAfter: const Duration(milliseconds: 900),
        );
        context.go(_postAuthRoute(ref.read(sessionControllerProvider)));
      }
      if (failure) {
        _setLlamaAnimation(
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
      showGuardianLlama: false,
      showCompactHero: false,
      heroAnimation: _llamaAnimation,
      formChild: _AuthPanel(
        accessMode: _accessMode,
        authState: authState,
        keepSignedIn: _keepSignedIn,
        loginFormKey: _loginFormKey,
        loginEmailController: _loginEmailController,
        loginPasswordController: _loginPasswordController,
        loginEmailFocusNode: _loginEmailFocusNode,
        loginPasswordFocusNode: _loginPasswordFocusNode,
        llamaAnimation: _llamaAnimation,
        llamaLookOffsetX: _llamaLookOffsetX,
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
        onMicrosoftLogin: () => _handleSocialLogin('MICROSOFT'),
        onEmailTyping: _handleEmailTyping,
        onPasswordTyping: _handlePasswordTyping,
        showGoogleLogin: kIsWeb,
        showFacebookLogin: kIsWeb,
        showMicrosoftLogin: !kIsWeb && AppEnv.hasEntraAuthConfig,
        onEmailRegisterPressed: () => context.go('/register'),
        onPasswordResetPressed: () => context.go('/password-reset'),
      ),
    );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    _setLlamaAnimation(
      'hands_down',
      resetAfter: const Duration(milliseconds: 450),
    );
    final isValid = _loginFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      _setLlamaAnimation(
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

  void _syncLlamaFromFocus() {
    if (!mounted) return;
    if (_loginPasswordFocusNode.hasFocus) {
      if (_llamaLookOffsetX != 0) {
        setState(() => _llamaLookOffsetX = 0);
      }
      _setLlamaAnimation('hands_up');
      return;
    }
    if (_loginEmailFocusNode.hasFocus) {
      _setLookOffsetFromEmail(_loginEmailController.text);
      _animateEmailTracking(forceReplay: _llamaAnimation == 'test');
      return;
    }
    if (_llamaLookOffsetX != -1) {
      setState(() => _llamaLookOffsetX = -1);
    }
    _animateIdleFromCurrent();
  }

  void _animateEmailTracking({bool forceReplay = false}) {
    if (_llamaAnimation == 'hands_up') {
      _setLlamaAnimation('hands_down', forceReplay: true);
      _animationResetTimer?.cancel();
      _animationResetTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (_loginPasswordFocusNode.hasFocus) {
          _setLlamaAnimation('hands_up');
          return;
        }
        if (_loginEmailFocusNode.hasFocus) {
          _setLlamaAnimation('test', forceReplay: true);
          return;
        }
        _setLlamaAnimation('idle');
      });
      return;
    }
    _setLlamaAnimation('test', forceReplay: forceReplay);
  }

  void _animateIdleFromCurrent() {
    if (_llamaAnimation == 'hands_up') {
      _setLlamaAnimation(
        'hands_down',
        forceReplay: true,
        resetAfter: const Duration(milliseconds: 140),
      );
      return;
    }
    _setLlamaAnimation('idle');
  }

  void _setLlamaAnimation(
    String value, {
    Duration? resetAfter,
    bool forceReplay = false,
  }) {
    _animationResetTimer?.cancel();
    if (!mounted) {
      return;
    }
    if (_llamaAnimation != value) {
      setState(() => _llamaAnimation = value);
    } else if (forceReplay) {
      setState(() => _llamaAnimation = 'idle');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _llamaAnimation = value);
      });
    }
    if (resetAfter != null) {
      _animationResetTimer = Timer(resetAfter, _syncLlamaFromFocus);
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
      if (_llamaLookOffsetX != 0) {
        setState(() => _llamaLookOffsetX = 0);
      }
      _setLlamaAnimation('hands_up');
    }
  }

  void _setLookOffsetFromEmail(String value) {
    final normalizedLength = value.trim().length;
    final ratio = (normalizedLength / 26).clamp(0.0, 1.0);
    final target = -1 + (2 * ratio);
    if ((_llamaLookOffsetX - target).abs() < 0.04) {
      return;
    }
    setState(() => _llamaLookOffsetX = target);
  }

  Future<void> _handleSocialLogin(String provider) async {
    await ref
        .read(authControllerProvider.notifier)
        .signInWithSocial(provider: provider, termsAccepted: true);
  }

  Future<void> _consumeSocialCallbackPayloadIfPresent() async {
    if (!mounted || _consumingSocialPayload) {
      return;
    }
    final uri = Uri.base;
    final payload = uri.queryParameters['payload']?.trim();
    final error = uri.queryParameters['error']?.trim();
    if ((payload == null || payload.isEmpty) &&
        (error == null || error.isEmpty)) {
      return;
    }

    _consumingSocialPayload = true;
    await clearSocialCallbackUrl(route: '/login');
    if (error != null && error.isNotEmpty) {
      _setLlamaAnimation(
        'fail',
        resetAfter: const Duration(milliseconds: 1200),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      _consumingSocialPayload = false;
      return;
    }

    try {
      final decoded = _decodeSocialPayload(payload!);
      final accessToken = decoded['accessToken']?.toString().trim() ?? '';
      final refreshToken = decoded['refreshToken']?.toString().trim() ?? '';
      final rawUser = decoded['user'];
      if (accessToken.isEmpty || refreshToken.isEmpty || rawUser is! Map) {
        throw const FormatException('Missing session fields');
      }

      final user = AppUser.fromJson(Map<String, dynamic>.from(rawUser));
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(
            user: user,
            accessToken: accessToken,
            refreshToken: refreshToken,
            pendingVerificationCode: decoded['verificationCodePreview']
                ?.toString(),
          );
      if (!mounted) return;
      _setLlamaAnimation(
        'success',
        resetAfter: const Duration(milliseconds: 900),
      );
      context.go(_postAuthRoute(ref.read(sessionControllerProvider)));
    } catch (_) {
      if (!mounted) return;
      _setLlamaAnimation(
        'fail',
        resetAfter: const Duration(milliseconds: 1200),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar el inicio de sesion social.'),
        ),
      );
    } finally {
      _consumingSocialPayload = false;
    }
  }

  Map<String, dynamic> _decodeSocialPayload(String payload) {
    final normalized = switch (payload.length % 4) {
      2 => '$payload==',
      3 => '$payload=',
      _ => payload,
    };
    final bytes = base64Url.decode(normalized);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  String _postAuthRoute(SessionState session) {
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
    required this.llamaAnimation,
    required this.llamaLookOffsetX,
    required this.loginPasswordVisible,
    required this.showValidation,
    required this.onModeChanged,
    required this.onKeepSignedInChanged,
    required this.onToggleLoginPasswordVisibility,
    required this.onClientLogin,
    required this.onInternalLogin,
    required this.onGoogleLogin,
    required this.onFacebookLogin,
    required this.onMicrosoftLogin,
    required this.onEmailTyping,
    required this.onPasswordTyping,
    required this.showGoogleLogin,
    required this.showFacebookLogin,
    required this.showMicrosoftLogin,
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
  final String llamaAnimation;
  final double llamaLookOffsetX;
  final bool loginPasswordVisible;
  final bool showValidation;
  final ValueChanged<_AccessMode> onModeChanged;
  final ValueChanged<bool> onKeepSignedInChanged;
  final ValueChanged<bool> onToggleLoginPasswordVisibility;
  final Future<void> Function() onClientLogin;
  final Future<void> Function() onInternalLogin;
  final Future<void> Function() onGoogleLogin;
  final Future<void> Function() onFacebookLogin;
  final Future<void> Function() onMicrosoftLogin;
  final ValueChanged<String> onEmailTyping;
  final ValueChanged<String> onPasswordTyping;
  final bool showGoogleLogin;
  final bool showFacebookLogin;
  final bool showMicrosoftLogin;
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
    final topGap = width >= 980 ? 28.0 : (responsive.isMobile ? 2.0 : 8.0);
    final titleSize = responsive.adaptiveFont(
      mobileSmall: 26,
      mobile: 30,
      tablet: 33,
      desktopSmall: 36,
      desktop: 38,
    );
    final accessTitleSize = responsive.adaptiveFont(
      mobileSmall: 15,
      mobile: 16,
      tablet: 17,
      desktopSmall: 18,
      desktop: 18,
    );
    final headlineColor = isDark ? const Color(0xFFF6ECDE) : TravelBoxBrand.ink;
    final descriptionColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : TravelBoxBrand.textMuted;
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
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: TravelBoxBrand.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  context.l10n.t('app_name').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),
          if (isMobile) const SizedBox(height: 6),
          Center(
            child: AuthLlamaAnimation(
              animation: llamaAnimation,
              compact: width < 520,
              lookOffsetX: llamaLookOffsetX,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('login_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: headlineColor,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width > 600 ? 20 : 8),
            child: Text(
              l10n.t('login_description'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: descriptionColor,
                height: 1.45,
                fontSize: responsive.isMobile ? 13 : 13.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 3.5,
                height: 18,
                decoration: BoxDecoration(
                  gradient: TravelBoxBrand.brandGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isClient
                    ? l10n.t('access_client')
                    : l10n.t('access_internal'),
                style: TextStyle(
                  fontSize: accessTitleSize,
                  fontWeight: FontWeight.w700,
                  color: headlineColor,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AuthLineField(
            child: TextFormField(
              controller: loginEmailController,
              focusNode: loginEmailFocusNode,
              onTap: () => onEmailTyping(loginEmailController.text),
              onChanged: onEmailTyping,
              validator: FormValidators.email,
              keyboardType: TextInputType.emailAddress,
              decoration: AuthUi.lineFieldDecoration(
                l10n.t('email_hint'),
                prefixIcon: Icons.alternate_email_rounded,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AuthLineField(
            child: TextFormField(
              controller: loginPasswordController,
              focusNode: loginPasswordFocusNode,
              onTap: () => onPasswordTyping(loginPasswordController.text),
              onChanged: onPasswordTyping,
              obscureText: !loginPasswordVisible,
              validator: FormValidators.password,
              decoration: AuthUi.lineFieldDecoration(l10n.t('password_hint'),
                  prefixIcon: Icons.lock_outline_rounded)
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
            if ((showGoogleLogin || showFacebookLogin || showMicrosoftLogin) &&
                width < 380)
              Column(
                children: [
                  if (showGoogleLogin)
                    SizedBox(
                      width: double.infinity,
                      child: _SocialGhostButton(
                        icon: Icons.language_outlined,
                        label: 'Google',
                        onTap: authState.isLoading ? null : onGoogleLogin,
                      ),
                    ),
                  if (showGoogleLogin &&
                      (showFacebookLogin || showMicrosoftLogin))
                    const SizedBox(height: 8),
                  if (showFacebookLogin)
                    SizedBox(
                      width: double.infinity,
                      child: _SocialGhostButton(
                        icon: Icons.facebook_outlined,
                        label: 'Facebook',
                        onTap: authState.isLoading ? null : onFacebookLogin,
                      ),
                    ),
                  if (showFacebookLogin && showMicrosoftLogin)
                    const SizedBox(height: 8),
                  if (showMicrosoftLogin)
                    SizedBox(
                      width: double.infinity,
                      child: _SocialGhostButton(
                        icon: Icons.business_center_outlined,
                        label: 'Microsoft',
                        onTap: authState.isLoading ? null : onMicrosoftLogin,
                      ),
                    ),
                ],
              )
            else if (showGoogleLogin || showFacebookLogin || showMicrosoftLogin)
              Row(
                children: [
                  if (showGoogleLogin)
                    Expanded(
                      child: _SocialGhostButton(
                        icon: Icons.language_outlined,
                        label: 'Google',
                        onTap: authState.isLoading ? null : onGoogleLogin,
                      ),
                    ),
                  if (showGoogleLogin &&
                      (showFacebookLogin || showMicrosoftLogin))
                    const SizedBox(width: 8),
                  if (showFacebookLogin)
                    Expanded(
                      child: _SocialGhostButton(
                        icon: Icons.facebook_outlined,
                        label: 'Facebook',
                        onTap: authState.isLoading ? null : onFacebookLogin,
                      ),
                    ),
                  if (showFacebookLogin && showMicrosoftLogin)
                    const SizedBox(width: 8),
                  if (showMicrosoftLogin)
                    Expanded(
                      child: _SocialGhostButton(
                        icon: Icons.business_center_outlined,
                        label: 'Microsoft',
                        onTap: authState.isLoading ? null : onMicrosoftLogin,
                      ),
                    ),
                ],
              ),
            if (showGoogleLogin || showFacebookLogin || showMicrosoftLogin)
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
