import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/shared/models/app_user.dart';

void main() {
  group('AppUser role resolution', () {
    test('picks ADMIN when roles include SUPPORT and ADMIN', () {
      final user = AppUser.fromJson({
        'id': 1,
        'name': 'Admin',
        'email': 'admin@travelbox.pe',
        'roles': ['SUPPORT', 'ADMIN'],
      });

      expect(user.role, UserRole.admin);
    });

    test('roles list has priority over singular role value', () {
      final user = AppUser.fromJson({
        'id': 1,
        'name': 'Admin',
        'email': 'admin@travelbox.pe',
        'role': 'SUPPORT',
        'roles': ['SUPPORT', 'ADMIN'],
      });

      expect(user.role, UserRole.admin);
    });

    test('parses COURIER role from roles list', () {
      final user = AppUser.fromJson({
        'id': 2,
        'name': 'Courier',
        'email': 'courier@travelbox.pe',
        'roles': ['COURIER'],
      });

      expect(user.role, UserRole.courier);
    });
  });
}
