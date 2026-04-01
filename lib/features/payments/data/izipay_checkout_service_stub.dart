import 'izipay_checkout_service.dart';

class _UnsupportedIzipayCheckoutService implements IzipayCheckoutService {
  @override
  Future<IzipayCheckoutOutcome> openCheckout(IzipayCheckoutRequest request) {
    throw UnsupportedError(
      'El checkout de Izipay solo esta disponible en Flutter web.',
    );
  }
}

IzipayCheckoutService createPlatformIzipayCheckoutService() =>
    _UnsupportedIzipayCheckoutService();
