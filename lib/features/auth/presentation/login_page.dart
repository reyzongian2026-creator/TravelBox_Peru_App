import 'package:flutter/material.dart';

import 'auth_portal_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthPortalPage(initialMode: AuthPortalMode.login);
  }
}
