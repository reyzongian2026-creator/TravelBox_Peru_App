import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_dashboard_repository.dart';

final adminRatingsProvider = FutureProvider<List<AdminRatingItem>>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getAllRatings();
});

class AdminRatingsPage extends ConsumerWidget {
  const AdminRatingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingsAsync = ref.watch(adminRatingsProvider);
    final l10n = context.l10n;
    final responsive = context.responsive;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(responsive.cardPadding),
          child: Row(
            children: [
              Text(
                l10n.t('ratings_management'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(adminRatingsProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.t('recargar')),
              ),
            ],
          ),
        ),
        Expanded(
          child: ratingsAsync.when(
            data: (ratings) {
              if (ratings.isEmpty) {
                return Padding(
                  padding: responsive.pageInsets(top: 0),
                  child: EmptyStateView(
                    message: l10n.t('no_ratings_yet'),
                  ),
                );
              }
              return ListView.builder(
                padding: responsive.pageInsets(top: 0),
                itemCount: ratings.length,
                itemBuilder: (context, index) {
                  final rating = ratings[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: responsive.itemGap),
                    child: Padding(
                      padding: EdgeInsets.all(responsive.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _StarRating(stars: rating.stars),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(rating.type),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (rating.verified) ...[
                                const SizedBox(width: 4),
                                Chip(
                                  avatar: const Icon(Icons.verified, size: 16),
                                  label: Text(l10n.t('verified')),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.green[50],
                                ),
                              ],
                              const Spacer(),
                              Text(
                                '#${rating.id}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          SizedBox(height: responsive.itemGap / 2),
                          Text(
                            rating.comment ?? l10n.t('no_comment'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          SizedBox(height: responsive.itemGap / 2),
                          const Divider(),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${rating.userName} (${rating.userEmail})',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.warehouse_outlined, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  rating.warehouseName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const LoadingStateView(),
            error: (e, _) => ErrorStateView(
              message: '$e',
              onRetry: () => ref.invalidate(adminRatingsProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _StarRating extends StatelessWidget {
  final int stars;

  const _StarRating({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }
}
