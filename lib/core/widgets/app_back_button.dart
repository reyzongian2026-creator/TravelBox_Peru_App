import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.fallbackRoute,
    this.preferFallback = false,
  });

  final String fallbackRoute;
  final bool preferFallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.t('back'),
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (preferFallback) {
          context.go(fallbackRoute);
          return;
        }
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        context.go(fallbackRoute);
      },
    );
  }
}
