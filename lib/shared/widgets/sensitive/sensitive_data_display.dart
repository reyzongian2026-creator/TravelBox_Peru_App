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
  email,
}

class SensitiveDataDisplay extends StatelessWidget {
  final String label;
  final String? value;
  final SensitiveDataType type;
  final VoidCallback? onViewDetails;

  const SensitiveDataDisplay({
    super.key,
    required this.label,
    this.value,
    required this.type,
    this.onViewDetails,
  });

  String _maskSensitiveData(String? value, SensitiveDataType type) {
    if (value == null || value.isEmpty) return '---';

    switch (type) {
      case SensitiveDataType.dni:
      case SensitiveDataType.ruc:
      case SensitiveDataType.passport:
        if (value.length >= 4) {
          return '****-${value.substring(value.length - 4)}';
        }
        return '****';

      case SensitiveDataType.phone:
        if (value.length >= 4) {
          return '****-${value.substring(value.length - 4)}';
        }
        return '****';

      case SensitiveDataType.address:
        final parts = value.split(',');
        if (parts.length >= 2) {
          return '****, ${parts.last.trim()}';
        }
        return '****';

      case SensitiveDataType.gpsCoordinates:
        return '****, ****';

      case SensitiveDataType.creditCard:
        if (value.length >= 4) {
          return '****-****-****-${value.substring(value.length - 4)}';
        }
        return '****-****-****-****';

      case SensitiveDataType.bankAccount:
        if (value.length >= 4) {
          return '****-${value.substring(value.length - 4)}';
        }
        return '****';

      case SensitiveDataType.email:
        if (!value.contains('@')) return '****';
        final emailParts = value.split('@');
        final local = emailParts[0];
        final domain = emailParts.length > 1 ? emailParts[1] : '';
        if (local.length <= 1) return '****@$domain';
        return '${local.characters.first}****@$domain';
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
      case SensitiveDataType.email:
        return Icons.email;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getIconForType(type),
              size: 16,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _maskSensitiveData(value, type),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off,
                    size: 12,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Sens',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
