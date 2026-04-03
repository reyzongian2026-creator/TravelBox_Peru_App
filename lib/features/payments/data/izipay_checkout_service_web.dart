// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

import 'izipay_checkout_service.dart';

/// Lyra V4 Krypton SmartForm Pop-in integration for Flutter Web.
///
/// Uses the official KR JavaScript client from static.micuentaweb.pe
/// with the `kr-popin` attribute for popup-mode payment form.
/// Reference: https://github.com/izipay-pe/Popin-PaymentForm-Angular
class _WebIzipayCheckoutService implements IzipayCheckoutService {
  static const _scriptElementId = 'travelbox-kr-sdk';
  static const _cssElementId = 'travelbox-kr-css';
  static const _themeElementId = 'travelbox-kr-theme';
  static const _containerId = 'kr-payment-container';

  @override
  Future<IzipayCheckoutOutcome> openCheckout(IzipayCheckoutRequest request) async {
    // 1. Load the Krypton script + theme CSS/JS
    await _ensureKryptonLoaded(request.scriptUrl, request.publicKey);

    // 2. Wait for KR global to be available
    await _waitForKR();

    // 3. Create the container div with kr-embedded kr-popin
    _ensureContainerDiv();

    // 4. Set up payment callback + run KR integration via JS
    final completer = Completer<IzipayCheckoutOutcome>();

    void completeOnce(IzipayCheckoutOutcome outcome) {
      if (!completer.isCompleted) {
        completer.complete(outcome);
      }
    }

    // Expose callbacks to JavaScript
    js.context['__tbxOnPaymentComplete'] = js.JsFunction.withThis(
      (dynamic _, [dynamic paymentDataJson]) {
        final data = _parseJson(paymentDataJson?.toString());
        completeOnce(IzipayCheckoutOutcome(
          status: IzipayCheckoutOutcomeStatus.completed,
          response: data,
          message: data['orderStatus']?.toString() ?? 'Pago completado',
        ));
      },
    );

    js.context['__tbxOnPaymentError'] = js.JsFunction.withThis(
      (dynamic _, [dynamic errorJson]) {
        final data = _parseJson(errorJson?.toString());
        completeOnce(IzipayCheckoutOutcome(
          status: IzipayCheckoutOutcomeStatus.error,
          response: data,
          message: data['errorMessage']?.toString() ??
              data['detailedErrorMessage']?.toString() ??
              errorJson?.toString() ??
              'Error en el pago',
        ));
      },
    );

    // Pass the formToken safely to JS (avoid eval injection)
    js.context['__tbxFormToken'] = request.authorization;

    // Execute the KR integration code
    try {
      js.context.callMethod('eval', <dynamic>[_krPopinCode]);
    } catch (e) {
      completeOnce(IzipayCheckoutOutcome(
        status: IzipayCheckoutOutcomeStatus.error,
        message: 'Error al inicializar el formulario de pago: $e',
      ));
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        // Try to close popin on timeout
        try {
          final kr = js.context['KR'];
          kr?.callMethod('closePopin', <dynamic>[]);
        } catch (_) {}
        return const IzipayCheckoutOutcome(
          status: IzipayCheckoutOutcomeStatus.timedOut,
          message: 'El checkout no respondio a tiempo.',
        );
      },
    );
  }

  /// JavaScript code that uses the KR API to show the payment pop-in.
  /// The formToken is read from window.__tbxFormToken (set by Dart).
  /// Results are passed back via window.__tbxOnPaymentComplete / __tbxOnPaymentError.
  static const _krPopinCode = r'''
(function() {
  var formToken = window.__tbxFormToken;
  var KR = window.KR;
  if (!KR) {
    window.__tbxOnPaymentError(JSON.stringify({errorMessage: "KR SDK no disponible"}));
    return;
  }

  KR.setFormConfig({
    formToken: formToken,
    'kr-language': 'es-ES'
  }).then(function(res) {
    return res.KR.addForm('#kr-payment-container');
  }).then(function(res) {
    return res.KR.showForm(res.result.formId);
  }).catch(function(err) {
    var msg = (err && err.errorMessage) ? err.errorMessage : JSON.stringify(err);
    window.__tbxOnPaymentError(JSON.stringify({errorMessage: msg}));
  });

  KR.onSubmit(function(paymentData) {
    try { KR.closePopin(); } catch(e) {}
    window.__tbxOnPaymentComplete(JSON.stringify(paymentData.clientAnswer || paymentData));
    return false;
  });

  KR.onError(function(event) {
    var errors = event.errorCode ? event : (event.metadata || event);
    window.__tbxOnPaymentError(JSON.stringify(errors));
  });
})();
''';

  /// Load the Krypton payment script with kr-public-key attribute,
  /// plus the neon theme CSS and JS for styling.
  Future<void> _ensureKryptonLoaded(String scriptUrl, String publicKey) async {
    // Derive the base endpoint from the script URL
    final baseEndpoint = _extractEndpoint(scriptUrl);

    // Load CSS theme (neon)
    _ensureCssLoaded(
      _cssElementId,
      '$baseEndpoint/static/js/krypton-client/V4.0/ext/neon-reset.css',
    );

    // Load theme JS (neon)
    await _ensureScriptLoaded(
      _themeElementId,
      '$baseEndpoint/static/js/krypton-client/V4.0/ext/neon.js',
      attributes: <String, String>{},
    );

    // Load the main KR script with kr-public-key
    await _ensureScriptLoaded(
      _scriptElementId,
      scriptUrl,
      attributes: <String, String>{
        'kr-public-key': publicKey,
        'kr-post-url-success': 'javascript:void(0)',
      },
    );
  }

  /// Extract the domain/endpoint from a full script URL.
  /// E.g. "https://static.micuentaweb.pe/static/js/..." → "https://static.micuentaweb.pe"
  String _extractEndpoint(String scriptUrl) {
    try {
      final uri = Uri.parse(scriptUrl);
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return 'https://static.micuentaweb.pe';
    }
  }

  /// Ensure a <link rel="stylesheet"> element is in the document head.
  void _ensureCssLoaded(String elementId, String href) {
    if (html.document.getElementById(elementId) != null) return;
    final link = html.LinkElement()
      ..id = elementId
      ..rel = 'stylesheet'
      ..href = href;
    html.document.head?.append(link);
  }

  /// Ensure a <script> element is loaded. Returns a Future that completes on load.
  Future<void> _ensureScriptLoaded(
    String elementId,
    String src, {
    Map<String, String> attributes = const {},
  }) async {
    final existing = html.document.getElementById(elementId);
    if (existing is html.ScriptElement) {
      if (existing.src.trim() == src.trim()) return;
      existing.remove();
    }

    final script = html.ScriptElement()
      ..id = elementId
      ..src = src;

    for (final entry in attributes.entries) {
      script.setAttribute(entry.key, entry.value);
    }

    final completer = Completer<void>();
    script.onLoad.first.then((_) {
      if (!completer.isCompleted) completer.complete();
    });
    script.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('No se pudo cargar el script: $src'),
        );
      }
    });
    html.document.head?.append(script);
    await completer.future;
  }

  /// Poll for the KR global object to become available (max 10 seconds).
  Future<void> _waitForKR() async {
    for (var i = 0; i < 50; i++) {
      if (js.context['KR'] != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError('El SDK de Krypton (KR) no se cargo correctamente.');
  }

  /// Create/reset the container div for the KR embedded popin form.
  void _ensureContainerDiv() {
    var container = html.document.getElementById(_containerId);
    if (container != null) {
      container.innerHtml = '';
    } else {
      container = html.DivElement()..id = _containerId;
      html.document.body?.append(container);
    }
    // Inner div required by KR: class="kr-embedded" with kr-popin attribute
    final innerDiv = html.DivElement()
      ..className = 'kr-embedded'
      ..setAttribute('kr-popin', '');
    container!.append(innerDiv);
  }

  Map<String, dynamic> _parseJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{'raw': jsonStr};
  }
}

IzipayCheckoutService createPlatformIzipayCheckoutService() =>
    _WebIzipayCheckoutService();
