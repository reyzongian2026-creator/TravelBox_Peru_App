import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelbox_peru_app/core/l10n/app_localizations.dart';
import 'package:travelbox_peru_app/features/Rating/data/rating_controller.dart';
import 'package:travelbox_peru_app/features/Rating/presentation/rating_widgets.dart';

class WarehouseRatingsPage extends ConsumerStatefulWidget {
  final int warehouseId;
  final String warehouseName;

  const WarehouseRatingsPage({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
  });

  @override
  ConsumerState<WarehouseRatingsPage> createState() => _WarehouseRatingsPageState();
}

class _WarehouseRatingsPageState extends ConsumerState<WarehouseRatingsPage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final controller = ref.read(ratingControllerProvider.notifier);
    await Future.wait([
      controller.loadRatings(widget.warehouseId),
      controller.loadSummary(widget.warehouseId),
      controller.loadMyRating(widget.warehouseId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(ratingControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.t('rating_title')} - ${widget.warehouseName}'),
      ),
      body: _buildBody(controller, l10n),
    );
  }

  Widget _buildBody(RatingController controller, AppLocalizations l10n) {
    if (controller.isLoading && controller.ratings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.summary != null)
            RatingSummaryCard(summary: controller.summary!),
          const SizedBox(height: 16),
          if (!controller.hasRated)
            RatingInputWidget(
              selectedStars: controller.selectedStars,
              comment: controller.comment,
              isLoading: controller.isLoading,
              onStarsChanged: controller.setStars,
              onCommentChanged: controller.setComment,
              onSubmit: () async {
                final success = await controller.submitRating(
                  warehouseId: widget.warehouseId,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.t('rating_success')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          if (controller.hasRated)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('rating_already_reviewed'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StarRatingWidget(stars: controller.myRating!.stars),
                    if (controller.myRating!.comment != null) ...[
                      const SizedBox(height: 8),
                      Text(controller.myRating!.comment!),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            l10n.t('rating_all_reviews'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (controller.ratings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.t('rating_no_reviews')),
              ),
            )
          else
            ...controller.ratings.map((rating) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RatingCard(rating: rating),
                )),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                controller.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
