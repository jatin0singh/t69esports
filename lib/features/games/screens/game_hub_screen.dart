import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/tactical_card.dart';
import '../../wallet/widgets/wallet_modal.dart';

class GameHubScreen extends ConsumerStatefulWidget {
  final String gameName;
  final String heroBannerUrl;
  final String description;
  final List<String> maps;
  final List<String> modes;
  final String expectedLaunch;
  final double teaserPrizePool;

  const GameHubScreen({
    super.key,
    required this.gameName,
    required this.heroBannerUrl,
    required this.description,
    required this.maps,
    required this.modes,
    this.expectedLaunch = 'SEASON 2026',
    this.teaserPrizePool = 50000.0,
  });

  /// Factory for BGMI Arena
  factory GameHubScreen.bgmi() {
    return const GameHubScreen(
      gameName: 'BGMI',
      heroBannerUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80',
      description: 'Battlegrounds Mobile India Tier-1 custom rooms, daily paid scrims & mega prize tournament circuits.',
      maps: ['Erangel', 'Miramar', 'Sanhok', 'Vikendi'],
      modes: ['Squad BR', 'Duo BR', 'TDM 4v4'],
      expectedLaunch: 'OPENING SOON',
      teaserPrizePool: 75000.0,
    );
  }

  /// Factory for Valorant Arena
  factory GameHubScreen.valorant() {
    return const GameHubScreen(
      gameName: 'VALORANT',
      heroBannerUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80',
      description: '5v5 Tactical Shooter tournaments, Spike Rush challenges, and verified premier custom lobbies.',
      maps: ['Ascent', 'Haven', 'Bind', 'Split', 'Lotus'],
      modes: ['Standard 5v5', 'Spike Rush', 'Swiftplay'],
      expectedLaunch: 'Q3 2026',
      teaserPrizePool: 100000.0,
    );
  }

  /// Factory for CS2 Arena
  factory GameHubScreen.cs2() {
    return const GameHubScreen(
      gameName: 'COUNTER-STRIKE 2',
      heroBannerUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80',
      description: 'Sub-tick MR12 competitive brackets, Wingman 2v2 cups, and anti-cheat verified servers.',
      maps: ['Mirage', 'Inferno', 'Dust II', 'Nuke', 'Ancient'],
      modes: ['Competitive 5v5', 'Wingman 2v2'],
      expectedLaunch: 'COMING SOON',
      teaserPrizePool: 50000.0,
    );
  }

  /// Factory for CODM Arena
  factory GameHubScreen.codm() {
    return const GameHubScreen(
      gameName: 'CALL OF DUTY: MOBILE',
      heroBannerUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80',
      description: 'Search & Destroy tournaments, Hardpoint scrims, and Isolated Battle Royale prize cups.',
      maps: ['Crash', 'Firing Range', 'Summit', 'Standoff', 'Isolated'],
      modes: ['Search & Destroy', 'Hardpoint', 'Battle Royale'],
      expectedLaunch: 'COMING SOON',
      teaserPrizePool: 40000.0,
    );
  }

  @override
  ConsumerState<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends ConsumerState<GameHubScreen> {
  bool _isPreRegistered = false;

  void _handlePreRegister() {
    setState(() => _isPreRegistered = !_isPreRegistered);
    if (_isPreRegistered) {
      UiHelpers.showSuccessBanner(
        context,
        'Pre-registered for ${widget.gameName} Arena! You will be notified when matches go live.',
      );
    } else {
      UiHelpers.showSuccessBanner(context, 'Pre-registration cancelled.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${widget.gameName} Arena',
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
            onPressed: () => WalletModal.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // 1. Hero Spotlight Poster with Gradient
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              image: DecorationImage(
                image: NetworkImage(widget.heroBannerUrl),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatusBadge(
                        label: 'STATUS: ${widget.expectedLaunch}',
                        type: BadgeType.warning,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.gameName,
                        style: AppTextStyles.h1.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. COMING SOON Neo Card (Matching reference Blue & White design)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Soft Blue Circle Icon Container
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceBlueTile,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      color: AppColors.primaryDark,
                      size: 36,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  '${widget.gameName} ARENA COMING SOON',
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'We are currently calibrating verified match servers, anti-cheat detection, and custom room distribution for ${widget.gameName}. Pre-register below to get early slot access and exclusive bonus ticket drops.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Pre-Register Interactive Pill Button
                TacticalButton(
                  label: _isPreRegistered ? '✓ Pre-Registered (Notification Active)' : 'Pre-Register for Early Access',
                  variant: _isPreRegistered ? TacticalButtonVariant.secondary : TacticalButtonVariant.primary,
                  icon: _isPreRegistered ? Icons.check_circle_outline_rounded : Icons.notifications_active_outlined,
                  onPressed: _handlePreRegister,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Tournament Circuit Teaser Grid
          Text('Teaser Circuit Specs', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TacticalCard(
                  title: 'LAUNCH PRIZE POOL',
                  accentColor: AppColors.accentOrange,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${widget.teaserPrizePool.toStringAsFixed(0)}',
                        style: AppTextStyles.monoCode.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Guaranteed Pool', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TacticalCard(
                  title: 'FAIR PLAY',
                  accentColor: AppColors.primary,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% VERIFIED',
                        style: AppTextStyles.monoCode.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Strict Anti-Cheat', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. Supported Competitive Formats & Maps
          TacticalCard(
            title: 'SUPPORTED MODES & MAPS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modes:', style: AppTextStyles.inputLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.modes.map((mode) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBlueTile,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        mode,
                        style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                Text('Map Pool:', style: AppTextStyles.inputLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.maps.map((map) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        map,
                        style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. Community Discord Channel Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF5865F2).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF5865F2).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5865F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join the ${widget.gameName} Discord',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Team scrims, partner clans & daily announcements',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TacticalButton(
                  label: 'Join',
                  isFullWidth: false,
                  height: 36,
                  onPressed: () {
                    UiHelpers.showSuccessBanner(
                      context,
                      'Redirecting to T69 ${widget.gameName} community channel...',
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          TacticalButton(
            label: '← Back to Home Hub',
            variant: TacticalButtonVariant.outline,
            height: 44,
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
