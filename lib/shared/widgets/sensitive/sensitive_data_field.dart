import 'package:flutter/material.dart';

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

  String? _defaultValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }

    switch (widget.type) {
      case SensitiveDataType.dni:
      case SensitiveDataType.ruc:
        if (value.length < 8) {
          return 'Debe tener al menos 8 caracteres';
        }
        break;
      case SensitiveDataType.passport:
        if (value.length < 6) {
          return 'Debe tener al menos 6 caracteres';
        }
        break;
      case SensitiveDataType.phone:
        if (value.length < 7) {
          return 'Debe tener al menos 7 caracteres';
        }
        break;
      case SensitiveDataType.creditCard:
        if (value.length < 13) {
          return 'Número de tarjeta inválido';
        }
        break;
      default:
        break;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                      'Requiere verificación',
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
          validator: widget.validator ?? _defaultValidator,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Ingrese ${widget.label.toLowerCase()}',
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
                  tooltip: _showFullValue ? 'Ocultar' : 'Mostrar',
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
                    'Para guardar cambios en datos sensibles, deberás verificar tu contraseña.',
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
