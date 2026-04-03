// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

import 'izipay_checkout_service.dart';

class _WebIzipayCheckoutService implements IzipayCheckoutService {
  static const _scriptElementId = 'travelbox-izipay-sdk';

  @override
  Future<IzipayCheckoutOutcome> openCheckout(IzipayCheckoutRequest request) async {
    await _ensureSdkLoaded(request.scriptUrl);

    final izipayConstructor = js.context['Izipay'];
    if (izipayConstructor == null) {
      throw StateError('No se pudo inicializar el SDK de Izipay.');
    }

    final completer = Completer<IzipayCheckoutOutcome>();
    final checkout = js.JsObject(
      izipayConstructor,
      <dynamic>[js.JsObject.jsify({'config': request.checkoutConfig})],
    );

    void completeOnce(IzipayCheckoutOutcome outcome) {
      if (!completer.isCompleted) {
        completer.complete(outcome);
      }
    }

// Izipay PopUp SDK: solo usar LoadForm con authorization, keyRSA, callbackResponse
// El callbackResponse recibe todas las respuestas (éxito, cancel, error)
// discriminadas por el campo "code": "00" = éxito, "-1" = cancelado, otro = error

final callbackResponse = js.JsFunction.withThis((dynamic _, [dynamic response]) {
  final mapped = _asMap(response);
  final code = mapped['code']?.toString() ?? '';

  if (code == '00') {
    completeOnce(
      IzipayCheckoutOutcome(
        status: IzipayCheckoutOutcomeStatus.completed,
        response: mapped,
        message: mapped['messageUser']?.toString() ?? mapped['message']?.toString(),
      ),
    );
  } else if (code == '-1') {
    completeOnce(
      IzipayCheckoutOutcome(
        status: IzipayCheckoutOutcomeStatus.canceled,
        response: mapped,
        message: mapped['messageUser']?.toString() ?? mapped['message']?.toString() ?? 'Cancelado',
      ),
    );
  } else {
    completeOnce(
      IzipayCheckoutOutcome(
        status: IzipayCheckoutOutcomeStatus.error,
        response: mapped,
        message: mapped['messageUser']?.toString() ?? mapped['message']?.toString() ?? 'Error en el pago',
      ),
    );
  }
});

try {
  checkout.callMethod('LoadForm', <dynamic>[
    js.JsObject.jsify({
      'authorization': request.authorization,
      'keyRSA': request.keyRsa,
      'callbackResponse': callbackResponse,
    }),
  ]);
} catch (e) {
  completeOnce(
    IzipayCheckoutOutcome(
      status: IzipayCheckoutOutcomeStatus.error,
      message: 'Error al abrir el formulario de pago: $e',
    ),
  );
}

return completer.future.timeout(

      const Duration(minutes: 5),
      onTimeout: () => const IzipayCheckoutOutcome(
        status: IzipayCheckoutOutcomeStatus.timedOut,
        message: 'El checkout de Izipay no respondio a tiempo.',
      ),
    );
  }

  Future<void> _ensureSdkLoaded(String scriptUrl) async {
    final existing = html.document.getElementById(_scriptElementId);
    if (existing is html.ScriptElement) {
      final currentSrc = existing.src.trim();
      if (currentSrc == scriptUrl.trim() && js.context['Izipay'] != null) {
        return;
      }
      existing.remove();
    }

    final script = html.ScriptElement()
      ..id = _scriptElementId
      ..src = scriptUrl
      ..defer = true
      ..async = true;

    final completer = Completer<void>();
    script.onLoad.first.then((_) => completer.complete());
    script.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('No se pudo cargar el SDK de Izipay desde $scriptUrl'),
        );
      }
    });
    html.document.head?.append(script);
    await completer.future;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is js.JsObject || value is js.JsArray) {
      try {
        final jsonString = js.context['JSON'].callMethod('stringify', [value]);
        final decoded = jsonDecode(jsonString.toString());
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Ignore serialization errors and fall through.
      }
    }
    return <String, dynamic>{'raw': value.toString()};
  }
}

IzipayCheckoutService createPlatformIzipayCheckoutService() =>
    _WebIzipayCheckoutService();
