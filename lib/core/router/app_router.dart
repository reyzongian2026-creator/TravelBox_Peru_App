import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin_dashboard/presentation/admin_dashboard_page.dart';
import '../../features/admin_incidents/presentation/admin_incidents_page.dart';
import '../../features/admin_payments/presentation/admin_payments_history_page.dart';
import '../../features/admin_reservations/presentation/admin_reservations_page.dart';
import '../../features/admin_users/presentation/admin_users_page.dart';
import '../../features/admin_warehouses/presentation/admin_warehouses_page.dart';
import '../../features/auth/presentation/auth_portal_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/password_reset_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/delivery/presentation/delivery_request_page.dart';
import '../../features/delivery/presentation/delivery_monitor_page.dart';
import '../../features/delivery/presentation/tracking_page.dart';
import '../../features/courier/presentation/courier_dashboard_page.dart';
import '../../features/courier/presentation/courier_services_page.dart';
import '../../features/incidents/presentation/incidents_page.dart';
import '../../features/map_discovery/presentation/home_discovery_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/operator_dashboard/presentation/operator_dashboard_page.dart';
import '../../features/ops_qr/presentation/ops_qr_handoff_page.dart';
import '../../features/payments/presentation/cash_payments_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/qr_scan/presentation/qr_scan_page.dart';
import '../../features/reservation/presentation/checkout_page.dart';
import '../../features/reservation/presentation/my_reservations_page.dart';
import '../../features/reservation/presentation/reservation_detail_page.dart';
import '../../features/reservation/presentation/reservation_form_page.dart';
import '../../features/reservation/presentation/reservation_success_page.dart';
import '../../features/auth/presentation/verify_email_page.dart';
import '../../features/warehouse/presentation/warehouse_detail_page.dart';
import '../../shared/state/session_controller.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionControllerProvider);

  return GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      final path = state.matchedLocation;
      const publicPaths = {'/auth', '/login', '/register', '/password-reset'};
      const verificationPath = '/verify-email';
      const onboardingPath = '/onboarding';
      const completionPath = '/profile/complete';

      if (!session.isAuthenticated && !publicPaths.contains(path)) {
        return '/login';
      }

      if (session.isAuthenticated && session.needsEmailVerification) {
        if (path != verificationPath) {
          return verificationPath;
        }
        return null;
      }

      if (session.isAuthenticated && session.needsOnboarding) {
        if (path != onboardingPath) {
          return onboardingPath;
        }
        return null;
      }

      if (session.isAuthenticated && session.needsProfileCompletion) {
        if (path != completionPath) {
          return completionPath;
        }
        return null;
      }

      if (session.isAuthenticated &&
          (publicPaths.contains(path) ||
              path == onboardingPath ||
              path == verificationPath ||
              path == completionPath)) {
        return _defaultLandingRoute(session);
      }

      if (path.startsWith('/admin') && !session.isAdmin) {
        if (session.isSupport) {
          return '/support/incidents';
        }
        if (session.canAccessAdmin) {
          return '/operator/panel';
        }
        if (session.isCourier) {
          return '/courier/panel';
        }
        return '/discovery';
      }

      if (path.startsWith('/operator') && !session.canAccessAdmin) {
        if (session.isSupport) {
          return '/support/incidents';
        }
        if (session.isCourier) {
          return '/courier/panel';
        }
        return '/discovery';
      }

      if (path.startsWith('/support') && !session.isSupport) {
        if (session.isAdmin) {
          return '/admin/incidents';
        }
        if (session.canAccessAdmin) {
          return '/operator/incidents';
        }
        return '/discovery';
      }

      if (path.startsWith('/courier') && !session.isCourier) {
        if (session.isAdmin) {
          return '/admin/dashboard';
        }
        if (session.canAccessAdmin) {
          return '/operator/panel';
        }
        return '/discovery';
      }

      if (path.startsWith('/ops') &&
          !session.canAccessAdmin &&
          !session.isAdmin &&
          !session.isCourier) {
        return '/discovery';
      }

      if (session.isSupport &&
          !path.startsWith('/support/incidents') &&
          !path.startsWith('/notifications') &&
          !path.startsWith('/profile') &&
          !path.startsWith('/qr-scan')) {
        return '/support/incidents';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => AuthPortalPage(
          initialMode: state.uri.queryParameters['mode'] == 'register'
              ? AuthPortalMode.register
              : AuthPortalMode.login,
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/password-reset',
        builder: (context, state) => const PasswordResetPage(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: '/discovery',
        builder: (context, state) => const HomeDiscoveryPage(),
      ),
      GoRoute(
        path: '/warehouse/:warehouseId',
        builder: (_, state) => WarehouseDetailPage(
          warehouseId: state.pathParameters['warehouseId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reservation/new/:warehouseId',
        builder: (_, state) => ReservationFormPage(
          warehouseId: state.pathParameters['warehouseId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/checkout/:warehouseId',
        builder: (_, state) => CheckoutPage(
          warehouseId: state.pathParameters['warehouseId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reservation/success/:reservationId',
        builder: (_, state) => ReservationSuccessPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reservations',
        builder: (context, state) => const MyReservationsPage(),
      ),
      GoRoute(
        path: '/reservation/:reservationId',
        builder: (_, state) {
          final postCheckoutBack = state.uri.queryParameters['back'] == 'home';
          return ReservationDetailPage(
            reservationId: state.pathParameters['reservationId'] ?? '',
            fallbackRoute: postCheckoutBack ? '/discovery' : '/reservations',
            lockBackNavigation: postCheckoutBack,
          );
        },
      ),
      GoRoute(
        path: '/delivery/:reservationId',
        builder: (_, state) => DeliveryRequestPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
          backRoute: state.uri.queryParameters['back'],
          initialType:
              state.uri.queryParameters['type']?.trim().toUpperCase() ==
                  'PICKUP'
              ? DeliveryRequestType.pickup
              : DeliveryRequestType.delivery,
        ),
      ),
      GoRoute(
        path: '/tracking/:reservationId',
        builder: (_, state) => TrackingPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/tracking',
        builder: (context, state) => const DeliveryMonitorPage(
          title: 'Tracking logistico',
          currentRoute: '/admin/tracking',
        ),
      ),
      GoRoute(
        path: '/admin/tracking/:reservationId',
        builder: (_, state) => TrackingPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
          title: 'Tracking logistico',
          currentRoute: '/admin/tracking',
          backofficeMode: true,
        ),
      ),
      GoRoute(
        path: '/incidents',
        builder: (_, state) => IncidentsPage(
          reservationId: state.uri.queryParameters['reservationId'],
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/profile/complete',
        builder: (context, state) => const EditProfilePage(forceComplete: true),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/ops/qr-handoff',
        builder: (context, state) => OpsQrHandoffPage(
          initialScannedValue: state.uri.queryParameters['scan'],
        ),
      ),
      GoRoute(
        path: '/qr-scan',
        builder: (context, state) => const QrScanPage(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: '/admin/cash-payments',
        builder: (context, state) => const CashPaymentsPage(),
      ),
      GoRoute(
        path: '/admin/warehouses',
        builder: (context, state) => const AdminWarehousesPage(),
      ),
      GoRoute(
        path: '/admin/reservations',
        builder: (context, state) => const AdminReservationsPage(),
      ),
      GoRoute(
        path: '/admin/incidents',
        builder: (context, state) => const AdminIncidentsPage(),
      ),
      GoRoute(
        path: '/admin/payments-history',
        builder: (context, state) => const AdminPaymentsHistoryPage(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUsersPage(),
      ),
      GoRoute(
        path: '/operator/panel',
        builder: (context, state) => const OperatorDashboardPage(),
      ),
      GoRoute(
        path: '/operator/cash-payments',
        builder: (context, state) => const CashPaymentsPage(
          title: 'Cobros en caja',
          currentRoute: '/operator/cash-payments',
        ),
      ),
      GoRoute(
        path: '/operator/reservations',
        builder: (context, state) => const AdminReservationsPage(
          title: 'Reservas operativas',
          currentRoute: '/operator/reservations',
        ),
      ),
      GoRoute(
        path: '/operator/incidents',
        builder: (context, state) => const AdminIncidentsPage(
          title: 'Incidencias operativas',
          currentRoute: '/operator/incidents',
        ),
      ),
      GoRoute(
        path: '/support/incidents',
        builder: (context, state) => const AdminIncidentsPage(
          title: 'Incidencias de soporte',
          currentRoute: '/support/incidents',
        ),
      ),
      GoRoute(
        path: '/operator/tracking',
        builder: (context, state) => const DeliveryMonitorPage(
          title: 'Tracking logistico',
          currentRoute: '/operator/tracking',
        ),
      ),
      GoRoute(
        path: '/operator/tracking/:reservationId',
        builder: (_, state) => TrackingPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
          title: 'Tracking logistico',
          currentRoute: '/operator/tracking',
          backofficeMode: true,
        ),
      ),
      GoRoute(
        path: '/courier/panel',
        builder: (context, state) => const CourierDashboardPage(),
      ),
      GoRoute(
        path: '/courier/services',
        builder: (context, state) => const CourierServicesPage(),
      ),
      GoRoute(
        path: '/courier/tracking/:reservationId',
        builder: (_, state) => TrackingPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
          title: 'Tracking courier',
          currentRoute: '/courier/services',
          backofficeMode: true,
        ),
      ),
    ],
    errorBuilder: (_, state) {
      return Scaffold(
        body: Center(child: Text('Ruta no encontrada: ${state.uri}')),
      );
    },
  );
});

String _defaultLandingRoute(SessionState session) {
  if (session.isAdmin) {
    return '/admin/dashboard';
  }
  if (session.isSupport) {
    return '/support/incidents';
  }
  if (session.isCourier) {
    return '/courier/panel';
  }
  if (session.canAccessAdmin) {
    return '/operator/panel';
  }
  return '/discovery';
}
