import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/features/payments/data/payment_repository.dart';

void main() {
  group('PaymentIntentResult', () {
    test('parses alternate identifiers and 3DS flow', () {
      final result = PaymentIntentResult.fromJson({
        'paymentIntentId': 42,
        'amount': 120.5,
        'status': 'PENDING',
        'paymentFlow': 'REQUIRES_3DS_AUTH',
        'nextAction': {
          'type': 'AUTHENTICATE_3DS',
          'providerPayload': {'authenticationUrl': 'https://3ds.example.com'},
        },
      });

      expect(result.id, '42');
      expect(result.requires3ds, isTrue);
      expect(result.threeDsUrl, 'https://3ds.example.com');
      expect(result.isConfirmed, isFalse);
      expect(result.isFailed, isFalse);
    });

    test('detects manual transfer, izipay checkout and failure states', () {
      final manual = PaymentIntentResult.fromJson({
        'id': 'A1',
        'amount': 50,
        'status': 'PENDING',
        'paymentFlow': 'WAITING_MANUAL_TRANSFER',
        'nextAction': {'type': 'SHOW_TRANSFER_QR'},
      });
      final checkout = PaymentIntentResult.fromJson({
        'id': 'B1',
        'amount': 50,
        'status': 'PENDING',
        'paymentFlow': 'OPEN_IZIPAY_CHECKOUT',
        'nextAction': {'type': 'OPEN_IZIPAY_CHECKOUT'},
      });
      final failed = PaymentIntentResult.fromJson({
        'id': 'C1',
        'amount': 50,
        'status': 'FAILED',
        'paymentFlow': 'CARD_REJECTED',
      });

      expect(manual.requiresManualTransfer, isTrue);
      expect(checkout.requiresIzipayCheckout, isTrue);
      expect(failed.isFailed, isTrue);
    });

    test('treats direct flows as confirmed and offline as waiting', () {
      final confirmed = PaymentIntentResult.fromJson({
        'id': 'D1',
        'amount': 80,
        'status': 'PENDING',
        'paymentFlow': 'DIRECT_CHARGE',
      });
      final offline = PaymentIntentResult.fromJson({
        'id': 'E1',
        'amount': 80,
        'status': 'PENDING',
        'paymentFlow': 'WAITING_OFFLINE_VALIDATION',
      });

      expect(confirmed.isConfirmed, isTrue);
      expect(offline.isWaitingOffline, isTrue);
    });
  });

  group('PaymentStatusResult', () {
    test('maps status aliases and convenience booleans', () {
      final pending = PaymentStatusResult.fromJson({
        'id': 9,
        'status': 'PENDING',
        'amount': 10,
      });
      final confirmed = PaymentStatusResult.fromJson({
        'paymentIntentId': 10,
        'paymentStatus': 'CONFIRMED',
        'amount': 10,
      });
      final failed = PaymentStatusResult.fromJson({
        'paymentIntentId': 11,
        'paymentStatus': 'REJECTED',
        'amount': 10,
      });

      expect(pending.paymentIntentId, '9');
      expect(pending.isPending, isTrue);
      expect(confirmed.isConfirmed, isTrue);
      expect(failed.isFailed, isTrue);
    });
  });

  group('Payment repository models', () {
    test('SavedCard applies defaults', () {
      final card = SavedCard.fromJson({'id': 7});

      expect(card.id, '7');
      expect(card.alias, 'Tarjeta');
      expect(card.brand, 'Visa');
      expect(card.lastFourDigits, '****');
    });

    test('PaymentHistoryItem uses paymentMethod fallback', () {
      final item = PaymentHistoryItem.fromJson({
        'id': 'P1',
        'reservationId': 'R1',
        'reservationCode': 'TBX-001',
        'amount': 99.9,
        'status': 'CONFIRMED',
        'paymentMethod': 'wallet',
        'createdAt': '2026-04-07T10:00:00Z',
      });

      expect(item.method, 'wallet');
      expect(item.confirmedAt, isNull);
    });

    test('CashPendingPayment parses optional customer fields', () {
      final item = CashPendingPayment.fromJson({
        'id': 'CASH-1',
        'reservationId': 'R1',
        'reservationCode': 'TBX-001',
        'amount': 25,
        'status': 'PENDING',
        'createdAt': '2026-04-07T10:00:00Z',
        'customerName': 'Ana',
        'customerEmail': 'ana@example.com',
      });

      expect(item.customerName, 'Ana');
      expect(item.customerEmail, 'ana@example.com');
    });
  });
}
