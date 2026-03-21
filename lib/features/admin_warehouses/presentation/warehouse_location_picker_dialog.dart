import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class WarehouseLocationPickerDialog extends StatefulWidget {
  WarehouseLocationPickerDialog({
    super.key,
    required this.initialPoint,
    this.anchorPoint,
    required this.cityLabel,
    this.zoneLabel,
  });

  final LatLng initialPoint;
  final LatLng? anchorPoint;
  final String cityLabel;
  final String? zoneLabel;

  @override
  State<WarehouseLocationPickerDialog> createState() =>
      _WarehouseLocationPickerDialogState();
}

class _WarehouseLocationPickerDialogState
    extends State<WarehouseLocationPickerDialog> {
  late LatLng _selectedPoint;

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
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.drag |
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom |
                            InteractiveFlag.scrollWheelZoom,
                      ),
                      onTap: (_, point) {
                        setState(() => _selectedPoint = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.travelbox.peru.travelbox_peru_app',
                      ),
                      if (widget.anchorPoint != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: widget.anchorPoint!,
                              width: 36,
                              height: 36,
                              child: const Icon(
                                Icons.place_outlined,
                                color: Color(0xFF1F6E8C),
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.location_pin,
                              color: Color(0xFFC43D3D),
                              size: 38,
                            ),
                          ),
                        ],
                      ),
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
                  SizedBox(width: 8),
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
