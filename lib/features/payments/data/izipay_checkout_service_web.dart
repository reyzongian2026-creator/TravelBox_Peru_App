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
      (dynamic _, [dynamic paymentDataJson, dynamic rawAnswerStr, dynamic hashStr]) {
        _cleanupKryptonForm();
        final data = _parseJson(paymentDataJson?.toString());
        completeOnce(IzipayCheckoutOutcome(
          status: IzipayCheckoutOutcomeStatus.completed,
          response: data,
          message: data['orderStatus']?.toString() ?? 'Pago completado',
          rawClientAnswer: rawAnswerStr?.toString(),
          hash: hashStr?.toString(),
        ));
      },
    );

    js.context['__tbxOnPaymentError'] = js.JsFunction.withThis(
      (dynamic _, [dynamic errorJson]) {
        _cleanupKryptonForm();
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
        _cleanupKryptonForm();
        return const IzipayCheckoutOutcome(
          status: IzipayCheckoutOutcomeStatus.timedOut,
          message: 'El checkout no respondio a tiempo.',
        );
      },
    );
  }

  /// Close the Krypton popin and remove leftover DOM elements (the "Pagar" button).
  void _cleanupKryptonForm() {
    try {
      final kr = js.context['KR'];
      if (kr != null) {
        try { kr.callMethod('closePopin', <dynamic>[]); } catch (_) {}
        try { kr.callMethod('removeForms', <dynamic>[]); } catch (_) {}
      }
    } catch (_) {}
    try {
      html.document.getElementById('kr-payment-wrapper')?.remove();
      // Krypton may leave orphan overlays/backdrops in the body
      html.document.querySelectorAll('.kr-popin-modal-overlay, .kr-popin-modal, .kr-smart-form-modal-overlay, .kr-embedded')
          .forEach((el) => el.remove());
    } catch (_) {}
  }

  /// JavaScript code that uses the KR API to show the payment pop-in.
  ///
  /// Uses KR.renderElements() + KR.openPopin() with the modern SmartForm structure:
  ///   <div id="wrapper"><div class="kr-smart-form" kr-popin></div></div>
  ///
  /// IMPORTANT: renderElements() BEFORE setFormConfig({formToken}) to avoid
  /// KryptonPopinButton watcher error (component must exist before token is set).
  ///
  /// Reference: https://github.com/lyra/embedded-form-glue/blob/master/docs/kr_methods.md
  static const _krPopinCode = r'''
(function() {
  var formToken = window.__tbxFormToken;
  var KR = window.KR;
  if (!KR) {
    window.__tbxOnPaymentError(JSON.stringify({errorMessage: "KR SDK no disponible"}));
    return;
  }

  // 1. Remove previous forms cleanly
  var step1;
  try { step1 = KR.removeForms(); } catch(e) { step1 = Promise.resolve(); }

  step1.then(function() {
    // 2. Ensure the wrapper with kr-smart-form + kr-popin inner div
    var wrapper = document.getElementById('kr-payment-wrapper');
    if (!wrapper) {
      wrapper = document.createElement('div');
      wrapper.id = 'kr-payment-wrapper';
      document.body.appendChild(wrapper);
    }
    wrapper.innerHTML = '<div class="kr-smart-form" kr-popin></div>';

    // 3. Set language config only (NO formToken yet)
    return KR.setFormConfig({
      'kr-language': 'es-ES'
    });
  }).then(function(res) {
    // 4. Render elements FIRST (creates KryptonPopinButton component)
    return res.KR.renderElements('#kr-payment-wrapper');
  }).then(function(res) {
    // 5. NOW set the formToken (component already exists)
    return res.KR.setFormConfig({
      formToken: formToken
    });
  }).then(function(res) {
    // 6. Register event handlers
    return res.KR.onSubmit(function(paymentData) {
      var clientAnswer = paymentData.clientAnswer || paymentData;
      var rawAnswer = paymentData.rawClientAnswer || JSON.stringify(clientAnswer);
      var hash = paymentData.hash || '';
      window.__tbxOnPaymentComplete(JSON.stringify(clientAnswer), rawAnswer, hash);
      return false;
    });
  }).then(function(res) {
    return res.KR.onError(function(event) {
      var errors = event.errorCode ? event : (event.metadata || event);
      window.__tbxOnPaymentError(JSON.stringify(errors));
    });
  }).then(function(res) {
    // 7. Open the pop-in overlay
    return res.KR.openPopin();
  }).catch(function(err) {
    var msg = (err && err.errorMessage) ? err.errorMessage : JSON.stringify(err);
    window.__tbxOnPaymentError(JSON.stringify({errorMessage: msg}));
  });
})();
''';

  /// Load the Krypton payment script with kr-public-key attribute,
  /// plus the neon theme CSS and JS for styling.
  Future<void> _ensureKryptonLoaded(String scriptUrl, String publicKey) async {
    // Derive the base endpoint from the script URL
    final baseEndpoint = _extractEndpoint(scriptUrl);

    // Load CSS theme (classic — compatible with SmartForm/pop-in)
    _ensureCssLoaded(
      _cssElementId,
      '$baseEndpoint/static/js/krypton-client/V4.0/ext/classic-reset.css',
    );

    // Load theme JS (classic)
    await _ensureScriptLoaded(
      _themeElementId,
      '$baseEndpoint/static/js/krypton-client/V4.0/ext/classic.js',
      attributes: <String, String>{},
    );

    // Load the main KR script with kr-public-key + kr-spa-mode
    // kr-spa-mode is CRITICAL for SPAs — without it, KryptonPopinButton
    // Vue component lifecycle breaks on dynamic form creation.
    // See: https://github.com/lyra/embedded-form-glue/blob/master/app/KryptonGlue.js
    await _ensureScriptLoaded(
      _scriptElementId,
      scriptUrl,
      attributes: <String, String>{
        'kr-public-key': publicKey,
        'kr-spa-mode': 'true',
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
  /// If existing script has matching src AND same attributes, skip reload.
  /// Otherwise, remove & re-add to pick up new attributes (e.g. kr-spa-mode).
  Future<void> _ensureScriptLoaded(
    String elementId,
    String src, {
    Map<String, String> attributes = const {},
  }) async {
    final existing = html.document.getElementById(elementId);
    if (existing is html.ScriptElement) {
      // Check if src matches and all attributes match
      final srcMatch = existing.src.trim() == src.trim();
      var attrsMatch = true;
      for (final entry in attributes.entries) {
        if (existing.getAttribute(entry.key) != entry.value) {
          attrsMatch = false;
          break;
        }
      }
      if (srcMatch && attrsMatch) return;
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

  /// Ensure the wrapper div exists for the Krypton pop-in.
  /// Structure: <div id="kr-payment-wrapper"><div class="kr-embedded" kr-popin="true"></div></div>
  /// The inner div with kr-embedded + kr-popin="true" is created by the JS code.
  void _ensureContainerDiv() {
    var wrapper = html.document.getElementById('kr-payment-wrapper');
    if (wrapper != null) {
      wrapper.innerHtml = '';
      return;
    }
    wrapper = html.DivElement()..id = 'kr-payment-wrapper';
    html.document.body?.append(wrapper);
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
