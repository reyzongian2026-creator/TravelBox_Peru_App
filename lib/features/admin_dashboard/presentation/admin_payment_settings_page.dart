import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/app_smart_image.dart';

final _paymentSettingsProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  // Depend on session so the request waits until auth token is available
  final session = ref.watch(sessionControllerProvider);
  if (session.accessToken == null || session.accessToken!.isEmpty) {
    return {};
  }
  final dio = ref.read(dioProvider);
  final response = await dio.get<Map<String, dynamic>>('/admin/settings');
  final data = response.data ?? {};
  return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
});

class AdminPaymentSettingsPage extends ConsumerStatefulWidget {
  const AdminPaymentSettingsPage({super.key});

  @override
  ConsumerState<AdminPaymentSettingsPage> createState() =>
      _AdminPaymentSettingsPageState();
}

class _AdminPaymentSettingsPageState
    extends ConsumerState<AdminPaymentSettingsPage> {
  final _yapePhoneController = TextEditingController();
  final _yapeNameController = TextEditingController();
  final _plinPhoneController = TextEditingController();
  final _plinNameController = TextEditingController();
  final _qrPhoneController = TextEditingController();
  final _qrNameController = TextEditingController();
  String? _yapeQrUrl;
  String? _plinQrUrl;
  String? _qrQrUrl;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _yapePhoneController.dispose();
    _yapeNameController.dispose();
    _plinPhoneController.dispose();
    _plinNameController.dispose();
    _qrPhoneController.dispose();
    _qrNameController.dispose();
    super.dispose();
  }

  void _loadSettings(Map<String, String> settings) {
    _yapePhoneController.text = settings['payments.yape.phone'] ?? '';
    _yapeNameController.text = settings['payments.yape.name'] ?? '';
    _plinPhoneController.text = settings['payments.plin.phone'] ?? '';
    _plinNameController.text = settings['payments.plin.name'] ?? '';
    _qrPhoneController.text = settings['payments.qr.phone'] ?? '';
    _qrNameController.text = settings['payments.qr.name'] ?? '';
    _yapeQrUrl = settings['payments.yape.qr_url'];
    _plinQrUrl = settings['payments.plin.qr_url'];
    _qrQrUrl = settings['payments.qr.qr_url'];
  }

  Future<void> _saveSetting(String key, String value) async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/admin/settings/$key', data: {'value': value});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Configuracion guardada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadQr(String method) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) return;
    final mediaType = _resolveImageMediaType(file);
    if (mediaType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formato no soportado. Usa PNG, JPG o WebP.'),
          ),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
          contentType: mediaType,
        ),
      });
      final response = await dio.post<Map<String, dynamic>>(
        '/admin/settings/upload-qr/$method',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final qrUrl = response.data?['qrUrl']?.toString();
      if (mounted) {
        setState(() {
          if (method == 'yape') _yapeQrUrl = qrUrl;
          if (method == 'plin') _plinQrUrl = qrUrl;
          if (method == 'qr') _qrQrUrl = qrUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR de ${method.toUpperCase()} subido correctamente'),
          ),
        );
        ref.invalidate(_paymentSettingsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error subiendo QR: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  MediaType? _resolveImageMediaType(PlatformFile file) {
    final filename = file.name.trim().toLowerCase();
    final extension =
        file.extension?.trim().toLowerCase() ??
        (filename.contains('.') ? filename.split('.').last : '');
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'webp' => MediaType('image', 'webp'),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(_paymentSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion de Pagos Manuales')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error cargando configuracion: $e')),
        data: (settings) {
          // Load only once
          if (_yapePhoneController.text.isEmpty && settings.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadSettings(settings);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMethodSection(
                  title: 'Yape',
                  color: TravelBoxBrand.yape,
                  icon: Icons.qr_code_2,
                  phoneController: _yapePhoneController,
                  nameController: _yapeNameController,
                  qrUrl: _yapeQrUrl,
                  phoneKey: 'payments.yape.phone',
                  nameKey: 'payments.yape.name',
                  method: 'yape',
                ),
                const SizedBox(height: 32),
                _buildMethodSection(
                  title: 'Plin',
                  color: TravelBoxBrand.plin,
                  icon: Icons.phone_android,
                  phoneController: _plinPhoneController,
                  nameController: _plinNameController,
                  qrUrl: _plinQrUrl,
                  phoneKey: 'payments.plin.phone',
                  nameKey: 'payments.plin.name',
                  method: 'plin',
                ),
                const SizedBox(height: 32),
                _buildMethodSection(
                  title: 'QR Universal',
                  color: TravelBoxBrand.qrPayment,
                  icon: Icons.qr_code,
                  phoneController: _qrPhoneController,
                  nameController: _qrNameController,
                  qrUrl: _qrQrUrl,
                  phoneKey: 'payments.qr.phone',
                  nameKey: 'payments.qr.name',
                  method: 'qr',
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Verificacion activa: Los pagos por Yape se verifican '
                          'automaticamente mediante las notificaciones de correo. '
                          'El operador puede revisar y confirmar manualmente en '
                          'caso de que sea necesario.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMethodSection({
    required String title,
    required Color color,
    required IconData icon,
    required TextEditingController phoneController,
    required TextEditingController nameController,
    required String? qrUrl,
    required String phoneKey,
    required String nameKey,
    required String method,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Numero de telefono $title',
                hintText: '999888777',
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nombre del destinatario',
                hintText: 'InkaVoy Peru',
                prefixIcon: const Icon(Icons.person),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            await _saveSetting(
                              phoneKey,
                              phoneController.text.trim(),
                            );
                            await _saveSetting(
                              nameKey,
                              nameController.text.trim(),
                            );
                          },
                    icon: const Icon(Icons.save),
                    label: Text(_saving ? 'Guardando...' : 'Guardar datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Codigo QR de $title',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (qrUrl != null && qrUrl.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppSmartImage(
                    source: qrUrl,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    fallback: const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: Text('No se pudo cargar la imagen')),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Sin QR configurado',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : () => _uploadQr(method),
                icon: Icon(
                  _uploading ? Icons.hourglass_top : Icons.upload_file,
                ),
                label: Text(
                  _uploading ? 'Subiendo...' : 'Subir imagen QR de $title',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
