import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env/app_env.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/country_catalog.dart';
import '../../../shared/utils/form_validators.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../incidents/data/selected_evidence_image.dart';
import '../data/profile_repository_impl.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  EditProfilePage({super.key, this.forceComplete = false});

  final bool forceComplete;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  static const _languageOptions = <String, String>{
    'es': 'Espanol',
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Francais',
    'it': 'Italiano',
    'pt': 'Portugues',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneLocalNumberController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _documentNumberController;
  late final TextEditingController _secondaryDocumentNumberController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyPhoneController;
  late final TextEditingController _currentPasswordController;

  bool _loading = false;
  bool _showValidation = false;
  String _nationality = 'Peru';
  late CountryDialingInfo _dialingCountry;
  String _preferredLanguage = 'es';
  String _documentType = 'PASSPORT';
  late final String _initialEmail;
  late final String _initialPhone;
  late final String _initialDocumentNumber;
  SelectedEvidenceImage? _selectedPhoto;

  AppUser? get _user => ref.read(sessionControllerProvider).user;
  bool get _storageUploadsEnabled => AppEnv.firebaseStorageUploadsEnabled;

  bool get _requiresLocalPasswordReauth =>
      _user?.authProvider.toUpperCase() == 'LOCAL';

  @override
  void initState() {
    super.initState();
    final user = _user;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _dialingCountry = resolveCountryDialingByPhone(user?.phone);
    if ((user?.nationality ?? '').trim().isNotEmpty) {
      _dialingCountry = resolveCountryDialingByName(user!.nationality);
    }
    _phoneLocalNumberController = TextEditingController(
      text: extractLocalNumber(
        country: _dialingCountry,
        rawPhone: user?.phone ?? '',
      ),
    );
    _addressController = TextEditingController(text: user?.address ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');
    _countryController = TextEditingController(text: user?.country ?? 'Peru');
    _documentNumberController = TextEditingController(
      text: user?.documentNumber ?? '',
    );
    _secondaryDocumentNumberController = TextEditingController(
      text: user?.secondaryDocumentNumber ?? '',
    );
    _emergencyNameController = TextEditingController(
      text: user?.emergencyContactName ?? '',
    );
    _emergencyPhoneController = TextEditingController(
      text: user?.emergencyContactPhone ?? '',
    );
    _currentPasswordController = TextEditingController();
    _initialEmail = user?.email ?? '';
    _initialPhone = user?.phone ?? '';
    _initialDocumentNumber = user?.documentNumber ?? '';
    _nationality = (user?.nationality ?? '').trim().isNotEmpty
        ? user!.nationality
        : _dialingCountry.countryName;
    final preferred =
        user?.preferredLanguage ?? _dialingCountry.defaultLanguage;
    _preferredLanguage = _languageOptions.containsKey(preferred)
        ? preferred
        : _dialingCountry.defaultLanguage;
    _documentType = user?.documentType ?? 'PASSPORT';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneLocalNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _documentNumberController.dispose();
    _secondaryDocumentNumberController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (!user.canSelfEditProfile && !widget.forceComplete) {
      return AppShellScaffold(
        title: 'Perfil administrado',
        currentRoute: '/profile/edit',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFFF6F1E8),
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(context.l10n.t('edicion_bloqueada')),
                subtitle: const Text(
                  'Los usuarios internos solo pueden ser editados por un administrador desde el modulo de usuarios.',
                ),
              ),
            ),
            SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/profile'),
              child: Text(context.l10n.t('volver_al_perfil')),
            ),
          ],
        ),
      );
    }

    return AppShellScaffold(
      title: widget.forceComplete ? 'Completa tu perfil' : 'Editar perfil',
      currentRoute: widget.forceComplete
          ? '/profile/complete'
          : '/profile/edit',
      child: Form(
        key: _formKey,
        autovalidateMode: _showValidation
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfilePhotoCard(
              currentPhotoPath: user.profilePhotoPath,
              selectedPhoto: _selectedPhoto,
              uploadsEnabled: _storageUploadsEnabled,
              loading: _loading,
              onPickPhoto: _pickPhoto,
            ),
            SizedBox(height: 12),
            _RemainingChangesCard(user: user),
            const SizedBox(height: 12),
            if (_requiresSensitiveReauth && _requiresLocalPasswordReauth)
              Card(
                color: const Color(0xFFFFF7E8),
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text(context.l10n.t('cambio_sensible_detectado')),
                  subtitle: Text(
                    'Si cambias correo, telefono o documento debes confirmar tu contrasena actual antes de guardar.',
                  ),
                ),
              ),
            if (_requiresSensitiveReauth && _requiresLocalPasswordReauth)
              SizedBox(height: 12),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'Nombres'),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  FormValidators.requiredText(value, label: 'los nombres'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Apellidos'),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  FormValidators.requiredText(value, label: 'los apellidos'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Correo',
                helperText:
                    'Te quedan ${user.emailChangeRemaining} cambios para este campo.',
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: FormValidators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey(_dialingCountry.dialCode),
              initialValue: _dialingCountry.dialCode,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Prefijo'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneLocalNumberController,
              decoration: InputDecoration(
                labelText: 'Numero celular',
                hintText: _dialingCountry.phoneHint,
                helperText:
                    'Te quedan ${user.phoneChangeRemaining} cambios. Formato ${_dialingCountry.countryName}: ${_dialingCountry.phoneMinDigits}-${_dialingCountry.phoneMaxDigits} digitos',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (value) => validateInternationalPhone(
                country: _dialingCountry,
                localNumber: value ?? '',
                label: 'un telefono valido',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _nationality,
              decoration: const InputDecoration(labelText: 'Nacionalidad'),
              items: countryDialingCatalog
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.countryName,
                      child: Text('${item.countryName} (${item.dialCode})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final next = resolveCountryDialingByName(value);
                setState(() {
                  _nationality = value;
                  _dialingCountry = next;
                  _preferredLanguage = next.defaultLanguage;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _preferredLanguage,
              decoration: const InputDecoration(labelText: 'Idioma'),
              items: _languageOptions.entries
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.key,
                      child: Text(item.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _preferredLanguage = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Direccion'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Ciudad'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _countryController,
              decoration: const InputDecoration(labelText: 'Pais'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _documentType,
              decoration: InputDecoration(
                labelText: 'Tipo documento',
                helperText:
                    'Te quedan ${user.documentChangeRemaining} cambios para este campo.',
              ),
              items: [
                DropdownMenuItem(value: 'DNI', child: Text(context.l10n.t('dni'))),
                DropdownMenuItem(value: 'PASSPORT', child: Text(context.l10n.t('pasaporte'))),
                DropdownMenuItem(
                  value: 'FOREIGNER_CARD',
                  child: Text(context.l10n.t('carne_de_extranjeria')),
                ),
                DropdownMenuItem(
                  value: 'ID_CARD',
                  child: Text(context.l10n.t('cedula_de_identidad')),
                ),
                DropdownMenuItem(
                  value: 'DRIVER_LICENSE',
                  child: Text(context.l10n.t('licencia_de_conducir')),
                ),
                DropdownMenuItem(value: 'OTHER', child: Text(context.l10n.t('otro_valido'))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _documentType = value);
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _documentNumberController,
              decoration: const InputDecoration(labelText: 'Numero documento'),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (value) => FormValidators.documentNumber(
                value,
                documentType: _documentType,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _secondaryDocumentNumberController,
              decoration: const InputDecoration(
                labelText: 'Documento secundario (opcional)',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(
                labelText: 'Contacto de emergencia',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyPhoneController,
              decoration: const InputDecoration(
                labelText: 'Telefono de emergencia',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (value) => FormValidators.phone(
                value,
                required: false,
                label: 'un telefono de emergencia valido',
              ),
            ),
            if (_requiresLocalPasswordReauth) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contrasena actual para cambios sensibles',
                ),
                validator: (value) =>
                    _requiresSensitiveReauth && _requiresLocalPasswordReauth
                    ? FormValidators.requiredText(
                        value,
                        label: 'tu contrasena actual',
                        minLength: 8,
                      )
                    : null,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: Text(_loading ? 'Guardando...' : 'Guardar perfil'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (!_storageUploadsEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La foto de perfil seguira con imagen por defecto hasta habilitar Firebase Storage.',
          ),
        ),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result != null && result.files.isNotEmpty
        ? result.files.first
        : null;
    if (file == null || file.bytes == null) {
      return;
    }
    setState(() {
      _selectedPhoto = SelectedEvidenceImage(
        filename: file.name,
        mimeType: _guessMimeType(file.extension),
        bytes: file.bytes!,
      );
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _showValidation = true);
      return;
    }
    setState(() => _loading = true);
    try {
      final repository = ref.read(profileRepositoryProvider);
      if (_storageUploadsEnabled && _selectedPhoto != null) {
        final uploadedUser = await repository.uploadProfilePhoto(
          image: _selectedPhoto!,
        );
        await ref
            .read(sessionControllerProvider.notifier)
            .updateUser(uploadedUser);
      }

      final result = await repository.updateProfile(payload: _buildPayload());

      await ref
          .read(sessionControllerProvider.notifier)
          .updateUser(
            result.user,
            pendingVerificationCode: result.verificationCodePreview,
            clearPendingVerificationCode:
                result.verificationCodePreview == null,
          );

      if (!mounted) return;
      final session = ref.read(sessionControllerProvider);
      if (session.needsEmailVerification) {
        context.go('/verify-email');
        return;
      }
      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo guardar: ${AppErrorFormatter.readable(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': normalizeInternationalPhone(
        country: _dialingCountry,
        localNumber: _phoneLocalNumberController.text,
      ),
      'nationality': _nationality,
      'preferredLanguage': _preferredLanguage,
      if (_addressController.text.trim().isNotEmpty)
        'address': _addressController.text.trim(),
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_countryController.text.trim().isNotEmpty)
        'country': _countryController.text.trim(),
      if (_documentNumberController.text.trim().isNotEmpty)
        'documentType': _documentType,
      if (_documentNumberController.text.trim().isNotEmpty)
        'documentNumber': _documentNumberController.text.trim(),
      if (_secondaryDocumentNumberController.text.trim().isNotEmpty)
        'secondaryDocumentNumber': _secondaryDocumentNumberController.text
            .trim(),
      if (_emergencyNameController.text.trim().isNotEmpty)
        'emergencyContactName': _emergencyNameController.text.trim(),
      if (_emergencyPhoneController.text.trim().isNotEmpty)
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
    };
    if (_requiresSensitiveReauth &&
        _requiresLocalPasswordReauth &&
        _currentPasswordController.text.trim().isNotEmpty) {
      payload['currentPassword'] = _currentPasswordController.text.trim();
    }
    return payload;
  }

  bool get _requiresSensitiveReauth {
    final nextPhone = normalizeInternationalPhone(
      country: _dialingCountry,
      localNumber: _phoneLocalNumberController.text,
    );
    final emailChanged =
        _emailController.text.trim().toLowerCase() !=
        _initialEmail.toLowerCase();
    final phoneChanged = nextPhone.trim() != _initialPhone.trim();
    final documentChanged =
        _documentNumberController.text.trim() != _initialDocumentNumber.trim();
    return emailChanged || phoneChanged || documentChanged;
  }

  String _guessMimeType(String? extension) {
    final normalized = (extension ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/png';
    }
  }
}

class _ProfilePhotoCard extends StatelessWidget {
  const _ProfilePhotoCard({
    required this.currentPhotoPath,
    required this.selectedPhoto,
    required this.uploadsEnabled,
    required this.loading,
    required this.onPickPhoto,
  });

  final String? currentPhotoPath;
  final SelectedEvidenceImage? selectedPhoto;
  final bool uploadsEnabled;
  final bool loading;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: ClipOval(
                    child: selectedPhoto != null
                        ? Image.memory(
                            selectedPhoto!.bytes,
                            fit: BoxFit.cover,
                          )
                        : AppSmartImage(
                            source: currentPhotoPath,
                            fit: BoxFit.cover,
                            fallback: Container(
                              color: const Color(0xFFE6F0F4),
                              alignment: Alignment.center,
                              child: const Icon(Icons.person_outline),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto de perfil',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        uploadsEnabled
                            ? selectedPhoto != null
                                  ? 'Nueva foto lista para subirse a Firebase Storage.'
                                  : 'La imagen se carga por red desde Firebase Storage.'
                            : 'Firebase Storage aun no esta disponible. Se usara la imagen por defecto.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (uploadsEnabled) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: loading ? null : onPickPhoto,
                icon: const Icon(Icons.photo_camera_back_outlined),
                label: Text(context.l10n.t('cambiar_foto')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemainingChangesCard extends StatelessWidget {
  const _RemainingChangesCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Limites de actualizacion',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RemainingChip(
                  label: 'Correo',
                  remaining: user.emailChangeRemaining,
                ),
                _RemainingChip(
                  label: 'Telefono',
                  remaining: user.phoneChangeRemaining,
                ),
                _RemainingChip(
                  label: 'Documento',
                  remaining: user.documentChangeRemaining,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RemainingChip extends StatelessWidget {
  const _RemainingChip({required this.label, required this.remaining});

  final String label;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final background = remaining <= 0
        ? const Color(0xFFFBE2E2)
        : remaining == 1
        ? const Color(0xFFFFF1D6)
        : const Color(0xFFE8F3EC);
    final foreground = remaining <= 0
        ? const Color(0xFF9A3030)
        : remaining == 1
        ? const Color(0xFF8A5A15)
        : const Color(0xFF21613B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $remaining',
        style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

