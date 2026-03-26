import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/data/peru_tourism_catalog.dart';
import '../../../shared/state/realtime_app_event_cursor_provider.dart';
import '../../../shared/state/warehouse_catalog_sync.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../../shared/widgets/currency_widgets.dart';
import '../../../shared/widgets/peru_flat_scene.dart';
import '../../map_discovery/data/discovery_repository_impl.dart';

final warehouseDetailProvider = FutureProvider.family((
  Ref ref,
  String warehouseId,
) {
  ref.watch(realtimeAppEventCursorProvider);
  ref.watch(warehouseCatalogVersionProvider);
  return ref.read(discoveryRepositoryProvider).getWarehouseById(warehouseId);
});

class WarehouseDetailPage extends ConsumerWidget {
  const WarehouseDetailPage({super.key, required this.warehouseId});

  final String warehouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouseAsync = ref.watch(warehouseDetailProvider(warehouseId));
    return AppShellScaffold(
      title: context.l10n.t('warehouse_detail_title'),
      currentRoute: '/discovery',
      actions: [
        IconButton(
          tooltip: context.l10n.t('back'),
          onPressed: () => context.go('/discovery'),
          icon: const Icon(Icons.arrow_back),
        ),
      ],
      child: warehouseAsync.when(
        data: (warehouse) {
          if (warehouse == null) {
            return EmptyStateView(
              message: context.l10n.t('warehouse_detail_not_found'),
              actionLabel: context.l10n.t('back'),
              onAction: () => context.go('/discovery'),
            );
          }

          final isWideWeb = kIsWeb && MediaQuery.of(context).size.width >= 1000;
          final content = ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${context.l10n.t('warehouse_detail_city_prefix')} '
                '${warehouse.city}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (isWideWeb)
                SizedBox(
                  height: 320,
                  child: AppSmartImage(
                    source: warehouse.imageUrl,
                    width: double.infinity,
                    height: 320,
                    borderRadius: BorderRadius.circular(16),
                    fallback: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: PeruFlatScene(
                        city: warehouse.city,
                        height: 320,
                        showLabel: true,
                      ),
                    ),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppSmartImage(
                    source: warehouse.imageUrl,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                    fallback: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: PeruFlatScene(
                        city: warehouse.city,
                        height: 200,
                        showLabel: true,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                warehouse.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text('${warehouse.address}, ${warehouse.city}'),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.l10n.t('warehouse_detail_schedule_prefix')}: '
                        '${warehouse.openingHours}',
                      ),
                      Text(
                        '${context.l10n.t('warehouse_detail_capacity_available_prefix')}: '
                        '${warehouse.availableSlots}',
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${context.l10n.t('warehouse_detail_price_from_prefix')}:',
                          ),
                          PriceDisplayWithOriginal(
                            priceInPEN: warehouse.priceFromPerHour,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            secondaryStyle: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                      if (warehouse.score > 0) ...[
                        Text(
                          '${context.l10n.t('warehouse_detail_score_prefix')}: '
                          '${warehouse.score.toStringAsFixed(1)}',
                        ),
                      ],
                      TextButton.icon(
                        onPressed: () {
                          context.push(
                            '/warehouse/${warehouse.id}/ratings?name=${Uri.encodeComponent(warehouse.name)}',
                          );
                        },
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: Text(context.l10n.t('rating_view_all')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _TourismInfoBlock(city: warehouse.city),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.t('warehouse_detail_extra_services_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: warehouse.extraServices
                    .map((item) => Chip(label: Text(item)))
                    .toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/reservation/new/$warehouseId'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(context.l10n.t('reservar_ahora')),
              ),
            ],
          );

          if (!isWideWeb) {
            return content;
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: content,
            ),
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: AppErrorFormatter.readable(
            error,
            (String key, {Map<String, dynamic>? params}) => context.l10n.t(key),
          ),
          onRetry: () => ref.invalidate(warehouseDetailProvider(warehouseId)),
        ),
      ),
    );
  }
}

class _TourismInfoBlock extends StatelessWidget {
  const _TourismInfoBlock({required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    final tourism = PeruTourismCatalog.forCity(city);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.l10n.t('warehouse_detail_tourism_highlight_prefix')}: '
          '${tourism.heroLandmark}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(tourism.shortDescription),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tourism.highlights
              .map((item) => Chip(label: Text(item)))
              .toList(),
        ),
      ],
    );
  }
}
