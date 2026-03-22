import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin_dashboard/presentation/admin_shell_page.dart';
import '../../features/admin_incidents/presentation/admin_incidents_page.dart';
import '../../features/admin_reservations/presentation/admin_reservations_page.dart';
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
import '../../features/Rating/presentation/warehouse_ratings_page.dart';
import '../debug/debug_text_page.dart';
import '../l10n/app_localizations.dart';
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
        builder: (context, state) => OnboardingPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => AuthPortalPage(
          initialMode: state.uri.queryParameters['mode'] == 'register'
              ? AuthPortalMode.register
              : AuthPortalMode.login,
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => RegisterPage()),
      GoRoute(
        path: '/password-reset',
        builder: (context, state) => PasswordResetPage(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => VerifyEmailPage(),
      ),
      GoRoute(
        path: '/discovery',
        builder: (context, state) => HomeDiscoveryPage(),
      ),
      GoRoute(
        path: '/warehouse/:warehouseId',
        builder: (_, state) => WarehouseDetailPage(
          warehouseId: state.pathParameters['warehouseId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/warehouse/:warehouseId/ratings',
        builder: (context, state) {
          final warehouseId = int.tryParse(state.pathParameters['warehouseId'] ?? '');
          final warehouseName = state.uri.queryParameters['name'] ?? '';
          if (warehouseId == null) {
            return Scaffold(
              body: Center(child: Text(context.l10n.t('error_invalid_warehouse_id'))),
            );
          }
          return WarehouseRatingsPage(
            warehouseId: warehouseId,
            warehouseName: warehouseName,
          );
        },
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
        builder: (context, state) => MyReservationsPage(),
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
        builder: (context, state) => DeliveryMonitorPage(
          title: 'tracking_logistico',
          currentRoute: '/admin/tracking',
        ),
      ),
      GoRoute(
        path: '/admin/tracking/:reservationId',
        builder: (_, state) => TrackingPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
          title: 'tracking_logistico',
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
      GoRoute(path: '/profile', builder: (context, state) => ProfilePage()),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => EditProfilePage(),
      ),
      GoRoute(
        path: '/profile/complete',
        builder: (context, state) => EditProfilePage(forceComplete: true),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationsPage(),
      ),
      GoRoute(
        path: '/ops/qr-handoff',
        builder: (context, state) => OpsQrHandoffPage(
          initialScannedValue: state.uri.queryParameters['scan'],
        ),
      ),
      GoRoute(path: '/qr-scan', builder: (context, state) => QrScanPage()),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const AdminShellPage(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminShellPage(),
          ),
          GoRoute(
            path: '/admin/warehouses',
            builder: (context, state) => const AdminShellPage(),
          ),
          GoRoute(
            path: '/admin/reservations',
            builder: (context, state) => const AdminShellPage(),
          ),
          GoRoute(
            path: '/admin/delivery',
            builder: (context, state) => const AdminShellPage(),
          ),
          GoRoute(
            path: '/admin/incidents',
            builder: (context, state) => const AdminShellPage(),
          ),
          GoRoute(
            path: '/admin/payments-history',
            builder: (context, state) => const AdminShellPage(),
          ),
          GoRoute(
            path: '/admin/ratings',
            builder: (context, state) => const AdminShellPage(),
          ),
          GoRoute(
            path: '/admin/system',
            builder: (context, state) => const AdminShellPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/operator/panel',
        builder: (context, state) => OperatorDashboardPage(),
      ),
      GoRoute(
        path: '/operator/cash-payments',
        builder: (context, state) => CashPaymentsPage(
          title: 'cobros_en_caja',
          currentRoute: '/operator/cash-payments',
        ),
      ),
      GoRoute(
        path: '/operator/reservations',
        builder: (context, state) => AdminReservationsPage(
          title: 'reservas_operativas',
          currentRoute: '/operator/reservations',
        ),
      ),
      GoRoute(
        path: '/operator/incidents',
        builder: (context, state) => AdminIncidentsPage(
          title: 'admin_incidents_operator_title',
          currentRoute: '/operator/incidents',
        ),
      ),
      GoRoute(
        path: '/support/incidents',
        builder: (context, state) => AdminIncidentsPage(
          title: 'admin_incidents_support_title',
          currentRoute: '/support/incidents',
        ),
      ),
      GoRoute(
        path: '/operator/tracking',
        builder: (context, state) => DeliveryMonitorPage(
          title: 'tracking_logistico',
          currentRoute: '/operator/tracking',
        ),
      ),
      GoRoute(
        path: '/operator/tracking/:reservationId',
        builder: (_, state) => TrackingPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
          title: 'tracking_logistico',
          currentRoute: '/operator/tracking',
          backofficeMode: true,
        ),
      ),
      GoRoute(
        path: '/courier/panel',
        builder: (context, state) => CourierDashboardPage(),
      ),
      GoRoute(
        path: '/courier/services',
        builder: (context, state) => CourierServicesPage(),
      ),
      GoRoute(
        path: '/courier/tracking/:reservationId',
        builder: (_, state) => TrackingPage(
          reservationId: state.pathParameters['reservationId'] ?? '',
          title: 'tracking_courier',
          currentRoute: '/courier/services',
          backofficeMode: true,
        ),
      ),
      GoRoute(
        path: '/debug/text',
        builder: (_, state) => const DebugTextPage(),
      ),
    ],
    errorBuilder: (_, state) {
      return Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: Text('${context.l10n.t('route_not_found')}: ${state.uri}'),
          ),
        ),
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
