import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tournaments/models/tournament_model.dart';

class TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback? onTap;
  final double width;

  const TournamentCard({
    super.key,
    required this.tournament,
    this.onTap,
    this.width = 300,
  });

  @override
  Widget build(BuildContext context) {
    final startTimeStr = DateFormat('dd MMM • hh:mm a').format(tournament.startTime);
    final isFree = tournament.entryFee == 0.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner Image Header with Badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                    child: Image.network(
                      tournament.bannerUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 120,
                        color: AppColors.surfaceElevated,
                        child: const Center(
                          child: Icon(Icons.sports_esports, color: AppColors.textTertiary, size: 36),
                        ),
                      ),
                    ),
                  ),
                  // Dark gradient overlay
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.surface.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                  // Game & Format Badges
                  Positioned(
                    top: 10,
                    left: 10,
                    child: StatusBadge(
                      label: tournament.game,
                      type: tournament.game == 'FREE FIRE' ? BadgeType.danger : BadgeType.primary,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        tournament.mapName.toUpperCase(),
                        style: AppTextStyles.badge.copyWith(color: AppColors.textPrimary, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.title,
                      style: AppTextStyles.h4.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tournament.format} • $startTimeStr',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),
                    Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 12),

                    // Prize Pool & Entry Fee Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PRIZE POOL', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${tournament.prizePool.toStringAsFixed(0)}',
                              style: AppTextStyles.monoCode.copyWith(
                                color: AppColors.accentAmber,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (tournament.perKill > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PER KILL', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary)),
                              const SizedBox(height: 2),
                              Text(
                                '₹${tournament.perKill.toStringAsFixed(0)}',
                                style: AppTextStyles.monoCode.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('ENTRY FEE', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary)),
                            const SizedBox(height: 2),
                            Text(
                              isFree ? 'FREE' : '₹${tournament.entryFee.toStringAsFixed(0)}',
                              style: AppTextStyles.monoCode.copyWith(
                                color: isFree ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Slots Progress Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SLOTS FILLED',
                          style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary),
                        ),
                        Text(
                          '${tournament.filledSlots} / ${tournament.maxSlots}',
                          style: AppTextStyles.monoCode.copyWith(
                            fontSize: 11,
                            color: tournament.isFull ? AppColors.secondary : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: tournament.slotsProgress,
                        backgroundColor: AppColors.surfaceHighlight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          tournament.isFull ? AppColors.secondary : AppColors.primary,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
