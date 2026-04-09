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
    _accessMode = _AccessMode.client;
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
      showHeroIllustration: false,
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
    final topGap = width >= 980 ? 20.0 : 0.0;
    final titleSize = responsive.adaptiveFont(
      mobileSmall: 20,
      mobile: 22,
      tablet: 28,
      desktopSmall: 32,
      desktop: 34,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: isMobile ? 36 : 64,
                width: isMobile ? 36 : 64,
                child: CustomPaint(
                  painter: _LoginPeruMapPainter(isDark: isDark),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'InkaVoy',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 24,
                      fontWeight: FontWeight.w800,
                      foreground: Paint()
                        ..shader = TravelBoxBrand.brandGradient.createShader(
                          const Rect.fromLTWH(0, 0, 200, 40),
                        ),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'PERÚ',
                    style: TextStyle(
                      fontSize: isMobile ? 8 : 9,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : TravelBoxBrand.textMuted,
                      letterSpacing: 3.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 14),
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
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width > 600 ? 20 : 8),
            child: Text(
              l10n.t('login_description'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: descriptionColor,
                height: 1.35,
                fontSize: isMobile ? 11.5 : 13,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 18),
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
          SizedBox(height: isMobile ? 6 : 16),
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
          SizedBox(height: isMobile ? 6 : 12),
          AuthLineField(
            child: TextFormField(
              controller: loginPasswordController,
              focusNode: loginPasswordFocusNode,
              onTap: () => onPasswordTyping(loginPasswordController.text),
              onChanged: onPasswordTyping,
              obscureText: !loginPasswordVisible,
              validator: FormValidators.password,
              decoration:
                  AuthUi.lineFieldDecoration(
                    l10n.t('password_hint'),
                    prefixIcon: Icons.lock_outline_rounded,
                  ).copyWith(
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
          const SizedBox(height: 6),
          if (width < 430)
            Row(
              children: [
                Checkbox(
                  value: keepSignedIn,
                  visualDensity: VisualDensity.compact,
                  onChanged: authState.isLoading
                      ? null
                      : (value) => onKeepSignedInChanged(value ?? keepSignedIn),
                ),
                const Expanded(child: _KeepSignedInLabel()),
                if (isClient)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: authState.isLoading
                        ? null
                        : onEmailRegisterPressed,
                    child: Text(
                      l10n.t('create_account'),
                      style: const TextStyle(fontSize: 12),
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
          const SizedBox(height: 4),
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
            loading: authState.isLoading,
          ),
          if (isClient) ...[
            const SizedBox(height: 6),
            if ((showGoogleLogin || showFacebookLogin || showMicrosoftLogin) &&
                width < 380)
              Column(
                children: [
                  if (showGoogleLogin)
                    SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: _SocialGhostButton(
                        icon: Icons.language_outlined,
                        label: 'Google',
                        onTap: authState.isLoading ? null : onGoogleLogin,
                      ),
                    ),
                  if (showGoogleLogin &&
                      (showFacebookLogin || showMicrosoftLogin))
                    const SizedBox(height: 6),
                  if (showFacebookLogin)
                    SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: _SocialGhostButton(
                        icon: Icons.facebook_outlined,
                        label: 'Facebook',
                        onTap: authState.isLoading ? null : onFacebookLogin,
                      ),
                    ),
                  if (showFacebookLogin && showMicrosoftLogin)
                    const SizedBox(height: 6),
                  if (showMicrosoftLogin)
                    SizedBox(
                      height: 36,
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
              SizedBox(
                height: 36,
                child: Row(
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
              ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isClient) ...[
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: authState.isLoading
                      ? null
                      : onEmailRegisterPressed,
                  child: Text(
                    l10n.t('create_client_account'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  ' · ',
                  style: TextStyle(
                    color: descriptionColor.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: authState.isLoading ? null : onPasswordResetPressed,
                child: Text(
                  isClient
                      ? l10n.t('recover_password')
                      : l10n.t('forgot_password'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 3 : 12),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  isDark ? const Color(0xFF2E3A52) : const Color(0xFFDDE3EE),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 3 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PolicyLink(
                label: l10n.t('privacy_policy'),
                onTap: () => _openPolicy(context, 'privacy'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : TravelBoxBrand.textMuted.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ),
              _PolicyLink(
                label: l10n.t('terms_of_service'),
                onTap: () => _openPolicy(context, 'terms'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : TravelBoxBrand.textMuted.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                '© ${DateTime.now().year} InkaVoy',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.28)
                      : TravelBoxBrand.textMuted.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _openPolicy(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (ctx) => _PolicyDialog(type: type),
    );
  }
}

class _KeepSignedInLabel extends StatelessWidget {
  const _KeepSignedInLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.t('keep_signed_in'),
      style: const TextStyle(fontSize: 12),
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
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          textStyle: const TextStyle(fontSize: 12),
          minimumSize: const Size(0, 34),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark
                ? Colors.white.withValues(alpha: 0.55)
                : TravelBoxBrand.textMuted,
            decoration: TextDecoration.underline,
            decorationColor: isDark
                ? Colors.white.withValues(alpha: 0.25)
                : TravelBoxBrand.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _PolicyDialog extends StatelessWidget {
  const _PolicyDialog({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrivacy = type == 'privacy';
    final title = isPrivacy
        ? l10n.t('privacy_policy')
        : l10n.t('terms_of_service');

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151A30) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: TravelBoxBrand.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isPrivacy
                          ? Icons.shield_outlined
                          : Icons.description_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : TravelBoxBrand.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Text(
                  isPrivacy ? _privacyPolicyText : _termsOfServiceText,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : TravelBoxBrand.textBody,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TravelBoxBrand.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(l10n.t('understood')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _privacyPolicyText = '''
InkaVoy Perú - Política de Privacidad

Última actualización: Enero 2026

1. Información que Recopilamos
Recopilamos información personal que usted nos proporciona directamente, incluyendo nombre, correo electrónico, número de teléfono e información de viaje.

2. Uso de la Información
Utilizamos su información para:
• Gestionar su cuenta y proporcionar nuestros servicios de almacenaje y logística para viajeros.
• Procesar reservas, check-ins y operaciones de equipaje.
• Enviar notificaciones relacionadas con sus servicios activos.
• Mejorar la experiencia del usuario y nuestros servicios.

3. Protección de Datos
Implementamos medidas de seguridad técnicas y organizativas para proteger su información personal contra acceso no autorizado, alteración o destrucción.

4. Compartir Información
No vendemos ni compartimos su información personal con terceros, excepto cuando sea necesario para prestar nuestros servicios o cuando lo exija la ley peruana.

5. Sus Derechos
Usted tiene derecho a acceder, rectificar, cancelar u oponerse al tratamiento de sus datos personales conforme a la Ley N° 29733 - Ley de Protección de Datos Personales del Perú.

6. Contacto
Para consultas sobre privacidad: privacidad@inkavoy.pe
''';

  static const _termsOfServiceText = '''
InkaVoy Perú - Términos de Servicio

Última actualización: Enero 2026

1. Aceptación de Términos
Al acceder y utilizar la plataforma InkaVoy Perú, usted acepta estos términos de servicio en su totalidad.

2. Descripción del Servicio
InkaVoy Perú ofrece servicios de almacenaje de equipaje, logística de viaje y operaciones de check-in para viajeros nacionales e internacionales en territorio peruano.

3. Registro y Cuenta
• Debe proporcionar información veraz y actualizada.
• Es responsable de mantener la confidencialidad de sus credenciales.
• Debe notificarnos inmediatamente cualquier uso no autorizado.

4. Uso Aceptable
Se compromete a utilizar la plataforma únicamente para fines legítimos relacionados con viajes y los servicios ofrecidos.

5. Responsabilidad
InkaVoy Perú se compromete a custodiar sus pertenencias con el máximo cuidado. La responsabilidad está limitada según los términos de cada servicio contratado.

6. Modificaciones
Nos reservamos el derecho de modificar estos términos. Los cambios serán comunicados a través de la plataforma.

7. Ley Aplicable
Estos términos se rigen por las leyes de la República del Perú. Cualquier controversia será resuelta en los tribunales de Lima.

8. Contacto
Soporte: soporte@inkavoy.pe
''';
}

class _LoginPeruMapPainter extends CustomPainter {
  _LoginPeruMapPainter({required this.isDark});

  final bool isDark;

  // 76 real border points from Natural Earth / GeoJSON (johan/world.geo.json).
  // Converted from lon/lat to normalised canvas [0..1] with Y inverted.
  // Bounding box: lon [-81.41, -68.67], lat [-18.35, -0.06], 2% padding.
  static const _border = <List<double>>[
    [0.911, 0.9404],
    [0.8907, 0.9673],
    [0.852, 0.9808],
    [0.7763, 0.9506],
    [0.7698, 0.929],
    [0.6202, 0.8762],
    [0.4849, 0.8187],
    [0.4267, 0.7863],
    [0.3955, 0.7429],
    [0.4079, 0.7278],
    [0.344, 0.6588],
    [0.2696, 0.5618],
    [0.1983, 0.4571],
    [0.1675, 0.4331],
    [0.1437, 0.3944],
    [0.0851, 0.3601],
    [0.0314, 0.3388],
    [0.0558, 0.3154],
    [0.0192, 0.2652],
    [0.0427, 0.2284],
    [0.1028, 0.1952],
    [0.1118, 0.2171],
    [0.0903, 0.2296],
    [0.0923, 0.2489],
    [0.1235, 0.2447],
    [0.154, 0.2504],
    [0.1856, 0.2769],
    [0.2283, 0.2553],
    [0.2426, 0.2198],
    [0.2888, 0.1741],
    [0.3795, 0.1534],
    [0.4618, 0.0983],
    [0.4852, 0.0641],
    [0.4747, 0.0242],
    [0.4948, 0.0192],
    [0.545, 0.0441],
    [0.5691, 0.0689],
    [0.604, 0.0825],
    [0.6484, 0.1376],
    [0.7046, 0.1442],
    [0.7462, 0.1303],
    [0.7734, 0.1394],
    [0.8187, 0.1349],
    [0.8765, 0.1595],
    [0.8278, 0.213],
    [0.8503, 0.2142],
    [0.8881, 0.2422],
    [0.8201, 0.2397],
    [0.81, 0.2476],
    [0.7482, 0.2577],
    [0.6619, 0.2935],
    [0.6564, 0.318],
    [0.6372, 0.3363],
    [0.6447, 0.3648],
    [0.5991, 0.3799],
    [0.5992, 0.4021],
    [0.5793, 0.4117],
    [0.6107, 0.4591],
    [0.6526, 0.4911],
    [0.6366, 0.5136],
    [0.6867, 0.5167],
    [0.7152, 0.5447],
    [0.7818, 0.5461],
    [0.8437, 0.5151],
    [0.8387, 0.595],
    [0.873, 0.601],
    [0.9155, 0.592],
    [0.9808, 0.6766],
    [0.9645, 0.6944],
    [0.9608, 0.7313],
    [0.9594, 0.776],
    [0.9299, 0.8023],
    [0.9434, 0.8218],
    [0.9261, 0.8395],
    [0.9585, 0.8837],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final peruPath = _buildPeruOutline(size);

    // Soft glow
    final glowPaint = Paint()
      ..color = const Color(0xFF3366FF).withValues(alpha: 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(peruPath, glowPaint);

    // Very subtle fill
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark
          ? const Color(0xFF3366FF).withValues(alpha: 0.06)
          : const Color(0xFF3366FF).withValues(alpha: 0.04);
    canvas.drawPath(peruPath, fillPaint);

    // Main outline stroke
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.55)
          : TravelBoxBrand.primaryBlue.withValues(alpha: 0.38);
    canvas.drawPath(peruPath, outlinePaint);

    // Geographic grid lines clipped to Peru shape
    final detailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.10)
          : TravelBoxBrand.primaryBlue.withValues(alpha: 0.06);

    canvas.save();
    canvas.clipPath(peruPath);
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.15 + i * 0.16);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), detailPaint);
    }
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.15 + i * 0.22);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), detailPaint);
    }
    canvas.restore();

    // City dots — real normalised positions
    final dotPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.55)
          : TravelBoxBrand.primaryBlue.withValues(alpha: 0.40);

    // Lima -77.03/-12.05, Cusco -71.97/-13.52, Arequipa -71.54/-16.41, Iquitos -73.25/-3.75
    final cities = [
      Offset(size.width * 0.34, size.height * 0.645), // Lima
      Offset(size.width * 0.73, size.height * 0.724), // Cusco
      Offset(size.width * 0.76, size.height * 0.877), // Arequipa
      Offset(size.width * 0.63, size.height * 0.201), // Iquitos
    ];
    for (final pos in cities) {
      canvas.drawCircle(pos, 2.0, dotPaint);
      canvas.drawCircle(
        pos,
        4.5,
        Paint()
          ..color = dotPaint.color.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  /// Build a smooth closed path through real border points using Catmull-Rom.
  Path _buildPeruOutline(Size size) {
    final pts = _border
        .map((p) => Offset(p[0] * size.width, p[1] * size.height))
        .toList();

    final n = pts.length;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);

    // Catmull-Rom spline → cubic Bézier segments (smoother than quadratic B-spline)
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = pts[(i + 2) % n];

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _LoginPeruMapPainter oldDelegate) =>
      isDark != oldDelegate.isDark;
}
