import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tournaments/models/banner_model.dart';
import '../../tournaments/controllers/tournament_controller.dart';

class BannerCarousel extends ConsumerStatefulWidget {
  final List<BannerModel> banners;
  final void Function(BannerModel banner)? onBannerTap;

  const BannerCarousel({
    super.key,
    required this.banners,
    this.onBannerTap,
  });

  @override
  ConsumerState<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<BannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showAddBannerDialog() {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    final imageController = TextEditingController(text: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80');
    final tagController = TextEditingController(text: 'MEGA CUP');
    String actionType = 'game_hub';
    String actionTarget = 'FREE FIRE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: Text('POST TOURNAMENT BANNER', style: AppTextStyles.h4),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TacticalTextField(
                  label: 'TOURNAMENT / EVENT TITLE',
                  hint: 'e.g. FREE FIRE MEGA CUP 2026',
                  controller: titleController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'SUBTITLE / PRIZE SUMMARY',
                  hint: 'e.g. ₹50,000 Prize Pool • Bermuda BR',
                  controller: subtitleController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'BANNER POSTER IMAGE URL',
                  hint: 'https://...',
                  controller: imageController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'BADGE TAG',
                  hint: 'e.g. MEGA CUP / FREE ENTRY',
                  controller: tagController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('TARGET: ', style: AppTextStyles.inputLabel),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: actionTarget,
                      dropdownColor: AppColors.surfaceElevated,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'FREE FIRE', child: Text('Free Fire Hub')),
                        DropdownMenuItem(value: 'BGMI', child: Text('BGMI Arena')),
                        DropdownMenuItem(value: 'VALORANT', child: Text('Valorant')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => actionTarget = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('CANCEL', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: 'PUBLISH BANNER',
              isFullWidth: false,
              height: 38,
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  UiHelpers.showErrorBanner(context, 'Title is required.');
                  return;
                }
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  await repo.addNewBanner(
                    title: titleController.text.trim(),
                    subtitle: subtitleController.text.trim(),
                    imageUrl: imageController.text.trim(),
                    actionType: actionType,
                    actionTarget: actionTarget,
                    tag: tagController.text.trim(),
                  );
                  ref.invalidate(bannersProvider);
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    UiHelpers.showSuccessBanner(context, 'Tournament banner published.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    UiHelpers.showErrorBanner(context, 'Error: ${e.toString()}');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Admin Post Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Featured Tournaments', style: AppTextStyles.sectionTitle),
            ),
            InkWell(
              onTap: _showAddBannerDialog,
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Post Banner',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Carousel Slider
        SizedBox(
          height: 175,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Stack(
                      children: [
                        // Background Poster Image
                        Image.network(
                          banner.imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.surfaceHighlight,
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
                            ),
                          ),
                        ),

                        // Cinematic Dark Gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.92),
                                Colors.black.withValues(alpha: 0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StatusBadge(
                                label: banner.tag,
                                type: banner.tag.contains('MEGA') ? BadgeType.danger : BadgeType.primary,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 260,
                                child: Text(
                                  banner.title,
                                  style: AppTextStyles.h3.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (banner.subtitle != null) ...[
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    banner.subtitle!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Click Overlay
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => widget.onBannerTap?.call(banner),
                              splashColor: AppColors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (idx) {
            final isCurrent = idx == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isCurrent ? 18 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }
}
