import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env/app_env.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/country_catalog.dart';
import '../../../shared/utils/image_upload_validator.dart';
import '../../../shared/utils/form_validators.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../incidents/data/selected_evidence_image.dart';
import '../data/profile_repository_impl.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key, this.forceComplete = false});

  final bool forceComplete;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  static const _supportedLanguages = <String>{'es', 'en'};

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
  bool _currentPasswordVisible = false;
  String _nationality = 'Peru';
  late CountryDialingInfo _dialingCountry;
  String _preferredLanguage = 'es';
  String _documentType = 'PASSPORT';
  late final String _initialEmail;
  late final String _initialPhone;
  late final String _initialDocumentNumber;
  SelectedEvidenceImage? _selectedPhoto;

  AppUser? get _user => ref.read(sessionControllerProvider).user;
  bool get _storageUploadsEnabled => AppEnv.azureStorageUploadsEnabled;

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
      text: extractLocalNumber(
        country: _dialingCountry,
        rawPhone: user?.emergencyContactPhone ?? '',
      ),
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
    _preferredLanguage = _supportedLanguages.contains(preferred)
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
    final l10n = context.l10n;
    final languageOptions = <String, String>{
      'es': l10n.t('spanish'),
      'en': l10n.t('english'),
    };
    final user = ref.watch(sessionControllerProvider).user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (!user.canSelfEditProfile && !widget.forceComplete) {
      return AppShellScaffold(
        title: l10n.t('profile_managed_title'),
        currentRoute: '/profile/edit',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: TravelBoxBrand.adminCardBg,
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(context.l10n.t('edicion_bloqueada')),
                subtitle: Text(l10n.t('profile_internal_edit_admin_only')),
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
      title: widget.forceComplete
          ? l10n.t('profile_complete_title')
          : l10n.t('profile_edit_title'),
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
                color: TravelBoxBrand.sensitiveCardBg,
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text(context.l10n.t('cambio_sensible_detectado')),
                  subtitle: Text(
                    context.l10n.t('profile_sensitive_changes_password_notice'),
                  ),
                ),
              ),
            if (_requiresSensitiveReauth && _requiresLocalPasswordReauth)
              SizedBox(height: 12),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: l10n.t('profile_first_name'),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => FormValidators.requiredText(
                value,
                label: l10n.t('first_name').toLowerCase(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: l10n.t('profile_last_name'),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => FormValidators.requiredText(
                value,
                label: l10n.t('last_name').toLowerCase(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.t('email'),
                helperText:
                    '${l10n.t('profile_remaining_changes_prefix')} '
                    '${user.emailChangeRemaining} '
                    '${l10n.t('profile_remaining_changes_suffix')}',
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
              decoration: InputDecoration(labelText: l10n.t('profile_prefix')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneLocalNumberController,
              decoration: InputDecoration(
                labelText: l10n.t('profile_phone_number'),
                hintText: _dialingCountry.phoneHint,
                helperText:
                    '${l10n.t('profile_remaining_changes_prefix')} '
                    '${user.phoneChangeRemaining}. '
                    '${l10n.t('profile_format_prefix')} '
                    '${_dialingCountry.countryName}: '
                    '${_dialingCountry.phoneMinDigits}-'
                    '${_dialingCountry.phoneMaxDigits} '
                    '${l10n.t('profile_digits')}',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (value) => validateInternationalPhone(
                country: _dialingCountry,
                localNumber: value ?? '',
                label: context.l10n.t('valid_phone_label'),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _nationality,
              decoration: InputDecoration(labelText: l10n.t('nationality')),
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
              isExpanded: true,
              initialValue: _preferredLanguage,
              decoration: InputDecoration(labelText: l10n.t('language')),
              items: languageOptions.entries
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
              decoration: InputDecoration(labelText: l10n.t('address')),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.trim().length < 3) {
                  return l10n.t('validation_min_length').replaceAll('{min}', '3');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityController,
              decoration: InputDecoration(labelText: l10n.t('city')),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.trim().length < 2) {
                  return l10n.t('validation_min_length').replaceAll('{min}', '2');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _countryController,
              decoration: InputDecoration(labelText: l10n.t('country')),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.trim().length < 2) {
                  return l10n.t('validation_min_length').replaceAll('{min}', '2');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _documentType,
              decoration: InputDecoration(
                labelText: l10n.t('profile_document_type'),
                helperText:
                    '${l10n.t('profile_remaining_changes_prefix')} '
                    '${user.documentChangeRemaining} '
                    '${l10n.t('profile_remaining_changes_suffix')}',
              ),
              items: [
                DropdownMenuItem(
                  value: 'DNI',
                  child: Text(context.l10n.t('dni')),
                ),
                DropdownMenuItem(
                  value: 'PASSPORT',
                  child: Text(context.l10n.t('pasaporte')),
                ),
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
                DropdownMenuItem(
                  value: 'OTHER',
                  child: Text(context.l10n.t('otro_valido')),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _documentType = value);
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _documentNumberController,
              decoration: InputDecoration(
                labelText: l10n.t('profile_document_number'),
              ),
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
              decoration: InputDecoration(
                labelText: l10n.t('profile_secondary_document_optional'),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyNameController,
              decoration: InputDecoration(
                labelText: l10n.t('profile_emergency_contact'),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyPhoneController,
              decoration: InputDecoration(
                labelText: l10n.t('profile_emergency_phone'),
                hintText: _dialingCountry.phoneHint,
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final rawValue = value?.trim() ?? '';
                if (rawValue.isEmpty) {
                  return null;
                }
                return validateInternationalPhone(
                  country: _dialingCountry,
                  localNumber: rawValue,
                  label: context.l10n.t('valid_emergency_phone_label'),
                );
              },
            ),
            if (_requiresLocalPasswordReauth) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: !_currentPasswordVisible,
                decoration: InputDecoration(
                  labelText: context.l10n.t(
                    'current_password_sensitive_changes',
                  ),
                  suffixIcon: IconButton(
                    tooltip: _currentPasswordVisible
                        ? context.l10n.t('hide_password')
                        : context.l10n.t('show_password'),
                    onPressed: () => setState(
                      () => _currentPasswordVisible = !_currentPasswordVisible,
                    ),
                    icon: Icon(
                      _currentPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) =>
                    _requiresSensitiveReauth && _requiresLocalPasswordReauth
                    ? FormValidators.requiredText(
                        value,
                        label: context.l10n.t('current_password_label'),
                        minLength: 8,
                      )
                    : null,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: Text(
                _loading
                    ? l10n.t('profile_saving')
                    : l10n.t('profile_save_button'),
              ),
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
        SnackBar(
          content: Text(
            context.l10n.t('profile_photo_storage_disabled_notice'),
          ),
        ),
      );
      return;
    }
    final t = context.l10n.t;
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
    final validationMessage = await validateSelectedImageForUpload(
      bytes: file.bytes!,
      t: t,
    );
    if (validationMessage != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
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
            '${context.l10n.t('profile_save_failed')}: '
            '${AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}',
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
        'emergencyContactPhone': normalizeInternationalPhone(
          country: _dialingCountry,
          localNumber: _emergencyPhoneController.text,
        ),
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
                        ? Image.memory(selectedPhoto!.bytes, fit: BoxFit.cover)
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
                      Text(
                        context.l10n.t('profile_photo_title'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        uploadsEnabled
                            ? selectedPhoto != null
                                  ? context.l10n.t(
                                      'profile_photo_ready_to_upload',
                                    )
                                  : context.l10n.t(
                                      'profile_photo_loaded_from_storage',
                                    )
                            : context.l10n.t(
                                'profile_photo_storage_not_available',
                              ),
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
            Text(
              context.l10n.t('profile_update_limits_title'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RemainingChip(
                  label: context.l10n.t('email'),
                  remaining: user.emailChangeRemaining,
                ),
                _RemainingChip(
                  label: context.l10n.t('profile_phone_number'),
                  remaining: user.phoneChangeRemaining,
                ),
                _RemainingChip(
                  label: context.l10n.t('profile_document_number'),
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
