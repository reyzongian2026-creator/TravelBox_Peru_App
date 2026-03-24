import 'package:flutter/material.dart';
import 'package:travelbox_peru_app/core/l10n/app_localizations_fixed.dart';
import 'package:travelbox_peru_app/features/Rating/data/rating_model.dart';

class StarRatingWidget extends StatelessWidget {
  final int stars;
  final int maxStars;
  final double size;
  final Color? color;
  final ValueChanged<int>? onTap;
  final bool readOnly;

  const StarRatingWidget({
    super.key,
    required this.stars,
    this.maxStars = 5,
    this.size = 24,
    this.color,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (index) {
        final isFilled = index < stars;
        return GestureDetector(
          onTap: readOnly ? null : () => onTap?.call(index + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: color ?? (isFilled ? Colors.amber : Colors.grey[400]),
            ),
          ),
        );
      }),
    );
  }
}

class RatingSummaryCard extends StatelessWidget {
  final WarehouseRatingSummary summary;
  final VoidCallback? onSeeAll;

  const RatingSummaryCard({
    super.key,
    required this.summary,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  summary.averageStars.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StarRatingWidget(stars: summary.averageStars.round()),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('rating_reviews_count').replaceAll('{count}', summary.totalRatings.toString()),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBar(5, summary.percentage5),
            _buildBar(4, summary.percentage4),
            _buildBar(3, summary.percentage3),
            _buildBar(2, summary.percentage2),
            _buildBar(1, summary.percentage1),
            if (onSeeAll != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: onSeeAll,
                  child: Text(l10n.t('rating_view_all')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBar(int stars, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$stars', style: const TextStyle(fontSize: 12)),
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation(Colors.amber),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${percentage.toInt()}%',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class RatingCard extends StatelessWidget {
  final RatingModel rating;

  const RatingCard({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    (rating.userName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.userName ?? l10n.t('rating_user_default'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          StarRatingWidget(stars: rating.stars, size: 16),
                          if (rating.verified) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: Colors.blue,
                            ),
                            Text(
                              ' ${l10n.t('rating_verified')}',
                              style: const TextStyle(fontSize: 10, color: Colors.blue),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (rating.createdAt != null)
                  Text(
                    _formatDate(rating.createdAt!, l10n),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            if (rating.comment != null && rating.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                rating.comment!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inDays > 0) {
      return l10n.t('rating_time_ago_days').replaceAll('{days}', diff.inDays.toString());
    } else if (diff.inHours > 0) {
      return l10n.t('rating_time_ago_hours').replaceAll('{hours}', diff.inHours.toString());
    } else if (diff.inMinutes > 0) {
      return l10n.t('rating_time_ago_minutes').replaceAll('{minutes}', diff.inMinutes.toString());
    }
    return l10n.t('rating_time_ago_now');
  }
}

class RatingInputWidget extends StatelessWidget {
  final int? selectedStars;
  final String comment;
  final bool isLoading;
  final ValueChanged<int> onStarsChanged;
  final ValueChanged<String> onCommentChanged;
  final VoidCallback onSubmit;

  const RatingInputWidget({
    super.key,
    required this.selectedStars,
    required this.comment,
    required this.isLoading,
    required this.onStarsChanged,
    required this.onCommentChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.t('rating_experience_question'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: StarRatingWidget(
                stars: selectedStars ?? 0,
                size: 40,
                onTap: onStarsChanged,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: l10n.t('rating_experience_hint'),
                border: const OutlineInputBorder(),
              ),
              onChanged: onCommentChanged,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading || selectedStars == null || selectedStars == 0
                  ? null
                  : onSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(l10n.t('rating_submit')),
            ),
          ],
        ),
      ),
    );
  }
}
