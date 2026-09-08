import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';
import '../../home/screens/home_hub_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ignController = TextEditingController();
  final _uidController = TextEditingController();
  final _discordController = TextEditingController();

  final List<String> _games = const [
    'FREE FIRE',
    'BGMI',
    'VALORANT',
    'CS2',
    'CODM',
  ];

  final List<String> _avatarPresets = const [
    'https://api.dicebear.com/7.x/bottts/png?seed=Viper',
    'https://api.dicebear.com/7.x/bottts/png?seed=Reaper',
    'https://api.dicebear.com/7.x/bottts/png?seed=Phantom',
    'https://api.dicebear.com/7.x/bottts/png?seed=Shadow',
    'https://api.dicebear.com/7.x/bottts/png?seed=Cyber',
  ];

  late String _selectedGame;
  late String _selectedAvatar;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedGame = _games.first;
    _selectedAvatar = _avatarPresets.first;
  }

  @override
  void dispose() {
    _ignController.dispose();
    _uidController.dispose();
    _discordController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      UiHelpers.vibrateError();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authController = ref.read(authControllerProvider.notifier);
    final success = await authController.completeOnboarding(
      gameIgn: _ignController.text.trim(),
      gameUid: _uidController.text.trim(),
      primaryGame: _selectedGame,
      discordTag: _discordController.text.trim().isNotEmpty
          ? _discordController.text.trim()
          : null,
      avatarUrl: _selectedAvatar,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      UiHelpers.showSuccessBanner(context, 'Gamer profile setup complete.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeHubScreen()),
        (route) => false,
      );
    } else {
      final error = ref.read(authControllerProvider).error;
      setState(() {
        _errorMessage = error?.toString().replaceAll('Exception: ', '') ??
            'Failed to save profile details.';
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.headerBackground,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          },
        ),
        title: Text('Profile Setup', style: AppTextStyles.h4.copyWith(color: Colors.white)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StatusBadge(label: 'STEP 02 // PROFILE INITIALIZATION', type: BadgeType.primary),
                        const SizedBox(height: 12),
                        Text('Setup Gamer Identity', style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text(
                          'Link your primary game credentials for verification.',
                          style: AppTextStyles.bodyMedium,
                        ),

                        const SizedBox(height: 24),

                        // Avatar Selection
                        Text('Select Gamer Avatar', style: AppTextStyles.inputLabel),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 64,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _avatarPresets.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final avatar = _avatarPresets[index];
                              final isSelected = avatar == _selectedAvatar;

                              return InkWell(
                                onTap: () => setState(() => _selectedAvatar = avatar),
                                borderRadius: BorderRadius.circular(32),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      avatar,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.sports_esports_outlined,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Primary Game Picker
                        Text('Primary Competitive Game', style: AppTextStyles.inputLabel),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _games.map((game) {
                            final isSelected = game == _selectedGame;
                            return InkWell(
                              onTap: () => setState(() => _selectedGame = game),
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  game,
                                  style: AppTextStyles.badge.copyWith(
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // In-Game Name (IGN)
                        TacticalTextField(
                          hint: 'In-Game Name (IGN)',
                          controller: _ignController,
                          validator: (val) => Validators.validateRequired(val, 'In-Game Name'),
                        ),

                        const SizedBox(height: 14),

                        // In-Game UID
                        TacticalTextField(
                          hint: 'Character UID (e.g. 512398712)',
                          controller: _uidController,
                          validator: Validators.validateGameUid,
                        ),

                        const SizedBox(height: 14),

                        // Discord Tag
                        TacticalTextField(
                          hint: 'Discord Tag (Optional, e.g. player#0000)',
                          controller: _discordController,
                        ),

                        const SizedBox(height: 28),

                        TacticalButton(
                          label: 'Confirm & Enter Arena',
                          isLoading: _isLoading,
                          onPressed: _handleCompleteOnboarding,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
