import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations_fixed.dart';
import '../../core/theme/brand_tokens.dart';

class TravelBoxLogo extends StatelessWidget {
  const TravelBoxLogo({
    super.key,
    this.compact = false,
    this.darkBackground = false,
    this.showSubtitle = true,
    this.showWordmark = true,
  });

  final bool compact;
  final bool darkBackground;
  final bool showSubtitle;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final textColor = darkBackground ? Colors.white : const Color(0xFF102A43);
    final subtitleColor = darkBackground
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF486581);
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0;
        final maxWidth = hasBoundedWidth ? constraints.maxWidth : 1000.0;
        final hideWordmarkByWidth =
            compact && hasBoundedWidth && maxWidth < 118;
        final hideSubtitleByWidth =
            compact && hasBoundedWidth && maxWidth < 220;
        final resolvedShowWordmark = showWordmark && !hideWordmarkByWidth;
        final resolvedShowSubtitle = showSubtitle && !hideSubtitleByWidth;
        const brandTitle = 'InkaVoy';

        return Row(
          mainAxisSize: hasBoundedWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Container(
              width: compact ? 36 : 44,
              height: compact ? 36 : 44,
              decoration: BoxDecoration(
                gradient: TravelBoxBrand.brandGradient,
                borderRadius: BorderRadius.circular(compact ? 12 : 14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.luggage_rounded,
                size: compact ? 18 : 22,
                color: Colors.white,
              ),
            ),
            if (resolvedShowWordmark) ...[
              SizedBox(width: compact ? 8 : 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandTitle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: textColor,
                      ),
                    ),
                    if (resolvedShowSubtitle)
                      Text(
                        compact
                            ? context.l10n.t('travelbox_logo_subtitle_compact')
                            : context.l10n.t('travelbox_logo_subtitle_full'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          color: subtitleColor,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
