import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../tournaments/models/banner_model.dart';
import '../../tournaments/models/sponsor_model.dart';
import '../../tournaments/models/tournament_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../host/screens/host_lobbies_screen.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/models/app_update_info.dart';
import '../../../core/widgets/app_update_dialog.dart';

class AdminPaymentsScreen extends ConsumerStatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  ConsumerState<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen> {
  // 0: Revenue & P&L, 1: Deposits, 2: Payouts, 3: Lobbies, 4: Players & Wallets, 5: Kick Players, 6: Banners, 7: Sponsors, 8: App Releases
  int _activeSection = 0;

  // Revenue & P&L Analytics State
  String _revenueTimeRange = 'ALL'; // 'ALL', 'MONTH', 'WEEK', 'TODAY'
  Map<String, dynamic>? _revenueData;
  bool _isLoadingRevenue = false;
  final TextEditingController _ledgerSearchController = TextEditingController();
  String _ledgerSearchQuery = '';
  String _ledgerFilterType = 'ALL'; // 'ALL', 'DEPOSIT', 'PAYOUT', 'ENTRY', 'PRIZE', 'REFUND', 'ADJUSTMENT'

  // Payments & Payouts State
  String _selectedFilter = 'PENDING';
  final List<String> _filters = const ['PENDING', 'COMPLETED', 'REJECTED', 'ALL'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _transactions = [];

  // Lobbies & Tournaments Management State
  List<TournamentModel> _allTournaments = [];
  bool _isLoadingTournaments = false;
  String _tournamentGameFilter = 'ALL';
  String _tournamentStatusFilter = 'ALL';
  final TextEditingController _tournamentSearchController = TextEditingController();
  String _tournamentSearchQuery = '';

  // Player Accounts & Wallets State
  List<Map<String, dynamic>> _allProfiles = [];
  bool _isLoadingProfiles = false;
  final TextEditingController _profileSearchController = TextEditingController();
  String _profileSearchQuery = '';

  // Lobby Moderation (Kick Players) State
  List<TournamentModel> _adminTournaments = [];
  TournamentModel? _selectedAdminTournament;
  List<Map<String, dynamic>> _lobbyRegistrations = [];
  bool _isLoadingLobbyData = false;
  final TextEditingController _playerSearchController = TextEditingController();
  String _playerSearchQuery = '';

  // Promo Banners State
  List<BannerModel> _allBanners = [];
  bool _isLoadingBanners = false;

  // App Releases State
  AppUpdateInfo? _currentRemoteUpdateInfo;
  bool _isLoadingAppRelease = false;
  bool _isPublishingAppRelease = false;
  final TextEditingController _releaseVersionController = TextEditingController(text: '1.0.1');
  final TextEditingController _releaseBuildController = TextEditingController(text: '2');
  final TextEditingController _minBuildController = TextEditingController(text: '1');
  final TextEditingController _apkUrlController = TextEditingController();
  final TextEditingController _releaseNotesController = TextEditingController(
    text: '• Performance & latency enhancements\n• Anti-cheat ban and instant lobby moderation\n• Personalized match and prize history logs\n• In-app auto-update notifications',
  );
  bool _isForceUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadRevenueData();
    _loadData();
    _loadCurrentReleaseInfo();
  }

