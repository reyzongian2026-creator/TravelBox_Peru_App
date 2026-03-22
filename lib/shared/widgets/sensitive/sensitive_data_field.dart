import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

enum SensitiveDataType {
  dni,
  ruc,
  passport,
  phone,
  address,
  gpsCoordinates,
  creditCard,
  bankAccount,
}

class SensitiveDataField extends StatefulWidget {
  final String label;
  final String initialValue;
  final SensitiveDataType type;
  final TextEditingController controller;
  final bool requireReauth;
  final String? hintText;
  final String? Function(String?)? validator;

  const SensitiveDataField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.type,
    required this.controller,
    this.requireReauth = false,
    this.hintText,
    this.validator,
  });

  @override
  State<SensitiveDataField> createState() => _SensitiveDataFieldState();
}

class _SensitiveDataFieldState extends State<SensitiveDataField> {
  bool _showFullValue = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue.isNotEmpty) {
      widget.controller.text = widget.initialValue;
    }
  }

  IconData _getIconForType(SensitiveDataType type) {
    switch (type) {
      case SensitiveDataType.dni:
      case SensitiveDataType.ruc:
      case SensitiveDataType.passport:
        return Icons.badge;
      case SensitiveDataType.phone:
        return Icons.phone;
      case SensitiveDataType.address:
        return Icons.location_on;
      case SensitiveDataType.gpsCoordinates:
        return Icons.my_location;
      case SensitiveDataType.creditCard:
        return Icons.credit_card;
      case SensitiveDataType.bankAccount:
        return Icons.account_balance;
    }
  }

  String? _defaultValidator(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.t('error_required_field');
    }

    switch (widget.type) {
      case SensitiveDataType.dni:
      case SensitiveDataType.ruc:
        if (value.length < 8) {
          return l10n.t('error_min_length_8');
        }
        break;
      case SensitiveDataType.passport:
        if (value.length < 6) {
          return l10n.t('error_min_length_6');
        }
        break;
      case SensitiveDataType.phone:
        if (value.length < 7) {
          return l10n.t('error_min_length_7');
        }
        break;
      case SensitiveDataType.creditCard:
        if (value.length < 13) {
          return l10n.t('error_invalid_credit_card');
        }
        break;
      default:
        break;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getIconForType(widget.type),
              size: 16,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (widget.requireReauth) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 10,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      l10n.t('field_reauth_required'),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: !_showFullValue,
          validator: widget.validator ?? (value) => _defaultValidator(value, l10n),
          decoration: InputDecoration(
            hintText: widget.hintText ?? l10n.t('field_enter_value').replaceAll('{label}', widget.label.toLowerCase()),
            filled: true,
            fillColor: Colors.orange.shade50.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.orange.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.orange.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _showFullValue ? Icons.visibility : Icons.visibility_off,
                    color: Colors.orange.shade700,
                  ),
                  onPressed: () {
                    setState(() {
                      _showFullValue = !_showFullValue;
                    });
                  },
                  tooltip: _showFullValue ? l10n.t('action_hide') : l10n.t('action_show'),
                ),
                if (widget.requireReauth)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.lock,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.requireReauth)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.t('reauth_message'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
