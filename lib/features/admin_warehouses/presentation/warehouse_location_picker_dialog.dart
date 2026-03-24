import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong_pkg;
import '../../../core/env/app_env.dart';
import '../../../core/l10n/app_localizations_fixed.dart';

class WarehouseLocationPickerDialog extends StatefulWidget {
  const WarehouseLocationPickerDialog({
    super.key,
    required this.initialPoint,
    this.anchorPoint,
    required this.cityLabel,
    this.zoneLabel,
  });

  final latlong_pkg.LatLng initialPoint;
  final latlong_pkg.LatLng? anchorPoint;
  final String cityLabel;
  final String? zoneLabel;

  @override
  State<WarehouseLocationPickerDialog> createState() =>
      _WarehouseLocationPickerDialogState();
}

class _WarehouseLocationPickerDialogState
    extends State<WarehouseLocationPickerDialog> {
  late latlong_pkg.LatLng _selectedPoint;
  final flutter_map.MapController _mapController = flutter_map.MapController();

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (widget.cityLabel.trim().isNotEmpty) widget.cityLabel.trim(),
      if (widget.zoneLabel?.trim().isNotEmpty == true) widget.zoneLabel!.trim(),
    ].join(' / ');

    final markers = <flutter_map.Marker>[
      if (widget.anchorPoint != null)
        flutter_map.Marker(
          point: widget.anchorPoint!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Color(0xFF0078D4),
            size: 40,
          ),
        ),
      flutter_map.Marker(
        point: _selectedPoint,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.location_on,
          color: Color(0xFFE5242D),
          size: 40,
        ),
      ),
    ];

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.t('warehouse_location_picker_title'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle.isEmpty
                    ? context.l10n.t('warehouse_location_picker_hint_base')
                    : '${context.l10n.t('warehouse_location_picker_hint_with_context')} $subtitle.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: flutter_map.FlutterMap(
                    mapController: _mapController,
                    options: flutter_map.MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 14,
                      onTap: (tapPosition, point) {
                        setState(() => _selectedPoint = point);
                      },
                    ),
                    children: [
                      flutter_map.TileLayer(
                        urlTemplate: AppEnv.azureMapsApiKey.trim().isNotEmpty
                            ? 'https://atlas.microsoft.com/map/tile?api-version=2022-12-01&tilesetId=microsoft.basemaps&zoom={z}&x={x}&y={y}&subscription-key=${AppEnv.azureMapsApiKey}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.travelbox.peru.app',
                      ),
                      flutter_map.MarkerLayer(markers: markers),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _CoordinateChip(
                    label: context.l10n.t('warehouse_location_picker_latitude'),
                    value: _selectedPoint.latitude.toStringAsFixed(6),
                  ),
                  _CoordinateChip(
                    label: context.l10n.t(
                      'warehouse_location_picker_longitude',
                    ),
                    value: _selectedPoint.longitude.toStringAsFixed(6),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.t('cancelar')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_selectedPoint),
                    icon: const Icon(Icons.check),
                    label: Text(context.l10n.t('usar_estas_coordenadas')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoordinateChip extends StatelessWidget {
  const _CoordinateChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}
