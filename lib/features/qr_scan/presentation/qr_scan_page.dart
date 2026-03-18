import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../shared/state/session_controller.dart';

class QrScanPage extends ConsumerStatefulWidget {
  QrScanPage({super.key, this.currentRoute = '/qr-scan'});

  final String currentRoute;

  @override
  ConsumerState<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends ConsumerState<QrScanPage> {
  late final MobileScannerController _cameraController;
  bool _handlingScan = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      autoStart: _supportsLiveCamera,
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
    _cameraController.addListener(_refreshScannerState);
  }

  @override
  void dispose() {
    _cameraController.removeListener(_refreshScannerState);
    _cameraController.dispose();
    super.dispose();
  }

  bool get _supportsLiveCamera {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    final scannerState = _cameraController.value;
    final torchEnabled = scannerState.torchState == TorchState.on;
    final cameraReady = scannerState.isInitialized && scannerState.isRunning;

    return AppShellScaffold(
      title: 'Escanear QR',
      currentRoute: widget.currentRoute,
      actions: [
        if (_supportsLiveCamera)
          IconButton(
            tooltip: torchEnabled ? 'Apagar flash' : 'Encender flash',
            onPressed: () => _cameraController.toggleTorch(),
            icon: Icon(
              torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
          ),
        if (_supportsLiveCamera)
          IconButton(
            tooltip: 'Cambiar camara',
            onPressed: () => _cameraController.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
      ],
      child: _supportsLiveCamera
          ? _buildLiveScanner(cameraReady: cameraReady)
          : _buildFallbackView(),
    );
  }

  Widget _buildLiveScanner({required bool cameraReady}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: (capture) {
            if (_handlingScan) return;
            final code = capture.barcodes
                .map((item) => item.rawValue?.trim())
                .whereType<String>()
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
            if (code.isEmpty) {
              return;
            }
            _handleScanResult(code);
          },
          fit: BoxFit.cover,
          errorBuilder: (_, error, child) {
            return Center(child: Text('No se pudo abrir la camara: $error'));
          },
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                cameraReady
                    ? 'Apunta la camara al QR. Se abrira automaticamente.'
                    : 'Iniciando camara...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 44),
                const SizedBox(height: 10),
                const Text(
                  'Escaneo por camara disponible en Android/iOS/Web.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => context.go('/ops/qr-handoff'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(context.l10n.t('abrir_modulo_qrpin')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleScanResult(String value) async {
    if (_handlingScan) return;
    _handlingScan = true;

    await _cameraController.stop();
    if (!mounted) return;

    final session = ref.read(sessionControllerProvider);
    if (session.isAdmin || session.canAccessAdmin || session.isCourier) {
      context.go('/ops/qr-handoff?scan=${Uri.encodeComponent(value)}');
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('QR detectado: $value')));
    context.go('/reservations');
  }

  void _refreshScannerState() {
    if (!mounted) return;
    setState(() {});
  }
}

