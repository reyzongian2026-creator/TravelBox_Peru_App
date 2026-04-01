import 'izipay_checkout_service_stub.dart'
    if (dart.library.html) 'izipay_checkout_service_web.dart';

class IzipayCheckoutRequest {
  const IzipayCheckoutRequest({
    required this.scriptUrl,
    required this.authorization,
    required this.keyRsa,
    required this.checkoutConfig,
  });

  final String scriptUrl;
  final String authorization;
  final String keyRsa;
  final Map<String, dynamic> checkoutConfig;
}

enum IzipayCheckoutOutcomeStatus {
  completed,
  canceled,
  error,
  timedOut,
}

class IzipayCheckoutOutcome {
  const IzipayCheckoutOutcome({
    required this.status,
    this.response,
    this.message,
  });

  final IzipayCheckoutOutcomeStatus status;
  final Map<String, dynamic>? response;
  final String? message;

  bool get isCompleted => status == IzipayCheckoutOutcomeStatus.completed;
  bool get isCanceled => status == IzipayCheckoutOutcomeStatus.canceled;
}

abstract class IzipayCheckoutService {
  Future<IzipayCheckoutOutcome> openCheckout(IzipayCheckoutRequest request);
}

IzipayCheckoutService createIzipayCheckoutService() =>
    createPlatformIzipayCheckoutService();
