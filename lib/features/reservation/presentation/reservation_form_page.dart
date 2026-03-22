import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/peru_time.dart';
import '../../warehouse/presentation/warehouse_detail_page.dart';
import '../data/reservation_repository_impl.dart';
import '../domain/reservation_repository.dart';

class ReservationFormPage extends ConsumerStatefulWidget {
  const ReservationFormPage({super.key, required this.warehouseId});

  final String warehouseId;

  @override
  ConsumerState<ReservationFormPage> createState() =>
      _ReservationFormPageState();
}

class _ReservationFormPageState extends ConsumerState<ReservationFormPage> {
  int bagCount = 1;
  String size = 'M';
  bool extraInsurance = false;
  bool pickupRequested = false;
  bool dropoffRequested = false;
  late DateTime startAt;
  late DateTime endAt;

  @override
  void initState() {
    super.initState();
    startAt = PeruTime.nextWholeHourUtc();
    endAt = startAt.add(const Duration(hours: 6));
  }

  @override
  Widget build(BuildContext context) {
    final warehouseAsync = ref.watch(
      warehouseDetailProvider(widget.warehouseId),
    );
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(
          fallbackRoute: '/warehouse/${widget.warehouseId}',
        ),
        title: Text(context.l10n.t('configure_reservation')),
      ),
      body: warehouseAsync.when(
        data: (warehouse) {
          if (warehouse == null) {
            return EmptyStateView(
              message: context.l10n.t('reservation_form_warehouse_not_found'),
            );
          }

          final draft = ReservationDraft(
            warehouse: warehouse,
            bagCount: bagCount,
            startAt: startAt,
            endAt: endAt,
            size: size,
            extraInsurance: extraInsurance,
            pickupRequested: pickupRequested,
            dropoffRequested: dropoffRequested,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(warehouse.name),
                  subtitle: Text('${warehouse.address}, ${warehouse.district}'),
                  trailing: Text(
                    '${context.l10n.t('reservation_form_price_from_prefix')} '
                    'S/${warehouse.pricePerHourSmall.toStringAsFixed(2)}/h',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.t('baggage_quantity')),
                      SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 1,
                            label: Text(context.l10n.t('1')),
                          ),
                          ButtonSegment(
                            value: 2,
                            label: Text(context.l10n.t('2')),
                          ),
                          ButtonSegment(
                            value: 3,
                            label: Text(context.l10n.t('3')),
                          ),
                        ],
                        selected: {bagCount},
                        onSelectionChanged: (value) {
                          setState(() {
                            bagCount = value.first;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      Text(context.l10n.t('main_size')),
                      SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'S',
                            label: Text(context.l10n.t('s')),
                          ),
                          ButtonSegment(
                            value: 'M',
                            label: Text(context.l10n.t('m')),
                          ),
                          ButtonSegment(
                            value: 'L',
                            label: Text(context.l10n.t('l')),
                          ),
                          ButtonSegment(
                            value: 'XL',
                            label: Text(context.l10n.t('xl')),
                          ),
                        ],
                        selected: {size},
                        onSelectionChanged: (value) {
                          setState(() {
                            size = value.first;
                          });
                        },
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${context.l10n.t('rate_label')} ${size.toUpperCase()}: ${NumberFormat.simpleCurrency(locale: 'es_PE').format(warehouse.rateForSize(size))} ${context.l10n.t('price_suffix_per_hour_per_package')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      _DateSelector(
                        label: context.l10n.t('start_date_label'),
                        value: startAt,
                        onTap: () async {
                          final picked = await _pickDateTime(context, startAt);
                          if (picked != null) {
                            setState(() {
                              startAt = picked;
                              if (endAt.isBefore(startAt)) {
                                endAt = startAt.add(const Duration(hours: 2));
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _DateSelector(
                        label: context.l10n.t('end_date_label'),
                        value: endAt,
                        onTap: () async {
                          final picked = await _pickDateTime(context, endAt);
                          if (picked != null && picked.isAfter(startAt)) {
                            setState(() {
                              endAt = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        value: extraInsurance,
                        onChanged: (value) {
                          setState(() {
                            extraInsurance = value;
                          });
                        },
                        title: Text(context.l10n.t('additional_insurance')),
                        subtitle: Text(
                          'S/${warehouse.insuranceFee.toStringAsFixed(2)} ${context.l10n.t('price_suffix_per_reservation')}',
                        ),
                      ),
                      SwitchListTile(
                        value: pickupRequested,
                        onChanged: (value) {
                          setState(() {
                            pickupRequested = value;
                          });
                        },
                        title: Text(context.l10n.t('home_pickup')),
                        subtitle: Text(
                          'S/${warehouse.pickupFee.toStringAsFixed(2)} ${context.l10n.t('price_suffix_per_order')}',
                        ),
                      ),
                      SwitchListTile(
                        value: dropoffRequested,
                        onChanged: (value) {
                          setState(() {
                            dropoffRequested = value;
                          });
                        },
                        title: Text(context.l10n.t('home_delivery')),
                        subtitle: Text(
                          'S/${warehouse.dropoffFee.toStringAsFixed(2)} ${context.l10n.t('price_suffix_per_order')}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: Text(context.l10n.t('estimated_total')),
                  subtitle: Text(
                    '${draft.billableHours()} ${context.l10n.t('hours_unit')} - ${draft.bagCount} ${context.l10n.t('packages_unit')}',
                  ),
                  trailing: Text(
                    'S/${draft.estimatePrice().toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.read(reservationDraftProvider.notifier).state = draft;
                  context.push('/checkout/${widget.warehouseId}');
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(context.l10n.t('continue_checkout')),
              ),
            ],
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: AppErrorFormatter.readable(
            error,
            (String key, {Map<String, dynamic>? params}) =>
                context.l10n.t(key),
          ),
          onRetry: () =>
              ref.invalidate(warehouseDetailProvider(widget.warehouseId)),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final initialPeru = PeruTime.toPeruClock(initial);
    final todayPeru = PeruTime.toPeruClock(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initialPeru,
      firstDate: DateTime(todayPeru.year, todayPeru.month, todayPeru.day),
      lastDate: DateTime(todayPeru.year + 1, todayPeru.month, todayPeru.day),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialPeru),
    );
    if (time == null) return null;
    return PeruTime.fromPeruClock(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(PeruTime.formatDateTime(value)),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: onTap,
    );
  }
}
