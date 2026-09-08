import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../tournaments/models/tournament_model.dart';
import '../../auth/controllers/auth_controller.dart';

class HostRulesModal {
  static void show(BuildContext context, TournamentModel tournament, VoidCallback onClaimed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _HostRulesModalContent(tournament: tournament, onClaimed: onClaimed),
    );
  }
}

class _HostRulesModalContent extends ConsumerStatefulWidget {
  final TournamentModel tournament;
  final VoidCallback onClaimed;

  const _HostRulesModalContent({required this.tournament, required this.onClaimed});

  @override
  ConsumerState<_HostRulesModalContent> createState() => _HostRulesModalContentState();
}

class _HostRulesModalContentState extends ConsumerState<_HostRulesModalContent> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _ignController = TextEditingController();
  final _uidController = TextEditingController();
  bool _acceptedRules = false;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authControllerProvider).value;
    if (profile != null) {
      _nameController.text = profile.fullName ?? profile.username;
      _mobileController.text = (profile.phone != null && profile.phone!.isNotEmpty) ? profile.phone! : '9876543210';
      _ignController.text = profile.gameIgn ?? 'kuchupuchu';
      _uidController.text = profile.gameUid ?? '2164068362';
      _acceptedRules = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _ignController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF0D121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Banner
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFF818CF8), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BECOME A HOST • CLAIM MATCH',
                        style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        t.title,
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),

            Expanded(
              child: ListView(
                children: [
                  // Host Compensation Promise Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFF59E0B), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STANDARD HOST COMPENSATION',
                                style: AppTextStyles.badge.copyWith(color: const Color(0xFFFBBF24), fontSize: 9.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Earn ₹${t.baseHostReward} per Completed Match',
                                style: AppTextStyles.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Direct payout to your vault wallet upon submitting match scores.',
                                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Strict Guidelines Accordion
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.rule_rounded, color: Color(0xFF60A5FA), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'MANDATORY HOST REGULATIONS',
                              style: AppTextStyles.badge.copyWith(color: const Color(0xFF93C5FD), fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildRuleItem('1', 'Account Requirement', 'Must be Level 40+ with valid Free Fire IGN and character UID.'),
                        _buildRuleItem('2', 'On-Time IDP Delivery', 'Custom Room ID & Password must be broadcasted on time before match start.'),
                        _buildRuleItem('3', '10-Min Lateness Penalty', 'If IDP is uploaded >10 minutes late, a 50% penalty applies (Reward reduced to ₹${t.baseHostReward ~/ 2}).'),
                        _buildRuleItem('4', '20-Min Auto-Refund Safeguard', 'If IDP is not uploaded within 20 mins, match is auto-cancelled and all players refunded.'),
                        _buildRuleItem('5', 'Anti-Self-Playing Rule', 'Hosts cannot play in the same lobby they are hosting. Zero tolerance for favoritism or cheating.'),
                        if (t.isCs)
                          _buildRuleItem('6', 'Clash Squad Esports Preset', 'Custom room MUST be created with Esports settings: Best of 7, 500 Coin Economy, Strictly No Throwables/Nades, Max 1 Sniper/team, Unique skills.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Host Details Form
                  Text(
                    'VERIFIED HOST CREDENTIALS',
                    style: AppTextStyles.badge.copyWith(color: const Color(0xFF818CF8), fontSize: 10),
                  ),
                  const SizedBox(height: 10),

                  TacticalTextField(
                    controller: _nameController,
                    label: 'Host Full Name',
                    hint: 'e.g. Aman Sharma',
                    prefixIcon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 12),

                  TacticalTextField(
                    controller: _mobileController,
                    label: 'WhatsApp Mobile Number',
                    hint: 'e.g. 9876543210',
                    prefixIcon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TacticalTextField(
                          controller: _ignController,
                          label: 'Free Fire Host IGN',
                          hint: 'e.g. T69_OfficialHost',
                          prefixIcon: Icons.sports_esports_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TacticalTextField(
                          controller: _uidController,
                          label: 'Character UID',
                          hint: 'e.g. 2164068362',
                          prefixIcon: Icons.tag_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Acceptance Checkbox
                  InkWell(
                    onTap: () => setState(() => _acceptedRules = !_acceptedRules),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _acceptedRules ? const Color(0xFF1E1B4B) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _acceptedRules ? const Color(0xFF6366F1) : Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _acceptedRules,
                            activeColor: const Color(0xFF6366F1),
                            onChanged: (val) => setState(() => _acceptedRules = val ?? false),
                          ),
                          Expanded(
                            child: Text(
                              'I agree to host with integrity, broadcast credentials on time, and accept all penalty safeguards.',
                              style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TacticalButton(
                    label: _isClaiming ? 'Claiming Match...' : 'ACCEPT RULES & CLAIM LOBBY (₹${t.baseHostReward})',
                    icon: Icons.check_circle_rounded,
                    isLoading: _isClaiming,
                    onPressed: () async {
                      if (!_acceptedRules) {
                        UiHelpers.showErrorBanner(context, 'Please read and accept the host regulations.');
                        return;
                      }

                      final name = _nameController.text.trim();
                      final mobile = _mobileController.text.trim();
                      final ign = _ignController.text.trim();
                      final uid = _uidController.text.trim();

                      if (name.isEmpty || mobile.isEmpty || ign.isEmpty || uid.isEmpty) {
                        UiHelpers.showErrorBanner(context, 'Please fill in all host credential fields.');
                        return;
                      }

                      final profile = ref.read(authControllerProvider).value;
                      final hostId = profile?.id ?? 'e0bca6e1-fca6-40e6-ad39-430e58593bb2';

                      setState(() => _isClaiming = true);
                      try {
                        final repo = ref.read(tournamentRepoProvider);
                        await repo.claimTournamentAsHost(
                          tournamentId: t.id,
                          hostId: hostId,
                          hostName: name,
                          hostMobile: mobile,
                          hostIgn: ign,
                          hostUid: uid,
                        );

                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        UiHelpers.showSuccessBanner(context, 'Lobby claimed! You are now the official coordinator for this match.');
                        widget.onClaimed();
                      } catch (e) {
                        if (!context.mounted) return;
                        setState(() => _isClaiming = false);
                        UiHelpers.showErrorBanner(context, e.toString().replaceAll('Exception: ', ''));
                      }
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              num,
              style: AppTextStyles.monoCode.copyWith(color: const Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 11),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
