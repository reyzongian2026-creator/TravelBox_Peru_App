import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelbox_peru_app/features/Rating/data/rating_controller.dart';
import 'package:travelbox_peru_app/features/Rating/data/rating_model.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Rese\u00f1as - ${widget.warehouseName}'),
      ),
      body: _buildBody(controller),
    );
  }

  Widget _buildBody(RatingController controller) {
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
                    const SnackBar(
                      content: Text('Rese\u00f1a enviada exitosamente'),
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
                    const Text(
                      '\u00a1Ya has dejado tu rese\u00f1a!',
                      style: TextStyle(
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
          const Text(
            'Todas las rese\u00f1as',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (controller.ratings.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('A\u00fan no hay rese\u00f1as'),
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