  @override
  void dispose() {
    _ledgerSearchController.dispose();
    _searchController.dispose();
    _tournamentSearchController.dispose();
    _profileSearchQuery = '';
    _profileSearchController.dispose();
    _playerSearchController.dispose();
    _releaseVersionController.dispose();
    _releaseBuildController.dispose();
    _minBuildController.dispose();
    _apkUrlController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentReleaseInfo() async {
    setState(() => _isLoadingAppRelease = true);
    try {
      final info = await AppUpdateService.fetchLatestUpdateInfo();
      if (mounted) {
        setState(() {
          _currentRemoteUpdateInfo = info;
          if (info != null) {
            _releaseVersionController.text = info.latestVersion;
            _releaseBuildController.text = info.buildNumber.toString();
            _minBuildController.text = info.minSupportedBuild.toString();
            _apkUrlController.text = info.apkUrl;
            _releaseNotesController.text = info.updateNotes;
            _isForceUpdate = info.isForceUpdate;
          }
          _isLoadingAppRelease = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAppRelease = false);
    }
  }

  Future<void> _loadRevenueData() async {
    setState(() => _isLoadingRevenue = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final data = await repo.fetchAdminRevenueAnalytics(timeRange: _revenueTimeRange);
      if (mounted) {
        setState(() {
          _revenueData = data;
          _isLoadingRevenue = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRevenue = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      List<Map<String, dynamic>> txs;
      if (_activeSection == 1) {
        txs = await repo.fetchAdminPaymentRequests(statusFilter: _selectedFilter);
      } else {
        txs = await repo.fetchAdminWithdrawalRequests(statusFilter: _selectedFilter);
      }

      if (mounted) {
        setState(() {
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTournamentsManagementData() async {
    setState(() => _isLoadingTournaments = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final list = await repo.fetchAllTournamentsForHost();
      if (mounted) {
        setState(() {
          _allTournaments = list;
          _isLoadingTournaments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTournaments = false);
    }
  }

  Future<void> _loadProfilesManagementData() async {
    setState(() => _isLoadingProfiles = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final profiles = await repo.getAllProfiles(query: _profileSearchQuery);
      if (mounted) {
        setState(() {
          _allProfiles = profiles;
          _isLoadingProfiles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfiles = false);
    }
  }

  Future<void> _loadBannersData() async {
    setState(() => _isLoadingBanners = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final banners = await repo.getAllBannersForAdmin();
      if (mounted) {
        setState(() {
          _allBanners = banners;
          _isLoadingBanners = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBanners = false);
    }
  }

  // 1. Approve Deposit Request
  Future<void> _handleApproveDeposit(Map<String, dynamic> tx) async {
    final txId = tx['id']?.toString() ?? '';
    final userId = tx['user_id']?.toString() ?? '';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final name = tx['account_holder_name'] ?? 'User';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 26),
            const SizedBox(width: 10),
            Text('Approve Deposit?', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'Confirm adding ₹${amount.toStringAsFixed(0)} to $name\'s wallet vault?\n\nThis will immediately credit their in-app balance.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.bodyMedium),
          ),
          TacticalButton(
            label: 'Approve & Credit ₹${amount.toStringAsFixed(0)}',
            height: 40,
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tournamentRepoProvider);
                await repo.approveDepositPayment(
                  transactionId: txId,
                  userId: userId,
                  amount: amount,
                );

                await ref.read(authControllerProvider.notifier).refreshProfile();
                ref.invalidate(walletTransactionsProvider);

                if (mounted) {
                  UiHelpers.showSuccessBanner(context, 'Payment of ₹${amount.toStringAsFixed(0)} approved and credited!');
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  UiHelpers.showErrorBanner(context, 'Approval failed: ${e.toString()}');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // 2. Reject Deposit
  Future<void> _handleRejectDeposit(Map<String, dynamic> tx) async {
    final txId = tx['id']?.toString() ?? '';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.secondary, size: 26),
            const SizedBox(width: 10),
            Text('Reject Deposit Proof?', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'Are you sure you want to decline this deposit request of ₹${amount.toStringAsFixed(0)}?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.bodyMedium),
          ),
          TacticalButton(
            label: 'Decline Deposit',
            variant: TacticalButtonVariant.danger,
            height: 40,
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tournamentRepoProvider);
                await repo.rejectDepositPayment(transactionId: txId);

                if (mounted) {
                  UiHelpers.showInfoBanner(context, 'Deposit request rejected.');
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  UiHelpers.showErrorBanner(context, 'Rejection failed: ${e.toString()}');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // 3. Mark Withdrawal Payout Completed
  Future<void> _handleApproveWithdrawal(Map<String, dynamic> tx) async {
    final txId = tx['id']?.toString() ?? '';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final name = tx['account_holder_name'] ?? 'Player';
    final upi = tx['payout_upi_id'] ?? 'UPI';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
            const SizedBox(width: 10),
            Text('Confirm Payout Sent?', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'Confirm that you have transferred ₹${amount.toStringAsFixed(0)} to $name at $upi?\n\nThis will mark the withdrawal as completed.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.bodyMedium),
          ),
          TacticalButton(
            label: 'Yes, Payout Sent (₹${amount.toStringAsFixed(0)})',
            height: 40,
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tournamentRepoProvider);
                await repo.approveWithdrawalPayout(transactionId: txId);

                if (mounted) {
                  UiHelpers.showSuccessBanner(context, 'Payout of ₹${amount.toStringAsFixed(0)} marked completed!');
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  UiHelpers.showErrorBanner(context, 'Update failed: ${e.toString()}');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // 4. Reject & Refund Withdrawal
  Future<void> _handleRejectWithdrawal(Map<String, dynamic> tx) async {
    final txId = tx['id']?.toString() ?? '';
    final userId = tx['user_id']?.toString() ?? '';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.undo_rounded, color: AppColors.secondary, size: 26),
            const SizedBox(width: 10),
            Text('Reject & Refund?', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'Decline this payout and instantly refund ₹${amount.toStringAsFixed(0)} back to the player\'s vault balance?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.bodyMedium),
          ),
          TacticalButton(
            label: 'Reject & Refund ₹${amount.toStringAsFixed(0)}',
            variant: TacticalButtonVariant.danger,
            height: 40,
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tournamentRepoProvider);
                await repo.rejectAndRefundWithdrawal(
                  transactionId: txId,
                  userId: userId,
                  amount: amount,
                );

                if (mounted) {
                  UiHelpers.showInfoBanner(context, 'Withdrawal rejected and ₹${amount.toStringAsFixed(0)} refunded to player.');
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  UiHelpers.showErrorBanner(context, 'Refund failed: ${e.toString()}');
                }
              }
            },
          ),
        ],
      ),
    );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Command Center', style: AppTextStyles.h3.copyWith(color: Colors.white, fontSize: 16)),
            Text('Master Management & Live Operations', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 10.5)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open Host Partner Hub',
            icon: const Icon(Icons.sports_esports_rounded, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HostLobbiesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _refreshCurrentSection,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Sticky Top Section Switcher (8 Tabs Ribbon)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                key: const PageStorageKey('admin_ribbon_scroll'),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildSectionTab(0, '📊 REVENUE'),
                    const SizedBox(width: 4),
                    _buildSectionTab(1, '📥 DEPOSITS'),
                    const SizedBox(width: 4),
                    _buildSectionTab(2, '📤 PAYOUTS'),
                    const SizedBox(width: 4),
                    _buildSectionTab(3, '🎮 LOBBIES'),
                    const SizedBox(width: 4),
                    _buildSectionTab(4, '👥 PLAYERS'),
                    const SizedBox(width: 4),
                    _buildSectionTab(5, '🛡️ MODERATION'),
                    const SizedBox(width: 4),
                    _buildSectionTab(6, '🖼️ BANNERS'),
                    const SizedBox(width: 4),
                    _buildSectionTab(7, '🤝 SPONSORS'),
                    const SizedBox(width: 4),
                    _buildSectionTab(8, '🚀 APP RELEASES'),
                  ],
                ),
              ),
            ),
          ),

          // Dynamic Scrollable Body Area
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: Colors.white,
              onRefresh: _refreshCurrentSection,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  if (_activeSection == 0) ...[
                    _buildRevenueAnalyticsSection(),
                  ] else if (_activeSection == 1 || _activeSection == 2) ...[
                    _buildPaymentsAndPayoutsSection(),
                  ] else if (_activeSection == 3) ...[
                    _buildLobbiesManagementSection(),
                  ] else if (_activeSection == 4) ...[
                    _buildPlayersManagementSection(),
                  ] else if (_activeSection == 5) ...[
                    _buildLobbyModerationSection(),
                  ] else if (_activeSection == 6) ...[
                    _buildBannersManagementSection(),
                  ] else if (_activeSection == 7) ...[
                    _buildSponsorsManagementSection(),
                  ] else if (_activeSection == 8) ...[
                    _buildAppReleasesSection(),
                  ],

                  const SizedBox(height: 16),
                  TacticalButton(
                    label: '← Return to Hub',
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
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshCurrentSection() async {
    switch (_activeSection) {
      case 0:
        await _loadRevenueData();
        break;
      case 1:
      case 2:
        await _loadData();
        break;
      case 3:
        await _loadTournamentsManagementData();
        break;
      case 4:
        await _loadProfilesManagementData();
        break;
      case 5:
        await _loadAdminTournaments();
        break;
      case 6:
        await _loadBannersData();
        break;
      case 7:
        ref.invalidate(sponsorsProvider);
        break;
      case 8:
        await _loadCurrentReleaseInfo();
        break;
    }
  }

  Widget _buildSectionTab(int index, String label) {
    final isSelected = _activeSection == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _activeSection = index);
        _refreshCurrentSection();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.badge.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // --- SECTION 0: REVENUE, P&L & FINANCIAL ANALYTICS ENGINE ---
  // =========================================================================

  void _copyRevenueReport(Map<String, dynamic> data) {
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final rangeStr = _revenueTimeRange == 'ALL'
        ? 'ALL TIME'
        : _revenueTimeRange == 'MONTH'
            ? 'THIS MONTH'
            : _revenueTimeRange == 'WEEK'
                ? 'LAST 7 DAYS'
                : 'TODAY';

    final dep = (data['totalDepositsCompleted'] as num?)?.toDouble() ?? 0.0;
    final wdr = (data['totalWithdrawalsCompleted'] as num?)?.toDouble() ?? 0.0;
    final entries = (data['totalEntryFees'] as num?)?.toDouble() ?? 0.0;
    final prizes = (data['totalPrizes'] as num?)?.toDouble() ?? 0.0;
    final profit = (data['matchOperatorProfit'] as num?)?.toDouble() ?? 0.0;
    final margin = (data['matchProfitMargin'] as num?)?.toDouble() ?? 0.0;
    final liability = (data['totalVaultLiability'] as num?)?.toDouble() ?? 0.0;
    final depBal = (data['totalDepositBalance'] as num?)?.toDouble() ?? 0.0;
    final winBal = (data['totalWinningBalance'] as num?)?.toDouble() ?? 0.0;
    final solvency = (data['netHousePosition'] as num?)?.toDouble() ?? 0.0;
    final users = data['totalUsersCount'] ?? 0;

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('📊 T69 ESPORTS - FINANCIAL & P&L REPORT');
    buffer.writeln('========================================');
    buffer.writeln('Generated: $nowStr');
    buffer.writeln('Audit Period: $rangeStr');
    buffer.writeln('----------------------------------------');
    buffer.writeln('💰 PLATFORM CASHFLOW:');
    buffer.writeln('• Gross User Deposits Approved: ₹${dep.toStringAsFixed(0)}');
    buffer.writeln('• Total Withdrawals Paid: ₹${wdr.toStringAsFixed(0)}');
    buffer.writeln('• Net Inflow Cashflow: ₹${(dep - wdr).toStringAsFixed(0)}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('🎮 MATCH OPERATIONS & MARGINS:');
    buffer.writeln('• Total Match Entries Collected: ₹${entries.toStringAsFixed(0)}');
    buffer.writeln('• Total Prize Pools Distributed: ₹${prizes.toStringAsFixed(0)}');
    buffer.writeln('• Match Operator P&L: ${profit >= 0 ? '+' : ''}₹${profit.toStringAsFixed(0)} (${margin.toStringAsFixed(1)}% margin)');
    buffer.writeln('----------------------------------------');
    buffer.writeln('🏦 USER VAULT & SOLVENCY:');
    buffer.writeln('• Total Vault Liability: ₹${liability.toStringAsFixed(0)} (Deposit: ₹${depBal.toStringAsFixed(0)}, Win: ₹${winBal.toStringAsFixed(0)})');
    buffer.writeln('• House Net Solvency Reserve: ${solvency >= 0 ? '+' : ''}₹${solvency.toStringAsFixed(0)}');
    buffer.writeln('• Total Registered Players: $users');
    buffer.writeln('========================================');
    buffer.writeln('🛡️ T69 Esports Admin Engine');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    UiHelpers.showSuccessBanner(context, 'Financial & P&L audit report copied to clipboard!');
  }

  Widget _buildRevenueAnalyticsSection() {
    if (_isLoadingRevenue && _revenueData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final data = _revenueData ?? {
      'totalDepositsCompleted': 0.0,
      'totalDepositsPending': 0.0,
      'totalWithdrawalsCompleted': 0.0,
      'totalWithdrawalsPending': 0.0,
      'totalEntryFees': 0.0,
      'totalPrizes': 0.0,
      'totalRefunds': 0.0,
      'totalBonuses': 0.0,
      'totalAdjustments': 0.0,
      'matchOperatorProfit': 0.0,
      'matchProfitMargin': 0.0,
      'netCashflow': 0.0,
      'totalVaultLiability': 0.0,
      'totalDepositBalance': 0.0,
      'totalWinningBalance': 0.0,
      'netHousePosition': 0.0,
      'totalUsersCount': 0,
      'modeBreakdown': {},
      'ledger': <Map<String, dynamic>>[],
    };

    final totalDeposits = (data['totalDepositsCompleted'] as num?)?.toDouble() ?? 0.0;
    final totalWithdrawals = (data['totalWithdrawalsCompleted'] as num?)?.toDouble() ?? 0.0;
    final totalEntries = (data['totalEntryFees'] as num?)?.toDouble() ?? 0.0;
    final totalPrizes = (data['totalPrizes'] as num?)?.toDouble() ?? 0.0;
    final matchProfit = (data['matchOperatorProfit'] as num?)?.toDouble() ?? 0.0;
    final matchMargin = (data['matchProfitMargin'] as num?)?.toDouble() ?? 0.0;
    final vaultLiability = (data['totalVaultLiability'] as num?)?.toDouble() ?? 0.0;
    final depositBal = (data['totalDepositBalance'] as num?)?.toDouble() ?? 0.0;
    final winBal = (data['totalWinningBalance'] as num?)?.toDouble() ?? 0.0;
    final netHouse = (data['netHousePosition'] as num?)?.toDouble() ?? 0.0;
    final totalUsers = data['totalUsersCount'] ?? 0;
    final isProfit = matchProfit >= 0;

    // Filter ledger
    final ledgerList = List<Map<String, dynamic>>.from(data['ledger'] ?? []);
    final query = _ledgerSearchQuery.trim().toLowerCase();
    final filteredLedger = ledgerList.where((tx) {
      final type = (tx['type']?.toString() ?? '').toLowerCase();
      if (_ledgerFilterType == 'DEPOSIT' && type != 'deposit') return false;
      if (_ledgerFilterType == 'PAYOUT' && type != 'withdrawal') return false;
      if (_ledgerFilterType == 'ENTRY' && type != 'tournament_entry') return false;
      if (_ledgerFilterType == 'PRIZE' && type != 'prize_credit') return false;
      if (_ledgerFilterType == 'REFUND' && type != 'refund') return false;
      if (_ledgerFilterType == 'ADJUSTMENT' && type != 'bonus' && type != 'adjustment') return false;

      if (query.isNotEmpty) {
        final desc = (tx['description']?.toString() ?? '').toLowerCase();
        final utr = (tx['utr_number']?.toString() ?? '').toLowerCase();
        final profile = tx['profiles'] as Map<String, dynamic>?;
        final username = (profile?['username']?.toString() ?? '').toLowerCase();
        final ign = (profile?['game_ign']?.toString() ?? '').toLowerCase();
        final fullName = (profile?['full_name']?.toString() ?? '').toLowerCase();
        return desc.contains(query) || utr.contains(query) || username.contains(query) || ign.contains(query) || fullName.contains(query);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. TOP HEADER ACTION CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINANCIAL CONTROL & P&L',
                      style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 9.5),
                    ),
                    Text(
                      'Platform Revenue Hub',
                      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
              TacticalButton(
                label: '📋 Copy Report',
                isFullWidth: false,
                height: 38,
                onPressed: () => _copyRevenueReport(data),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. TIME RANGE SELECTOR PILLS
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTimeFilterChip('ALL', 'ALL TIME'),
              const SizedBox(width: 6),
              _buildTimeFilterChip('MONTH', 'THIS MONTH'),
              const SizedBox(width: 6),
              _buildTimeFilterChip('WEEK', 'LAST 7 DAYS'),
              const SizedBox(width: 6),
              _buildTimeFilterChip('TODAY', 'TODAY'),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. HERO P&L SUMMARY BANNER CARD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isProfit
                  ? [const Color(0xFF0F2B1D), const Color(0xFF071810)]
                  : [const Color(0xFF2B0F0F), const Color(0xFF180707)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isProfit ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFEF4444).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PLATFORM MATCH P&L',
                        style: AppTextStyles.badge.copyWith(
                          color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                          fontSize: 10.5,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      isProfit ? '+${matchMargin.toStringAsFixed(1)}% PROFIT' : '-${matchMargin.abs().toStringAsFixed(1)}% LOSS',
                      style: TextStyle(
                        color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    isProfit ? '+₹${matchProfit.toStringAsFixed(0)}' : '-₹${matchProfit.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isProfit ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Net Operator Commission',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GROSS CASH INFLOW',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${totalDeposits.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.1)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL PAYOUTS PAID',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalWithdrawals.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.1)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VAULT LIABILITY',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${vaultLiability.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. SIX-CARD FINANCIAL KPI MATRIX
        Row(
          children: [
            Expanded(
              child: _buildFinancialMetricCard(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'GROSS DEPOSITS',
                value: '₹${totalDeposits.toStringAsFixed(0)}',
                subtext: data['totalDepositsPending'] > 0
                    ? '₹${(data['totalDepositsPending'] as num).toStringAsFixed(0)} Pending'
                    : 'All Settled',
                subtextColor: data['totalDepositsPending'] > 0 ? AppColors.warning : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFinancialMetricCard(
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'TOTAL PAYOUTS',
                value: '₹${totalWithdrawals.toStringAsFixed(0)}',
                subtext: data['totalWithdrawalsPending'] > 0
                    ? '₹${(data['totalWithdrawalsPending'] as num).toStringAsFixed(0)} Pending'
                    : 'Zero Pending',
                subtextColor: data['totalWithdrawalsPending'] > 0 ? AppColors.warning : AppColors.textTertiary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildFinancialMetricCard(
                icon: Icons.confirmation_number_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'MATCH ENTRIES',
                value: '₹${totalEntries.toStringAsFixed(0)}',
                subtext: 'Gross Ticket Turnover',
                subtextColor: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFinancialMetricCard(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'PRIZES CREDITED',
                value: '₹${totalPrizes.toStringAsFixed(0)}',
                subtext: 'Distributed to Winners',
                subtextColor: AppColors.textTertiary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildFinancialMetricCard(
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'VAULT LIABILITY',
                value: '₹${vaultLiability.toStringAsFixed(0)}',
                subtext: 'Dep: ₹${depositBal.toStringAsFixed(0)} • Win: ₹${winBal.toStringAsFixed(0)}',
                subtextColor: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFinancialMetricCard(
                icon: Icons.account_balance_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: 'SOLVENCY RESERVE',
                value: '${netHouse >= 0 ? '+' : ''}₹${netHouse.toStringAsFixed(0)}',
                subtext: '$totalUsers Registered Players',
                subtextColor: netHouse >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 5. MATCH FORMATS PROFITABILITY BREAKDOWN
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_esports_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'FREE FIRE MODES P&L MATRIX',
                    style: AppTextStyles.h4.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildModeBreakdownRow(
                title: 'Clash Squad (1v1, 2v2, 4v4)',
                icon: Icons.sports_martial_arts_rounded,
                data: (data['modeBreakdown'] as Map<String, dynamic>?)?['clashSquad'],
              ),
              const Divider(height: 20, thickness: 1, color: AppColors.border),
              _buildModeBreakdownRow(
                title: 'Solo Battle Royale',
                icon: Icons.person_rounded,
                data: (data['modeBreakdown'] as Map<String, dynamic>?)?['soloBR'],
              ),
              const Divider(height: 20, thickness: 1, color: AppColors.border),
              _buildModeBreakdownRow(
                title: 'Duo Battle Royale',
                icon: Icons.group_rounded,
                data: (data['modeBreakdown'] as Map<String, dynamic>?)?['duoBR'],
              ),
              const Divider(height: 20, thickness: 1, color: AppColors.border),
              _buildModeBreakdownRow(
                title: 'Squad Battle Royale',
                icon: Icons.groups_rounded,
                data: (data['modeBreakdown'] as Map<String, dynamic>?)?['squadBR'],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 6. LIVE CASHFLOW AUDIT LEDGER
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE CASHFLOW LEDGER',
                        style: AppTextStyles.h4.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filteredLedger.length} Events',
                      style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 9.5),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Ledger Search Bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _ledgerSearchController,
                  onChanged: (val) => setState(() => _ledgerSearchQuery = val),
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search player, IGN, UTR, or match title...',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
                    suffixIcon: _ledgerSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary, size: 16),
                            onPressed: () {
                              _ledgerSearchController.clear();
                              setState(() => _ledgerSearchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Ledger Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildLedgerFilterChip('ALL', 'ALL'),
                    const SizedBox(width: 6),
                    _buildLedgerFilterChip('DEPOSIT', '📥 DEPOSITS'),
                    const SizedBox(width: 6),
                    _buildLedgerFilterChip('PAYOUT', '📤 PAYOUTS'),
                    const SizedBox(width: 6),
                    _buildLedgerFilterChip('ENTRY', '🎟️ ENTRIES'),
                    const SizedBox(width: 6),
                    _buildLedgerFilterChip('PRIZE', '🏆 PRIZES'),
                    const SizedBox(width: 6),
                    _buildLedgerFilterChip('REFUND', '↩️ REFUNDS'),
                    const SizedBox(width: 6),
                    _buildLedgerFilterChip('ADJUSTMENT', '⚙️ ADM ADJ'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (filteredLedger.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'No financial events found in this period.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...filteredLedger.take(50).map((tx) => _buildLedgerTransactionItem(tx)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeFilterChip(String key, String label) {
    final isSel = _revenueTimeRange == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: isSel ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSel,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (selected) {
        if (selected) {
          setState(() => _revenueTimeRange = key);
          _loadRevenueData();
        }
      },
    );
  }

  Widget _buildLedgerFilterChip(String key, String label) {
    final isSel = _ledgerFilterType == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: isSel ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSel,
      selectedColor: AppColors.primaryDark,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (selected) {
        if (selected) setState(() => _ledgerFilterType = key);
      },
    );
  }

  Widget _buildFinancialMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtext,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.badge.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 8.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: AppTextStyles.bodySmall.copyWith(
              color: subtextColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModeBreakdownRow({
    required String title,
    required IconData icon,
    Map<String, dynamic>? data,
  }) {
    final entries = (data?['entries'] as num?)?.toDouble() ?? 0.0;
    final prizes = (data?['prizes'] as num?)?.toDouble() ?? 0.0;
    final profit = (data?['profit'] as num?)?.toDouble() ?? 0.0;
    final margin = (data?['margin'] as num?)?.toDouble() ?? 0.0;
    final count = data?['count'] ?? 0;
    final isPos = profit >= 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              Text(
                'Entries: ₹${entries.toStringAsFixed(0)} • Prizes: ₹${prizes.toStringAsFixed(0)} ($count matches)',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 9.5),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPos ? '+' : ''}₹${profit.toStringAsFixed(0)}',
              style: TextStyle(
                color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            Text(
              '${margin.toStringAsFixed(0)}% Margin',
              style: TextStyle(
                color: isPos ? const Color(0xFF10B981).withValues(alpha: 0.8) : const Color(0xFFEF4444).withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLedgerTransactionItem(Map<String, dynamic> tx) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final type = (tx['type']?.toString() ?? '').toLowerCase();
    final status = (tx['status']?.toString() ?? '').toLowerCase();
    final desc = tx['description']?.toString() ?? 'Transaction';
    final profile = tx['profiles'] as Map<String, dynamic>?;
    final username = profile?['username']?.toString() ?? 'User';
    final ign = profile?['game_ign']?.toString();
    final createdAtStr = tx['created_at']?.toString();
    String formattedTime = '';
    if (createdAtStr != null) {
      final dt = DateTime.tryParse(createdAtStr)?.toLocal();
      if (dt != null) {
        formattedTime = DateFormat('dd MMM, hh:mm a').format(dt);
      }
    }

    bool isInflow = false;
    Color iconColor = AppColors.primary;
    IconData icon = Icons.receipt_rounded;
    String typeLabel = type.toUpperCase();

    if (type == 'deposit') {
      isInflow = true;
      iconColor = const Color(0xFF10B981);
      icon = Icons.arrow_downward_rounded;
      typeLabel = 'DEPOSIT LOAD';
    } else if (type == 'withdrawal') {
      isInflow = false;
      iconColor = const Color(0xFFEF4444);
      icon = Icons.arrow_upward_rounded;
      typeLabel = 'PAYOUT';
    } else if (type == 'tournament_entry') {
      isInflow = false;
      iconColor = const Color(0xFF3B82F6);
      icon = Icons.sports_esports_rounded;
      typeLabel = 'MATCH ENTRY';
    } else if (type == 'prize_credit') {
      isInflow = true;
      iconColor = const Color(0xFFF59E0B);
      icon = Icons.emoji_events_rounded;
      typeLabel = 'PRIZE WIN';
    } else if (type == 'refund') {
      isInflow = true;
      iconColor = const Color(0xFF06B6D4);
      icon = Icons.undo_rounded;
      typeLabel = 'REFUND';
    } else if (type == 'bonus' || type == 'adjustment') {
      iconColor = const Color(0xFF8B5CF6);
      icon = Icons.admin_panel_settings_rounded;
      typeLabel = type == 'bonus' ? 'ADMIN CREDIT' : 'ADMIN DEBIT';
      isInflow = type == 'bonus';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          typeLabel,
                          style: AppTextStyles.badge.copyWith(color: iconColor, fontSize: 9),
                        ),
                        if (status != 'completed') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: status == 'pending'
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: status == 'pending' ? AppColors.warning : AppColors.error,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${isInflow ? '+' : '-'}₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isInflow ? const Color(0xFF10B981) : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$username ${ign != null && ign.isNotEmpty ? '($ign)' : ''}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // --- SECTION 1 & 2: DEPOSITS & PAYOUTS ---
  // =========================================================================

  Widget _buildPaymentsAndPayoutsSection() {
    double totalPendingAmt = 0;
    int pendingCount = 0;
    for (final tx in _transactions) {
      if (tx['status'] == 'pending') {
        totalPendingAmt += (tx['amount'] as num?)?.toDouble() ?? 0.0;
        pendingCount++;
      }
    }

    final isDepositMode = _activeSection == 1;

    final query = _searchQuery.trim().toLowerCase();
    final filteredTransactions = _transactions.where((tx) {
      if (query.isEmpty) return true;

      final accountHolder = (tx['account_holder_name']?.toString() ?? '').toLowerCase();
      final profileMap = tx['profiles'] as Map<String, dynamic>?;
      final username = (profileMap?['username']?.toString() ?? '').toLowerCase();
      final ign = (profileMap?['game_ign']?.toString() ?? '').toLowerCase();
      final utr = (tx['utr_number']?.toString() ?? '').toLowerCase();
      final upi = (tx['payout_upi_id']?.toString() ?? '').toLowerCase();
      final bank = (tx['payout_account_number']?.toString() ?? '').toLowerCase();

      return accountHolder.contains(query) ||
          username.contains(query) ||
          ign.contains(query) ||
          utr.contains(query) ||
          upi.contains(query) ||
          bank.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlueTile,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDepositMode ? 'PENDING DEPOSITS' : 'PENDING PAYOUTS',
                      style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${totalPendingAmt.toStringAsFixed(0)}',
                      style: AppTextStyles.monoCode.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text('$pendingCount Requests Awaiting', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlueTile,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OPERATION MODE', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.primaryDark)),
                    const SizedBox(height: 4),
                    Text(
                      isDepositMode ? 'Vault Credit' : 'UPI Transfer',
                      style: AppTextStyles.monoCode.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text('Direct Real-Time Sync', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search Account Holder Name, IGN, UTR...',
              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Found ${filteredTransactions.length} matching result(s)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                InkWell(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Text(
                    'Clear Search',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Status Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = filter == _selectedFilter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    _loadData();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: AppTextStyles.badge.copyWith(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Main Transactions List
        if (_isLoading) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ] else if (filteredTransactions.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No matches for "$_searchQuery"'
                        : 'No $_selectedFilter requests found.',
                    style: AppTextStyles.h4,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Try searching with another name, UTR or UPI ID.'
                        : 'All transactions are verified and clear.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ...filteredTransactions.map((tx) {
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final status = (tx['status']?.toString() ?? 'pending').toLowerCase();
            final utr = tx['utr_number']?.toString() ?? 'N/A';
            final accountHolder = tx['account_holder_name']?.toString() ?? 'Not specified';
            final gateway = tx['gateway_used']?.toString() ?? 'UPI';
            final payoutUpi = tx['payout_upi_id']?.toString() ?? '';
            final payoutBank = tx['payout_account_number']?.toString() ?? '';
            final payoutIfsc = tx['payout_ifsc']?.toString() ?? '';
            final profileMap = tx['profiles'] as Map<String, dynamic>?;
            final username = profileMap?['username'] ?? profileMap?['game_ign'] ?? 'Player';
            final currentVault = (profileMap?['wallet_balance'] as num?)?.toDouble() ?? 0.0;

            DateTime? createdDt;
            if (tx['created_at'] != null) {
              createdDt = DateTime.tryParse(tx['created_at'].toString());
            }
            final dateStr = createdDt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdDt.toLocal()) : '';

            final isPending = status == 'pending';
            final isCompleted = status == 'completed';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isCompleted
                      ? AppColors.success.withValues(alpha: 0.4)
                      : isPending
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : AppColors.border,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatusBadge(
                          label: status.toUpperCase(),
                          type: isPending
                              ? BadgeType.warning
                              : isCompleted
                                  ? BadgeType.success
                                  : BadgeType.danger,
                        ),
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: AppTextStyles.monoCode.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isCompleted
                                ? AppColors.success
                                : AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBlueTile,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_box_rounded, size: 18, color: AppColors.primaryDark),
                              const SizedBox(width: 6),
                              Text(
                                isDepositMode ? 'ACCOUNT HOLDER (SENDER):' : 'BENEFICIARY HOLDER:',
                                style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountHolder,
                            style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                          ),
                          const Divider(color: AppColors.border, height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Gamer: $username (IGN: ${profileMap?['game_ign'] ?? 'N/A'})',
                                  style: AppTextStyles.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Vault: ₹${currentVault.toStringAsFixed(0)}',
                                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (isDepositMode) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '12-DIGIT UPI UTR / TXN ID',
                                    style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textTertiary),
                                  ),
                                  Text(
                                    utr,
                                    style: AppTextStyles.monoCode.copyWith(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: AppColors.primaryDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                              tooltip: 'Copy UTR',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: utr));
                                UiHelpers.showSuccessBanner(context, 'UTR copied: $utr');
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PAYOUT DESTINATION',
                                    style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.primaryDark),
                                  ),
                                  Text(
                                    payoutUpi.isNotEmpty ? payoutUpi : 'Acc: $payoutBank ($payoutIfsc)',
                                    style: AppTextStyles.monoCode.copyWith(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: AppColors.primaryDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                              tooltip: 'Copy Payout Address',
                              onPressed: () {
                                final copyText = payoutUpi.isNotEmpty ? payoutUpi : '$payoutBank $payoutIfsc';
                                Clipboard.setData(ClipboardData(text: copyText));
                                UiHelpers.showSuccessBanner(context, 'Payout address copied: $copyText');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isDepositMode ? 'Channel: $gateway' : 'Method: ${tx['payout_method'] ?? 'UPI'}',
                            style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textTertiary),
                        ),
                      ],
                    ),

                    if (isPending) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TacticalButton(
                              label: isDepositMode
                                  ? 'Approve (₹${amount.toStringAsFixed(0)})'
                                  : 'Mark Paid (₹${amount.toStringAsFixed(0)})',
                              icon: Icons.check_circle_outline_rounded,
                              height: 42,
                              onPressed: isDepositMode
                                  ? () => _handleApproveDeposit(tx)
                                  : () => _handleApproveWithdrawal(tx),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TacticalButton(
                              label: isDepositMode ? 'Reject' : 'Refund',
                              icon: isDepositMode ? Icons.close_rounded : Icons.undo_rounded,
                              variant: TacticalButtonVariant.danger,
                              height: 42,
                              onPressed: isDepositMode
                                  ? () => _handleRejectDeposit(tx)
                                  : () => _handleRejectWithdrawal(tx),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // =========================================================================
  // --- SECTION 2: LOBBIES & TOURNAMENTS SUPER-ADMIN CONTROL ---
  // =========================================================================

  Widget _buildLobbiesManagementSection() {
    final query = _tournamentSearchQuery.trim().toLowerCase();
    final filtered = _allTournaments.where((t) {
      if (t.game.toUpperCase() == 'SYSTEM' || t.title.startsWith('__')) return false;
      if (_tournamentGameFilter != 'ALL') {
        final f = t.format.toLowerCase();
        final title = t.title.toLowerCase();
        if (_tournamentGameFilter == 'CLASH SQUAD') {
          if (!f.contains('clash') && !f.contains('cs') && !title.contains('clash') && !title.contains('cs')) return false;
        } else if (_tournamentGameFilter == 'SOLO BR') {
          if (!f.contains('solo') && !title.contains('solo')) return false;
        } else if (_tournamentGameFilter == 'DUO BR') {
          if (!f.contains('duo') && !title.contains('duo')) return false;
        } else if (_tournamentGameFilter == 'SQUAD BR') {
          if ((!f.contains('squad') || f.contains('clash') || f.contains('cs')) && (!title.contains('squad') || title.contains('clash'))) return false;
        }
      }
      if (_tournamentStatusFilter != 'ALL') {
        if (t.status.toUpperCase() != _tournamentStatusFilter) return false;
      }
      if (query.isNotEmpty) {
        final title = t.title.toLowerCase();
        final format = t.format.toLowerCase();
        final map = t.mapName.toLowerCase();
        final roomId = (t.roomId ?? '').toLowerCase();
        return title.contains(query) || format.contains(query) || map.contains(query) || roomId.contains(query);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Action Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sports_esports_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOBBIES & TOURNAMENTS',
                      style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 9.5),
                    ),
                    Text(
                      'Live Tournaments Engine',
                      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
              TacticalButton(
                label: '+ New Lobby',
                isFullWidth: false,
                height: 38,
                onPressed: _showCreateTournamentDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Search Bar for Tournaments
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _tournamentSearchController,
            onChanged: (val) => setState(() => _tournamentSearchQuery = val),
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search lobby title, map, format, room ID...',
              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              suffixIcon: _tournamentSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        _tournamentSearchController.clear();
                        setState(() => _tournamentSearchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Game & Status Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...['ALL', 'CLASH SQUAD', 'SOLO BR', 'DUO BR', 'SQUAD BR'].map((format) {
                final isSel = _tournamentGameFilter == format;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(format, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: isSel ? Colors.white : AppColors.textSecondary)),
                    selected: isSel,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (selected) {
                      if (selected) setState(() => _tournamentGameFilter = format);
                    },
                  ),
                );
              }),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: AppColors.border),
              const SizedBox(width: 8),
              ...['ALL', 'UPCOMING', 'LIVE', 'COMPLETED', 'CANCELLED'].map((status) {
                final isSel = _tournamentStatusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: isSel ? Colors.white : AppColors.textSecondary)),
                    selected: isSel,
                    selectedColor: AppColors.primaryDark,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (selected) {
                      if (selected) setState(() => _tournamentStatusFilter = status);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (_isLoadingTournaments) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ] else if (filtered.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.videogame_asset_off_rounded, size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text('No Lobbies Found', style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text('Tap "+ New Lobby" to create the first match.', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'ACTIVE LOBBIES (${filtered.length})',
              style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 8),

          ...filtered.map((tournament) => _buildTournamentAdminCard(tournament)),
        ],
      ],
    );
  }

  Widget _buildTournamentAdminCard(TournamentModel t) {
    final isLive = t.status == 'live' || t.status == 'ongoing';
    final isCancelled = t.status == 'cancelled';
    final isCompleted = t.status == 'completed';

    final startTimeStr = DateFormat('dd MMM, hh:mm a').format(t.startTime.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive
              ? const Color(0xFF10B981)
              : isCancelled
                  ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                  : AppColors.border,
          width: isLive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Format, Game, Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t.game.toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.format,
                      style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
                StatusBadge(
                  label: t.status.toUpperCase(),
                  type: isLive
                      ? BadgeType.success
                      : isCancelled
                          ? BadgeType.danger
                          : isCompleted
                              ? BadgeType.neutral
                              : BadgeType.info,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Title & Map
            Text(
              t.title,
              style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              'Map: ${t.mapName} • Starts: $startTimeStr',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
            ),

            const SizedBox(height: 12),

            // Financial & Slot KPIs
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlueTile,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ENTRY FEE', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textTertiary)),
                        Text('₹${t.entryFee.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRIZE POOL', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textTertiary)),
                        Text('₹${t.prizePool.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PER KILL', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textTertiary)),
                        Text('₹${t.perKill.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SLOTS', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textTertiary)),
                        Text('${t.filledSlots}/${t.maxSlots}', style: AppTextStyles.monoCode.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Room IDP preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        t.roomId != null && t.roomId!.isNotEmpty
                            ? 'Room: ${t.roomId} (Pass: ${t.roomPassword ?? "None"})'
                            : 'Room IDP: Not yet broadcasted',
                        style: AppTextStyles.monoCode.copyWith(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _showSetRoomIdpDialog(t),
                    child: Text('Edit IDP', style: AppTextStyles.badge.copyWith(color: AppColors.primary, fontSize: 9.5)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Action Buttons Toolbar
            Row(
              children: [
                Expanded(
                  child: TacticalButton(
                    label: 'Edit Lobby',
                    icon: Icons.edit_note_rounded,
                    variant: TacticalButtonVariant.outline,
                    height: 36,
                    onPressed: () => _showEditTournamentDialog(t),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TacticalButton(
                    label: 'Set IDP',
                    icon: Icons.key_rounded,
                    height: 36,
                    onPressed: () => _showSetRoomIdpDialog(t),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Emergency Cancel & 100% Refund Players',
                  icon: const Icon(Icons.cancel_presentation_rounded, color: AppColors.secondary, size: 22),
                  onPressed: () => _showEmergencyCancelDialog(t),
                ),
                IconButton(
                  tooltip: 'Delete Lobby',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 22),
                  onPressed: () => _showDeleteTournamentDialog(t),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTournamentDialog() {
    final titleController = TextEditingController(text: 'Clash Squad Championship');
    final mapController = TextEditingController(text: 'Bermuda');
    final entryFeeController = TextEditingController(text: '20');
    final prizePoolController = TextEditingController(text: '35');
    final perKillController = TextEditingController(text: '0');
    final maxSlotsController = TextEditingController(text: '2');
    final bannerUrlController = TextEditingController(text: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80');

    String selectedGame = 'FREE FIRE';
    String selectedFormat = '1v1 Clash Squad';
    DateTime selectedStartTime = DateTime.now().add(const Duration(minutes: 30));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text('Create Custom Lobby', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Game: ', style: AppTextStyles.inputLabel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedGame,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'FREE FIRE', child: Text('Free Fire')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedGame = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                TacticalTextField(
                  label: 'Tournament Title',
                  controller: titleController,
                  hint: 'e.g. Free Fire Squad Cup',
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TacticalTextField(
                        label: 'Format',
                        hint: 'Solo BR, 1v1 CS, Squad',
                        controller: TextEditingController(text: selectedFormat),
                        onChanged: (v) => selectedFormat = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TacticalTextField(
                        label: 'Map Name',
                        controller: mapController,
                        hint: 'Bermuda, Erangel',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TacticalTextField(
                        label: 'Entry Fee (₹)',
                        controller: entryFeeController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TacticalTextField(
                        label: 'Prize Pool (₹)',
                        controller: prizePoolController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TacticalTextField(
                        label: 'Per Kill (₹)',
                        controller: perKillController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TacticalTextField(
                        label: 'Max Slots',
                        controller: maxSlotsController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: dialogCtx,
                      initialDate: selectedStartTime,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (pickedDate != null && dialogCtx.mounted) {
                      final pickedTime = await showTimePicker(
                        context: dialogCtx,
                        initialTime: TimeOfDay.fromDateTime(selectedStartTime),
                      );
                      if (pickedTime != null) {
                        setDialogState(() {
                          selectedStartTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('START TIME', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textTertiary)),
                            Text(DateFormat('dd MMM yyyy, hh:mm a').format(selectedStartTime), style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TacticalTextField(
                  label: 'Cover Banner URL',
                  controller: bannerUrlController,
                  hint: 'https://...',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: 'Create Lobby',
              isLoading: isSaving,
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                final title = titleController.text.trim();
                final entry = double.tryParse(entryFeeController.text.trim()) ?? 0.0;
                final prize = double.tryParse(prizePoolController.text.trim()) ?? 0.0;
                final kill = double.tryParse(perKillController.text.trim()) ?? 0.0;
                final slots = int.tryParse(maxSlotsController.text.trim()) ?? 48;
                final map = mapController.text.trim().isEmpty ? 'Bermuda' : mapController.text.trim();

                if (title.isEmpty) {
                  UiHelpers.showErrorBanner(context, 'Tournament title cannot be empty.');
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  await repo.createAdminTournament(
                    title: title,
                    game: selectedGame,
                    entryFee: entry,
                    prizePool: prize,
                    perKill: kill,
                    format: selectedFormat,
                    mapName: map,
                    maxSlots: slots,
                    startTime: selectedStartTime,
                    bannerUrl: bannerUrlController.text.trim(),
                  );

                  ref.invalidate(freeFireTournamentsProvider);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                  if (mounted) {
                    UiHelpers.showSuccessBanner(context, 'Lobby "$title" successfully created!');
                    await _loadTournamentsManagementData();
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) UiHelpers.showErrorBanner(context, 'Creation failed: ${e.toString()}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTournamentDialog(TournamentModel t) {
    final titleController = TextEditingController(text: t.title);
    final mapController = TextEditingController(text: t.mapName);
    final entryFeeController = TextEditingController(text: t.entryFee.toStringAsFixed(0));
    final prizePoolController = TextEditingController(text: t.prizePool.toStringAsFixed(0));
    final perKillController = TextEditingController(text: t.perKill.toStringAsFixed(0));
    final maxSlotsController = TextEditingController(text: t.maxSlots.toString());
    String selectedStatus = t.status;
    DateTime selectedStartTime = t.startTime;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text('Edit Tournament Lobby', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TacticalTextField(
                  label: 'Tournament Title',
                  controller: titleController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TacticalTextField(
                        label: 'Entry Fee (₹)',
                        controller: entryFeeController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TacticalTextField(
                        label: 'Prize Pool (₹)',
                        controller: prizePoolController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TacticalTextField(
                        label: 'Per Kill (₹)',
                        controller: perKillController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TacticalTextField(
                        label: 'Max Slots',
                        controller: maxSlotsController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'Map Name',
                  controller: mapController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Status: ', style: AppTextStyles.inputLabel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedStatus,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'open', child: Text('Open (Accepting Players)')),
                              DropdownMenuItem(value: 'live', child: Text('Live (Ongoing)')),
                              DropdownMenuItem(value: 'completed', child: Text('Completed')),
                              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedStatus = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: 'Save Changes',
              isLoading: isSaving,
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                setDialogState(() => isSaving = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  await repo.updateTournamentDetails(
                    tournamentId: t.id,
                    title: titleController.text.trim(),
                    entryFee: double.tryParse(entryFeeController.text.trim()),
                    prizePool: double.tryParse(prizePoolController.text.trim()),
                    perKill: double.tryParse(perKillController.text.trim()),
                    maxSlots: int.tryParse(maxSlotsController.text.trim()),
                    mapName: mapController.text.trim(),
                    status: selectedStatus,
                    startTime: selectedStartTime,
                  );

                  ref.invalidate(freeFireTournamentsProvider);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                  if (mounted) {
                    UiHelpers.showSuccessBanner(context, 'Tournament details updated.');
                    await _loadTournamentsManagementData();
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) UiHelpers.showErrorBanner(context, 'Update failed: ${e.toString()}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSetRoomIdpDialog(TournamentModel t) {
    final roomIdController = TextEditingController(text: t.roomId ?? '');
    final passController = TextEditingController(text: t.roomPassword ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.key_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text('Set Room ID & Password', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Match: ${t.title}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              TacticalTextField(
                label: 'Custom Room ID',
                controller: roomIdController,
                hint: 'e.g. 8493021',
              ),
              const SizedBox(height: 12),
              TacticalTextField(
                label: 'Custom Room Password',
                controller: passController,
                hint: 'e.g. 1234',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: 'Broadcast to Players',
              isLoading: isSaving,
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                if (roomIdController.text.trim().isEmpty) {
                  UiHelpers.showErrorBanner(context, 'Room ID cannot be empty.');
                  return;
                }
                setDialogState(() => isSaving = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  await repo.lockAndBroadcastIdp(
                    tournamentId: t.id,
                    roomId: roomIdController.text.trim(),
                    roomPassword: passController.text.trim(),
                    allowScreenshots: true,
                  );

                  ref.invalidate(freeFireTournamentsProvider);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                  if (mounted) {
                    UiHelpers.showSuccessBanner(context, 'Room ID & Password broadcasted to players!');
                    await _loadTournamentsManagementData();
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) UiHelpers.showErrorBanner(context, 'Broadcast failed: ${e.toString()}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyCancelDialog(TournamentModel t) {
    final reasonController = TextEditingController(text: 'Admin Emergency Cancel / Server Maintenance');
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.secondary, size: 26),
              const SizedBox(width: 10),
              Text('Emergency Cancel & Refund', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancel "${t.title}" and automatically refund 100% of entry fees (₹${t.entryFee.toStringAsFixed(0)} per player) back to all registered player vaults?',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 14),
              TacticalTextField(
                label: 'Reason for Cancellation',
                controller: reasonController,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: 'Cancel & Auto-Refund',
              variant: TacticalButtonVariant.danger,
              isLoading: isProcessing,
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                setDialogState(() => isProcessing = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  final refundedCount = await repo.cancelTournamentWithAutoRefund(
                    tournamentId: t.id,
                    reason: reasonController.text.trim(),
                  );

                  ref.invalidate(freeFireTournamentsProvider);
                  ref.invalidate(walletTransactionsProvider);

                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                  if (mounted) {
                    UiHelpers.showSuccessBanner(context, 'Tournament cancelled. $refundedCount players received 100% auto-refund.');
                    await _loadTournamentsManagementData();
                  }
                } catch (e) {
                  setDialogState(() => isProcessing = false);
                  if (mounted) UiHelpers.showErrorBanner(context, 'Cancel failed: ${e.toString()}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTournamentDialog(TournamentModel t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text('Delete Tournament?', style: AppTextStyles.h4),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove "${t.title}"? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TacticalButton(
            label: 'Delete',
            variant: TacticalButtonVariant.danger,
            height: 38,
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tournamentRepoProvider);
                await repo.deleteTournament(t.id);
                ref.invalidate(freeFireTournamentsProvider);

                if (mounted) {
                  UiHelpers.showSuccessBanner(context, 'Tournament deleted successfully.');
                  await _loadTournamentsManagementData();
                }
              } catch (e) {
                if (mounted) UiHelpers.showErrorBanner(context, 'Failed to delete: ${e.toString()}');
              }
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // --- SECTION 3: PLAYER ACCOUNTS & WALLET BALANCES (GOD MODE) ---
  // =========================================================================

  Widget _buildPlayersManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.manage_accounts_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAYERS & WALLET AUDITING',
                      style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 9.5),
                    ),
                    Text(
                      'Manage Users & Balances',
                      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                tooltip: 'Refresh Players',
                onPressed: _loadProfilesManagementData,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _profileSearchController,
            onSubmitted: (val) {
              setState(() => _profileSearchQuery = val);
              _loadProfilesManagementData();
            },
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search username, IGN, UID, or name...',
              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                onPressed: () {
                  setState(() => _profileSearchQuery = _profileSearchController.text);
                  _loadProfilesManagementData();
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 14),

        if (_isLoadingProfiles) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ] else if (_allProfiles.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.person_search_rounded, size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text('No Players Found', style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text('Try a different search query.', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'REGISTERED PLAYERS (${_allProfiles.length})',
              style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 8),

          ..._allProfiles.map((p) => _buildPlayerProfileCard(p)),
        ],
      ],
    );
  }

  Widget _buildPlayerProfileCard(Map<String, dynamic> p) {
    final userId = p['id']?.toString() ?? '';
    final username = p['username']?.toString() ?? 'Player';
    final fullName = p['full_name']?.toString() ?? 'Anonymous';
    final ign = p['game_ign']?.toString() ?? 'N/A';
    final uid = p['game_uid']?.toString() ?? 'N/A';
    final role = (p['role']?.toString() ?? 'player').toLowerCase();
    final isBanned = role == 'banned';
    final isVerified = p['is_verified'] as bool? ?? false;
    final totalWallet = (p['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    final depositBal = (p['deposit_balance'] as num?)?.toDouble() ?? 0.0;
    final winningBal = (p['winning_balance'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBanned ? const Color(0xFFEF4444) : AppColors.border,
          width: isBanned ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isBanned ? const Color(0xFFEF4444) : AppColors.primary,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'P',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fullName,
                              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: Color(0xFFF59E0B), size: 16),
                          ],
                        ],
                      ),
                      Text('@$username • IGN: $ign (UID: $uid)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
                StatusBadge(
                  label: isBanned ? 'BANNED' : role.toUpperCase(),
                  type: isBanned ? BadgeType.danger : BadgeType.success,
                ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlueTile,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL VAULT', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.primaryDark)),
                        Text('₹${totalWallet.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DEPOSIT BAL', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textTertiary)),
                        Text('₹${depositBal.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WINNING BAL', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textTertiary)),
                        Text('₹${winningBal.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TacticalButton(
                    label: '± Adjust Balance',
                    icon: Icons.account_balance_wallet_rounded,
                    height: 36,
                    onPressed: () => _showAdjustBalanceDialog(p),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TacticalButton(
                    label: isVerified ? 'Unverify' : '⭐ Verify',
                    variant: TacticalButtonVariant.outline,
                    height: 36,
                    onPressed: () => _toggleUserVerified(userId, isVerified),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: isBanned ? 'Unban Player' : 'Ban Player Account',
                  icon: Icon(
                    isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: isBanned ? const Color(0xFF10B981) : AppColors.secondary,
                    size: 22,
                  ),
                  onPressed: () => _toggleUserBan(userId, isBanned),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustBalanceDialog(Map<String, dynamic> p) {
    final userId = p['id']?.toString() ?? '';
    final username = p['username']?.toString() ?? 'Player';
    final amountController = TextEditingController();
    final reasonController = TextEditingController(text: 'Admin balance adjustment');

    bool isCredit = true;
    String balanceType = 'deposit';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text('Adjust Wallet Balance', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: @$username', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => isCredit = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isCredit ? const Color(0xFF16A34A) : AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '+ Credit (Add)',
                              style: TextStyle(
                                color: isCredit ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => isCredit = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isCredit ? const Color(0xFFDC2626) : AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '- Debit (Deduct)',
                              style: TextStyle(
                                color: !isCredit ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Text('Target Vault: ', style: AppTextStyles.inputLabel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: balanceType,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'deposit', child: Text('Deposit Balance')),
                              DropdownMenuItem(value: 'winning', child: Text('Winning Balance')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => balanceType = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                TacticalTextField(
                  label: 'Amount (₹)',
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  hint: 'e.g. 100',
                ),

                const SizedBox(height: 12),

                TacticalTextField(
                  label: 'Audit Reason',
                  controller: reasonController,
                  hint: 'e.g. Tournament winner compensation',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: isCredit ? 'Credit Balance' : 'Deduct Balance',
              variant: isCredit ? TacticalButtonVariant.primary : TacticalButtonVariant.danger,
              isLoading: isSaving,
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amt <= 0) {
                  UiHelpers.showErrorBanner(context, 'Please enter a valid positive amount.');
                  return;
                }

                final finalAmount = isCredit ? amt : -amt;
                setDialogState(() => isSaving = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  final admin = ref.read(authControllerProvider).value;
                  final adminName = admin?.fullName ?? 'Super Admin';

                  await repo.adjustUserWalletBalance(
                    userId: userId,
                    amount: finalAmount,
                    balanceType: balanceType,
                    reason: reasonController.text.trim(),
                    adminName: adminName,
                  );

                  ref.invalidate(walletTransactionsProvider);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                  if (mounted) {
                    UiHelpers.showSuccessBanner(
                      context,
                      '${isCredit ? "Credited" : "Deducted"} ₹${amt.toStringAsFixed(0)} to @$username (${balanceType.toUpperCase()}).',
                    );
                    await _loadProfilesManagementData();
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) UiHelpers.showErrorBanner(context, 'Adjustment failed: ${e.toString()}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserVerified(String userId, bool current) async {
    try {
      final repo = ref.read(tournamentRepoProvider);
      await repo.toggleUserVerifiedBadge(userId, !current);
      if (mounted) {
        UiHelpers.showSuccessBanner(context, !current ? '⭐ Player granted Verified Star status.' : 'Verified badge revoked.');
        await _loadProfilesManagementData();
      }
    } catch (e) {
      if (mounted) UiHelpers.showErrorBanner(context, 'Update failed: ${e.toString()}');
    }
  }

  Future<void> _toggleUserBan(String userId, bool isCurrentlyBanned) async {
    try {
      final repo = ref.read(tournamentRepoProvider);
      await repo.toggleUserBanStatus(userId, !isCurrentlyBanned);
      if (mounted) {
        UiHelpers.showSuccessBanner(context, !isCurrentlyBanned ? '🚫 Player banned from matches.' : '✅ Player account unbanned.');
        await _loadProfilesManagementData();
      }
    } catch (e) {
      if (mounted) UiHelpers.showErrorBanner(context, 'Ban update failed: ${e.toString()}');
    }
  }

  // =========================================================================
  // --- SECTION 4: LOBBY MODERATION & KICK PLAYERS ---
  // =========================================================================

  Future<void> _loadAdminTournaments() async {
    setState(() => _isLoadingLobbyData = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final tournaments = await repo.fetchAllTournamentsForHost();
      if (mounted) {
        setState(() {
          _adminTournaments = tournaments;
          if (_selectedAdminTournament == null && tournaments.isNotEmpty) {
            _selectedAdminTournament = tournaments.first;
          } else if (_selectedAdminTournament != null) {
            final found = tournaments.where((t) => t.id == _selectedAdminTournament!.id).toList();
            if (found.isNotEmpty) {
              _selectedAdminTournament = found.first;
            } else if (tournaments.isNotEmpty) {
              _selectedAdminTournament = tournaments.first;
            }
          }
          _isLoadingLobbyData = false;
        });
        if (_selectedAdminTournament != null) {
          await _loadLobbyRegistrations(_selectedAdminTournament!.id);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLobbyData = false);
    }
  }

  Future<void> _loadLobbyRegistrations(String tournamentId) async {
    setState(() => _isLoadingLobbyData = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final regs = await repo.fetchTournamentRegistrations(tournamentId);
      final refreshed = await repo.fetchTournamentById(tournamentId);
      if (mounted) {
        setState(() {
          _lobbyRegistrations = regs;
          if (refreshed != null) {
            _selectedAdminTournament = refreshed;
          }
          _isLoadingLobbyData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLobbyData = false);
    }
  }

  void _showAdminKickPlayerDialog({
    required TournamentModel tournament,
    required Map<String, dynamic> registration,
  }) {
    final slot = (registration['slot_number'] as num?)?.toInt() ?? 1;
    final ign = registration['game_ign'] ?? registration['profiles']?['username'] ?? 'Player';
    final username = registration['profiles']?['username'] ?? 'User';
    final uid = registration['game_uid'] ?? 'N/A';
    final userId = registration['user_id']?.toString() ?? '';
    final entryFee = tournament.entryFee;

    bool refundFee = entryFee > 0;
    String selectedReason = 'Violating Lobby Rules';
    final List<String> reasonPresets = [
      'Violating Lobby Rules',
      'Fake / Inactive Free Fire UID',
      'Host / Player Removal Request',
      'Cheating / Hacking Suspicion',
      'AFK / Slot Squatting',
      'Abusive Chat / Behavior',
      'Other Custom Reason',
    ];
    final customReasonController = TextEditingController();
    bool isKicking = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.secondary, width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_remove_rounded, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kick Player from Lobby', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900)),
                    Text('Slot #$slot • $ign', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBlueTile,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TARGET PLAYER', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 9)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SLOT #$slot',
                              style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(ign, style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                      Text('Username: $username • UID: $uid', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                      if (entryFee > 0) ...[
                        const Divider(color: AppColors.border, height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Entry Fee Paid:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                            Text('₹${entryFee.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (entryFee > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: refundFee ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: refundFee ? const Color(0xFF86EFAC) : const Color(0xFFFDA4AF),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                refundFee ? 'Refund Entry Fee (₹${entryFee.toStringAsFixed(0)})' : 'No Refund (Cheater / Penalty)',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: refundFee ? const Color(0xFF15803D) : const Color(0xFFBE123C),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                refundFee ? 'Credits ₹${entryFee.toStringAsFixed(0)} to player\'s deposit vault.' : 'Entry fee is forfeited (zero refund).',
                                style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: refundFee,
                          activeThumbColor: const Color(0xFF16A34A),
                          onChanged: (val) => setDialogState(() => refundFee = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Text('REASON FOR KICK:', style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 9.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      items: reasonPresets.map((r) => DropdownMenuItem(value: r, child: Text(r, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedReason = val);
                      },
                    ),
                  ),
                ),

                if (selectedReason == 'Other Custom Reason') ...[
                  const SizedBox(height: 10),
                  TacticalTextField(
                    label: 'Custom Reason',
                    controller: customReasonController,
                    hint: 'Type reason here...',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: '🚫 Kick Player',
              variant: TacticalButtonVariant.danger,
              isLoading: isKicking,
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                final finalReason = selectedReason == 'Other Custom Reason' && customReasonController.text.trim().isNotEmpty
                    ? customReasonController.text.trim()
                    : selectedReason;

                setDialogState(() => isKicking = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  const adminName = 'T69 Team';

                  await repo.kickPlayerFromLobby(
                    tournamentId: tournament.id,
                    userId: userId,
                    slotNumber: slot,
                    refundEntryFee: refundFee,
                    reason: finalReason,
                    adminOrHostName: adminName,
                    teamOrPlayerName: ign,
                    gameUid: uid,
                    isHostBan: false,
                  );

                  ref.invalidate(freeFireTournamentsProvider);
                  ref.invalidate(userRegisteredTournamentIdsProvider);
                  ref.invalidate(walletTransactionsProvider);

                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                  if (mounted) {
                    UiHelpers.showSuccessBanner(
                      context,
                      'Player "$ign" kicked from Slot #$slot.${refundFee ? " ₹${entryFee.toStringAsFixed(0)} refunded." : ""}',
                    );
                    await _loadLobbyRegistrations(tournament.id);
                  }
                } catch (e) {
                  setDialogState(() => isKicking = false);
                  if (mounted) {
                    UiHelpers.showErrorBanner(context, 'Kick failed: ${e.toString()}');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyModerationSection() {
    final query = _playerSearchQuery.trim().toLowerCase();
    final filteredRegs = _lobbyRegistrations.where((reg) {
      if (query.isEmpty) return true;
      final ign = (reg['game_ign']?.toString() ?? '').toLowerCase();
      final uid = (reg['game_uid']?.toString() ?? '').toLowerCase();
      final username = (reg['profiles']?['username']?.toString() ?? '').toLowerCase();
      final teamName = (reg['team_name']?.toString() ?? '').toLowerCase();
      final slotStr = (reg['slot_number']?.toString() ?? '').toLowerCase();
      return ign.contains(query) || uid.contains(query) || username.contains(query) || teamName.contains(query) || slotStr.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.security_rounded, color: AppColors.secondary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSTANT LOBBY MODERATION',
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.secondary,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      'Kick / Remove Players',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                tooltip: 'Refresh Tournaments',
                onPressed: _loadAdminTournaments,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'SELECT TOURNAMENT LOBBY:',
          style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 9.5),
        ),
        const SizedBox(height: 8),

        if (_adminTournaments.isEmpty && !_isLoadingLobbyData) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'No tournaments found in system.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ] else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _adminTournaments.map((t) {
                final isSelected = _selectedAdminTournament?.id == t.id;
                final isLive = t.status == 'live' || t.status == 'ongoing';
                final isCompleted = t.status == 'completed';

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedAdminTournament = t);
                      _loadLobbyRegistrations(t.id);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: 1.2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.format,
                                style: AppTextStyles.badge.copyWith(
                                  color: isSelected ? Colors.white70 : AppColors.textTertiary,
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isLive
                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                      : (isCompleted ? Colors.grey.withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: isLive ? const Color(0xFF10B981) : (isCompleted ? Colors.grey : const Color(0xFF6366F1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Slots: ${t.filledSlots}/${t.maxSlots} • Entry: ₹${t.entryFee.toStringAsFixed(0)}',
                            style: AppTextStyles.monoCode.copyWith(
                              color: isSelected ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 16),

        if (_selectedAdminTournament != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceBlueTile,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAdminTournament!.title,
                        style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedAdminTournament!.format} • Map: ${_selectedAdminTournament!.mapName} • Host: ${_selectedAdminTournament!.hostName ?? "Certified Host"}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'FILLED',
                        style: AppTextStyles.badge.copyWith(color: Colors.white70, fontSize: 8),
                      ),
                      Text(
                        '${_lobbyRegistrations.length}/${_selectedAdminTournament!.maxSlots}',
                        style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _playerSearchController,
              onChanged: (val) => setState(() => _playerSearchQuery = val),
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search player by IGN, UID, Slot #...',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: _playerSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary, size: 18),
                        onPressed: () {
                          _playerSearchController.clear();
                          setState(() => _playerSearchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (_isLoadingLobbyData) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ] else if (_lobbyRegistrations.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: 10),
                    Text('No Players Registered Yet', style: AppTextStyles.h4),
                    const SizedBox(height: 4),
                    Text(
                      'As players register for this lobby, they will appear here.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (filteredRegs.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text('No player matches "$_playerSearchQuery"', style: AppTextStyles.bodyMedium),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REGISTERED PLAYERS (${filteredRegs.length})',
                    style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8),
                  ),
                  Text(
                    'Tap Kick to remove instantly',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            ...filteredRegs.map((reg) {
              final slot = (reg['slot_number'] as num?)?.toInt() ?? 1;
              final ign = reg['game_ign'] ?? reg['profiles']?['username'] ?? 'Player';
              final username = reg['profiles']?['username'] ?? 'User';
              final uid = reg['game_uid'] ?? 'N/A';
              final teamName = reg['team_name'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '#$slot',
                          style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  ign,
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (teamName != null && teamName.isNotEmpty && teamName != ign) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    teamName,
                                    style: const TextStyle(fontSize: 8.5, color: AppColors.primary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'User: @$username • UID: $uid',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TacticalButton(
                      label: 'Kick',
                      icon: Icons.person_remove_rounded,
                      variant: TacticalButtonVariant.danger,
                      height: 34,
                      isFullWidth: false,
                      onPressed: () => _showAdminKickPlayerDialog(
                        tournament: _selectedAdminTournament!,
                        registration: reg,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // KICKED / BANNED PLAYERS LIST
          Builder(
            builder: (context) {
              final kickedList = _selectedAdminTournament?.kickedTeams ?? [];
              if (kickedList.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'REMOVED / BANNED PLAYERS (${kickedList.length})',
                          style: AppTextStyles.badge.copyWith(color: AppColors.error, letterSpacing: 0.8),
                        ),
                        Text(
                          'Re-entry Blocked',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...kickedList.map((k) {
                    final slot = (k['slot'] as num?)?.toInt() ?? 1;
                    final teamOrIgn = k['team_name']?.toString() ?? 'Player';
                    final uid = k['game_uid']?.toString() ?? 'N/A';
                    final userId = k['user_id']?.toString() ?? '';
                    final reason = k['reason']?.toString() ?? 'Violation of lobby rules';
                    final action = k['action']?.toString() ?? 'KICKED';
                    final enforcedBy = k['enforced_by']?.toString() ?? 'T69 Team';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        teamOrIgn,
                                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'SLOT #$slot • $action',
                                        style: const TextStyle(fontSize: 8, color: Color(0xFFDC2626), fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'UID: $uid • Reason: $reason',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 10.5, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Enforced by: $enforcedBy',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TacticalButton(
                            label: 'Allow Rejoin',
                            icon: Icons.lock_open_rounded,
                            variant: TacticalButtonVariant.outline,
                            height: 34,
                            isFullWidth: false,
                            onPressed: () async {
                              try {
                                final repo = ref.read(tournamentRepoProvider);
                                await repo.unbanOrAllowPlayerRejoin(
                                  tournamentId: _selectedAdminTournament!.id,
                                  userId: userId,
                                  gameUid: uid,
                                );
                                if (context.mounted) {
                                  UiHelpers.showSuccessBanner(context, 'Player "$teamOrIgn" unbanned. Re-entry allowed.');
                                  await _loadAdminTournaments();
                                  if (_selectedAdminTournament != null) {
                                    await _loadLobbyRegistrations(_selectedAdminTournament!.id);
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  UiHelpers.showErrorBanner(context, 'Failed to unban: ${e.toString()}');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  // =========================================================================
  // --- SECTION 5: HOMESCREEN PROMO BANNERS ---
  // =========================================================================

  Widget _buildBannersManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.view_carousel_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOMESCREEN CAROUSEL BANNERS',
                      style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 9.5),
                    ),
                    Text(
                      'Featured Promo Campaigns',
                      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
              TacticalButton(
                label: '+ Add Banner',
                isFullWidth: false,
                height: 38,
                onPressed: _showAddBannerDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (_isLoadingBanners) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ] else if (_allBanners.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text('No Promo Banners', style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text('Tap "+ Add Banner" to publish your first homescreen card.', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'ACTIVE & INACTIVE BANNERS (${_allBanners.length})',
              style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 8),

          ..._allBanners.map((b) => _buildBannerAdminCard(b)),
        ],
      ],
    );
  }

  Widget _buildBannerAdminCard(BannerModel b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: b.isActive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceBlueTile,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  b.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported_rounded, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          b.tag,
                          style: const TextStyle(color: AppColors.primary, fontSize: 8.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          b.title,
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (b.subtitle != null && b.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      b.subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: b.isActive,
              activeThumbColor: const Color(0xFF16A34A),
              onChanged: (val) => _toggleBanner(b.id, b.isActive),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.secondary, size: 20),
              tooltip: 'Delete Banner',
              onPressed: () => _deleteBanner(b.id),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBannerDialog() {
    final titleController = TextEditingController(text: 'FREE FIRE GRAND PRIX');
    final subtitleController = TextEditingController(text: 'Win ₹10,000 cash prizes');
    final imageController = TextEditingController(text: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80');
    final tagController = TextEditingController(text: 'HOT TOURNAMENT');
    String selectedAction = 'tournament';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text('Add New Banner', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TacticalTextField(
                  label: 'Banner Title',
                  controller: titleController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'Subtitle / Description',
                  controller: subtitleController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'Image URL',
                  controller: imageController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'Badge Tag (e.g. HOT, FEATURED)',
                  controller: tagController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Action: ', style: AppTextStyles.inputLabel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedAction,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'tournament', child: Text('Open Tournament Hub')),
                              DropdownMenuItem(value: 'game_hub', child: Text('Open Game Hub')),
                              DropdownMenuItem(value: 'external_link', child: Text('External URL')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedAction = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: 'Save Banner',
              isLoading: isSaving,
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                if (titleController.text.trim().isEmpty || imageController.text.trim().isEmpty) {
                  UiHelpers.showErrorBanner(context, 'Title and image URL are required.');
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  await repo.addNewBanner(
                    title: titleController.text.trim(),
                    subtitle: subtitleController.text.trim(),
                    imageUrl: imageController.text.trim(),
                    tag: tagController.text.trim(),
                    actionType: selectedAction,
                  );

                  ref.invalidate(bannersProvider);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                  if (mounted) {
                    UiHelpers.showSuccessBanner(context, 'Promo banner added to home page!');
                    await _loadBannersData();
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) UiHelpers.showErrorBanner(context, 'Add failed: ${e.toString()}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBanner(String bannerId, bool current) async {
    try {
      final repo = ref.read(tournamentRepoProvider);
      await repo.toggleBannerStatus(bannerId, !current);
      ref.invalidate(bannersProvider);
      if (mounted) {
        UiHelpers.showSuccessBanner(context, !current ? 'Banner activated.' : 'Banner deactivated.');
        await _loadBannersData();
      }
    } catch (e) {
      if (mounted) UiHelpers.showErrorBanner(context, 'Status update failed: ${e.toString()}');
    }
  }

  Future<void> _deleteBanner(String bannerId) async {
    try {
      final repo = ref.read(tournamentRepoProvider);
      await repo.deleteBanner(bannerId);
      ref.invalidate(bannersProvider);
      if (mounted) {
        UiHelpers.showSuccessBanner(context, 'Banner deleted.');
        await _loadBannersData();
      }
    } catch (e) {
      if (mounted) UiHelpers.showErrorBanner(context, 'Delete failed: ${e.toString()}');
    }
  }

  // =========================================================================
  // --- SECTION 6: SPONSORS & PARTNER BRANDS ---
  // =========================================================================

  Widget _buildSponsorsManagementSection() {
    final sponsorsAsync = ref.watch(sponsorsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.handshake_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOME SPONSORS & PARTNERS',
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.primaryDark,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      'Manage Official Brands',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              TacticalButton(
                label: '+ Add Sponsor',
                isFullWidth: false,
                height: 38,
                onPressed: _showAddSponsorDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        sponsorsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text('Error loading sponsors: $err', style: TextStyle(color: Colors.red.shade700)),
          ),
          data: (sponsors) {
            if (sponsors.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.business_rounded, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      Text(
                        'No Sponsors Registered',
                        style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add partner logos to feature them on the player home screen.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TacticalButton(
                        label: 'Add First Sponsor',
                        isFullWidth: false,
                        height: 38,
                        onPressed: _showAddSponsorDialog,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'ACTIVE PARTNERS (${sponsors.length})',
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sponsors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final sponsor = sponsors[index];
                    return _buildSponsorCard(sponsor);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSponsorCard(SponsorModel sponsor) {
    Color badgeColor;
    String tierLabel;

    switch (sponsor.tier) {
      case 'title_sponsor':
        badgeColor = const Color(0xFFF59E0B);
        tierLabel = 'TITLE SPONSOR';
        break;
      case 'powered_by':
        badgeColor = const Color(0xFF8B5CF6);
        tierLabel = 'POWERED BY';
        break;
      default:
        badgeColor = AppColors.primary;
        tierLabel = 'PARTNER';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surfaceBlueTile,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                sponsor.logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_rounded, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sponsor.name,
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tierLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sponsor.websiteUrl != null && sponsor.websiteUrl!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sponsor.websiteUrl!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.secondary, size: 22),
            tooltip: 'Delete Sponsor',
            onPressed: () => _confirmDeleteSponsor(sponsor),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSponsor(SponsorModel sponsor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text('Delete Sponsor?', style: AppTextStyles.h4),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${sponsor.name}" from official home page sponsors?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TacticalButton(
            label: 'Delete',
            variant: TacticalButtonVariant.danger,
            isFullWidth: false,
            height: 38,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tournamentRepoProvider);
                await repo.deleteSponsor(sponsor.id);
                ref.invalidate(sponsorsProvider);
                if (mounted) {
                  UiHelpers.showSuccessBanner(context, 'Sponsor "${sponsor.name}" deleted successfully.');
                }
              } catch (e) {
                if (mounted) {
                  UiHelpers.showErrorBanner(context, 'Failed to delete: ${e.toString()}');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddSponsorDialog() {
    final nameController = TextEditingController();
    final logoController = TextEditingController(text: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=200&q=80');
    final websiteController = TextEditingController(text: 'https://');
    String selectedTier = 'partner';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handshake_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Register New Sponsor', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TacticalTextField(
                  label: 'Sponsor Name',
                  hint: 'e.g. Red Bull Esports',
                  controller: nameController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'Logo Image URL',
                  hint: 'https://...',
                  controller: logoController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'Official Website / Link',
                  hint: 'https://...',
                  controller: websiteController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Tier: ', style: AppTextStyles.inputLabel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTier,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'title_sponsor', child: Text('Title Sponsor')),
                              DropdownMenuItem(value: 'powered_by', child: Text('Powered By')),
                              DropdownMenuItem(value: 'partner', child: Text('Partner')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedTier = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: 'Save Sponsor',
              isLoading: isSaving,
              isFullWidth: false,
              height: 40,
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  UiHelpers.showErrorBanner(context, 'Sponsor name is required.');
                  return;
                }
                setDialogState(() => isSaving = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  await repo.addNewSponsor(
                    name: nameController.text.trim(),
                    logoUrl: logoController.text.trim(),
                    websiteUrl: websiteController.text.trim(),
                    tier: selectedTier,
                  );
                  ref.invalidate(sponsorsProvider);
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                  if (mounted) {
                    UiHelpers.showSuccessBanner(context, 'Sponsor added to home page successfully.');
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) {
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

  // =========================================================================
  // --- SECTION 8: APP RELEASES & OTA UPDATER ---
  // =========================================================================

  Widget _buildAppReleasesSection() {
    final hasRemote = _currentRemoteUpdateInfo != null;
    final publishedAt = _currentRemoteUpdateInfo?.publishedAt;
    final dateStr = publishedAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(publishedAt.toLocal()) : 'Never';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IN-APP AUTO UPDATER & RELEASES',
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.primaryDark,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      'Push Updates to All Players',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: _isLoadingAppRelease
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.refresh_rounded, color: AppColors.primary),
                tooltip: 'Refresh Release Info',
                onPressed: _loadCurrentReleaseInfo,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceBlueTile,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: AppColors.success, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'CURRENT LIVE DEPLOYMENT',
                        style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 10),
                      ),
                    ],
                  ),
                  if (hasRemote)
                    StatusBadge(
                      label: _currentRemoteUpdateInfo!.isForceUpdate ? 'MANDATORY' : 'OPTIONAL',
                      type: _currentRemoteUpdateInfo!.isForceUpdate ? BadgeType.danger : BadgeType.info,
                    )
                  else
                    const StatusBadge(label: 'NOT CONFIGURED', type: BadgeType.warning),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target Version', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                        Text(
                          hasRemote ? 'v${_currentRemoteUpdateInfo!.latestVersion} (Build ${_currentRemoteUpdateInfo!.buildNumber})' : 'v1.0.0 (Build 1)',
                          style: AppTextStyles.monoCode.copyWith(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Min Supported Build', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                        Text(
                          hasRemote ? 'Build ${_currentRemoteUpdateInfo!.minSupportedBuild}' : 'Build 1',
                          style: AppTextStyles.monoCode.copyWith(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Published on: $dateStr',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 10.5, color: AppColors.textTertiary),
              ),
              if (hasRemote && _currentRemoteUpdateInfo!.apkUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _currentRemoteUpdateInfo!.apkUrl,
                          style: AppTextStyles.monoCode.copyWith(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                        tooltip: 'Copy Link',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _currentRemoteUpdateInfo!.apkUrl));
                          UiHelpers.showSuccessBanner(context, 'APK Link copied to clipboard.');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.publish_rounded, color: AppColors.primaryDark, size: 20),
                  const SizedBox(width: 8),
                  Text('PUBLISH NEW APP UPDATE', style: AppTextStyles.h4),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the new version details and APK download link. When published, users will receive a popup immediately.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TacticalTextField(
                      label: 'Latest Version Tag',
                      hint: 'e.g. 1.0.1',
                      controller: _releaseVersionController,
                      prefixIcon: Icons.sell_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TacticalTextField(
                      label: 'Build #',
                      hint: 'e.g. 2',
                      controller: _releaseBuildController,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.tag_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              TacticalTextField(
                label: 'Min Supported Build #',
                hint: '1 (Lower builds will be forced to update)',
                controller: _minBuildController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.security_update_warning_rounded,
              ),

              const SizedBox(height: 14),

              TacticalTextField(
                label: 'APK / App Download URL',
                hint: 'https://drive.google.com/... or direct APK link',
                controller: _apkUrlController,
                keyboardType: TextInputType.url,
                prefixIcon: Icons.download_rounded,
              ),

              const SizedBox(height: 14),

              TacticalTextField(
                label: 'Release Notes & Changelog',
                hint: '• What is new in this update...',
                controller: _releaseNotesController,
                maxLines: 4,
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _isForceUpdate ? const Color(0xFFFEF2F2) : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isForceUpdate ? AppColors.secondary.withValues(alpha: 0.4) : AppColors.border,
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Mandatory / Force Update',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _isForceUpdate ? AppColors.secondary : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _isForceUpdate
                        ? 'Users CANNOT dismiss or close the dialog until they update the app.'
                        : 'Optional update: users can dismiss and play normally.',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                  value: _isForceUpdate,
                  activeThumbColor: AppColors.secondary,
                  onChanged: (val) => setState(() => _isForceUpdate = val),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TacticalButton(
                      label: 'Preview Dialog',
                      icon: Icons.visibility_outlined,
                      variant: TacticalButtonVariant.outline,
                      height: 44,
                      onPressed: () {
                        final previewInfo = AppUpdateInfo(
                          latestVersion: _releaseVersionController.text.trim().isEmpty ? '1.0.1' : _releaseVersionController.text.trim(),
                          buildNumber: int.tryParse(_releaseBuildController.text.trim()) ?? 2,
                          minSupportedBuild: int.tryParse(_minBuildController.text.trim()) ?? 1,
                          apkUrl: _apkUrlController.text.trim().isEmpty ? 'https://example.com/app.apk' : _apkUrlController.text.trim(),
                          updateNotes: _releaseNotesController.text.trim(),
                          isForceUpdate: _isForceUpdate,
                          publishedAt: DateTime.now(),
                        );
                        showDialog(
                          context: context,
                          barrierDismissible: !_isForceUpdate,
                          builder: (_) => AppUpdateDialog(
                            updateInfo: previewInfo,
                            installedVersion: '1.0.0',
                            installedBuildNumber: 1,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TacticalButton(
                      label: _isPublishingAppRelease ? 'Publishing...' : '🚀 Publish Release',
                      icon: Icons.send_rounded,
                      height: 44,
                      onPressed: _isPublishingAppRelease ? null : _handlePublishAppRelease,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _handlePublishAppRelease() async {
    final version = _releaseVersionController.text.trim();
    final buildNumber = int.tryParse(_releaseBuildController.text.trim()) ?? 1;
    final minBuild = int.tryParse(_minBuildController.text.trim()) ?? 1;
    final apkUrl = _apkUrlController.text.trim();
    final notes = _releaseNotesController.text.trim();

    if (version.isEmpty) {
      UiHelpers.showErrorBanner(context, 'Please enter a valid version tag (e.g. 1.0.1)');
      return;
    }

    if (apkUrl.isEmpty) {
      UiHelpers.showErrorBanner(context, 'Please enter a valid APK / App download URL');
      return;
    }

    setState(() => _isPublishingAppRelease = true);
    try {
      final updateInfo = AppUpdateInfo(
        latestVersion: version,
        buildNumber: buildNumber,
        minSupportedBuild: minBuild,
        apkUrl: apkUrl,
        updateNotes: notes,
        isForceUpdate: _isForceUpdate,
        publishedAt: DateTime.now(),
      );

      await AppUpdateService.publishNewVersion(updateInfo);
      if (mounted) {
        UiHelpers.showSuccessBanner(context, '🚀 Version v$version published! Players will now get update prompts.');
        await _loadCurrentReleaseInfo();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorBanner(context, 'Publish failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isPublishingAppRelease = false);
    }
  }
}
