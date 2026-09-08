import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/services/rate_limiter_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../tournaments/controllers/tournament_controller.dart';

class PaymentGatewayRoute {
  final String id;
  final String name;
  final String upiId;
  final String payeeName;
  final String? aid;

  const PaymentGatewayRoute({
    required this.id,
    required this.name,
    required this.upiId,
    required this.payeeName,
    this.aid,
  });

  /// Generates the standard NPCI Dynamic UPI payload with exact pre-filled amount
  String buildUpiUrl(double amount) {
    final formattedAmount = amount.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final note = Uri.encodeComponent('T69 Esports Vault Deposit');
    var url = 'upi://pay?pa=$upiId&pn=$encodedName&am=$formattedAmount&cu=INR&tn=$note';
    if (aid != null) {
      url += '&aid=$aid';
    }
    return url;
  }

  String buildPhonePeUrl(double amount) {
    final formattedAmount = amount.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final note = Uri.encodeComponent('T69 Esports Vault Deposit');
    return 'phonepe://pay?pa=$upiId&pn=$encodedName&am=$formattedAmount&cu=INR&tn=$note';
  }

  String buildGPayUrl(double amount) {
    final formattedAmount = amount.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final note = Uri.encodeComponent('T69 Esports Vault Deposit');
    return 'gpay://upi/pay?pa=$upiId&pn=$encodedName&am=$formattedAmount&cu=INR&tn=$note';
  }

  String buildTezUrl(double amount) {
    final formattedAmount = amount.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final note = Uri.encodeComponent('T69 Esports Vault Deposit');
    return 'tez://upi/pay?pa=$upiId&pn=$encodedName&am=$formattedAmount&cu=INR&tn=$note';
  }

  String buildPaytmUrl(double amount) {
    final formattedAmount = amount.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final note = Uri.encodeComponent('T69 Esports Vault Deposit');
    return 'paytmmp://pay?pa=$upiId&pn=$encodedName&am=$formattedAmount&cu=INR&tn=$note';
  }

  String buildPaytmAltUrl(double amount) {
    final formattedAmount = amount.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final note = Uri.encodeComponent('T69 Esports Vault Deposit');
    return 'paytm://pay?pa=$upiId&pn=$encodedName&am=$formattedAmount&cu=INR&tn=$note';
  }
}

class WalletModal extends ConsumerStatefulWidget {
  const WalletModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WalletModal(),
    );
  }

  @override
  ConsumerState<WalletModal> createState() => _WalletModalState();
}

class _WalletModalState extends ConsumerState<WalletModal> {
  // Active Tab: 0 for 'DEPOSIT', 1 for 'WITHDRAW'
  int _activeTab = 0;

  double _selectedAddAmount = 100.0;
  bool _isProcessing = false;
  bool _showQrGatewaySheet = false;

  // Available QR Gateways rotated automatically on a 2-hour schedule
  final List<PaymentGatewayRoute> _gateways = const [
    PaymentGatewayRoute(
      id: 'gateway_1',
      name: 'Google Pay / ICICI Gateway',
      upiId: 't69esports@okaxis',
      payeeName: 'T69 Team',
      aid: 'uGICAgMC-gZK9PA',
    ),
    PaymentGatewayRoute(
      id: 'gateway_2',
      name: 'UPI Express Channel',
      upiId: 't69team@fam',
      payeeName: 'T69 Team',
    ),
  ];

  // Deposit Controllers
  final TextEditingController _amountController = TextEditingController(text: '100');
  final TextEditingController _depositAccountHolderController = TextEditingController();
  final TextEditingController _utrController = TextEditingController();

  // Withdrawal Controllers
  final TextEditingController _withdrawAmountController = TextEditingController(text: '50');
  final TextEditingController _withdrawUpiController = TextEditingController();
  final TextEditingController _withdrawHolderController = TextEditingController();
  final TextEditingController _withdrawBankAccController = TextEditingController();
  final TextEditingController _withdrawIfscController = TextEditingController();

  String _payoutMethod = 'UPI'; // 'UPI' or 'BANK'

  final List<double> _quickAmounts = [15, 20, 25, 50, 100, 200, 500];

  int get _currentGatewayIndex {
    final int twoHourBlock = (DateTime.now().millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 2));
    return twoHourBlock % _gateways.length;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _depositAccountHolderController.dispose();
    _utrController.dispose();

    _withdrawAmountController.dispose();
    _withdrawUpiController.dispose();
    _withdrawHolderController.dispose();
    _withdrawBankAccController.dispose();
    _withdrawIfscController.dispose();
    super.dispose();
  }

  // App Not Found Alert Dialog
  void _showAppNotInstalledDialog(String appName) {
    UiHelpers.vibrateError();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text('$appName Not Found', style: AppTextStyles.h3),
            ),
          ],
        ),
        content: Text(
          '$appName is not installed on this device.\n\nPlease scan the QR code using any UPI app (PhonePe, Google Pay, Paytm, BHIM, Cred) to complete your deposit of ₹${_selectedAddAmount.toStringAsFixed(0)}.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TacticalButton(
            label: 'Got It, I Will Scan QR',
            height: 42,
            isFullWidth: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  // 1-Tap Native UPI App Launcher with candidate schemes and fallback
  Future<void> _launchSpecificUpiApp({
    required String appName,
    List<String>? candidateUrls,
    String? specificSchemeUrl,
    required String genericUpiUrl,
  }) async {
    final urlsToTry = <String>[];
    if (candidateUrls != null && candidateUrls.isNotEmpty) {
      urlsToTry.addAll(candidateUrls);
    } else if (specificSchemeUrl != null) {
      urlsToTry.add(specificSchemeUrl);
    }

    try {
      // 1. Try launching candidates with canLaunchUrl check first
      for (final url in urlsToTry) {
        final uri = Uri.parse(url);
        try {
          if (await canLaunchUrl(uri)) {
            final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (launched) return;
          }
        } catch (_) {}
      }

      // 2. Direct attempt (iOS canLaunchUrl can give false negatives for non-system apps)
      for (final url in urlsToTry) {
        final uri = Uri.parse(url);
        try {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return;
        } catch (_) {}
      }

      // 3. Try generic upi://pay scheme
      final genericUri = Uri.parse(genericUpiUrl);
      try {
        if (await canLaunchUrl(genericUri)) {
          final launched = await launchUrl(genericUri, mode: LaunchMode.externalApplication);
          if (launched) return;
        }
      } catch (_) {}

      try {
        final launched = await launchUrl(genericUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {}

      // 4. Neither worked -> App not installed on device
      if (mounted) {
        _showAppNotInstalledDialog(appName);
      }
    } catch (_) {
      if (mounted) {
        _showAppNotInstalledDialog(appName);
      }
    }
  }

  // Lightweight Amazon / Neo-Fintech Payment Option Tile
  Widget _buildLightweightPaymentOption({
    required String title,
    required String subtitle,
    required Widget leading,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor ?? AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Submit Deposit Proof
  Future<void> _handleConfirmPayment() async {
    final accountHolder = _depositAccountHolderController.text.trim();
    final rawUtr = _utrController.text.trim();
    final cleanUtr = rawUtr.replaceAll(RegExp(r'\D'), '');

    if (accountHolder.isEmpty) {
      UiHelpers.showErrorBanner(context, 'Please enter your UPI Account Holder Name.');
      return;
    }

    if (cleanUtr.length != 12) {
      UiHelpers.showErrorBanner(context, 'Invalid UTR format. Bank UTR must be exactly 12 numeric digits (e.g. 423891029384).');
      return;
    }

    // Rate Limit Check on UTR Submission (max 3 in 5 minutes)
    final profile = ref.read(authControllerProvider).value;
    final rateLimitKey = profile?.id ?? cleanUtr;
    final rlCheck = await RateLimiterService.checkDepositUtr(rateLimitKey);
    if (!rlCheck.isAllowed) {
      UiHelpers.vibrateError();
      if (!mounted) return;
      UiHelpers.showErrorBanner(
        context,
        rlCheck.customMessage ?? 'Too many deposit submissions. Please wait ${rlCheck.formattedRetryAfter}.',
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await RateLimiterService.recordDepositUtrAttempt(rateLimitKey);
      final currentGateway = _gateways[_currentGatewayIndex];
      final repo = ref.read(tournamentRepoProvider);

      await repo.submitDepositRequest(
        amount: _selectedAddAmount,
        utrNumber: cleanUtr,
        accountHolderName: accountHolder,
        gatewayUsed: '${currentGateway.name} (${currentGateway.upiId})',
      );

      ref.invalidate(walletTransactionsProvider);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _showQrGatewaySheet = false;
      });

      _showSubmissionSuccessDialog(context, _selectedAddAmount, cleanUtr, accountHolder);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      UiHelpers.showErrorBanner(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  // 2. Submit Withdrawal Request (Strictly Winning Balance Only)
  Future<void> _handleWithdrawSubmit(double winningBalance, double depositBalance) async {
    final profile = ref.read(authControllerProvider).value;
    final userId = profile?.id ?? 'user';

    // Rate Limit Check on Withdrawal (1 request per 2 minutes)
    final rlCheck = await RateLimiterService.checkWithdrawal(userId);
    if (!rlCheck.isAllowed) {
      UiHelpers.vibrateError();
      if (!mounted) return;
      UiHelpers.showErrorBanner(
        context,
        rlCheck.customMessage ?? 'Please wait ${rlCheck.formattedRetryAfter} before requesting another withdrawal.',
      );
      return;
    }

    if (!mounted) return;
    final amtText = _withdrawAmountController.text.trim();
    final amt = double.tryParse(amtText);

    if (amt == null || amt < 30) {
      UiHelpers.showErrorBanner(context, 'Minimum withdrawal amount is ₹30.');
      return;
    }

    if (amt > winningBalance) {
      UiHelpers.showErrorBanner(
        context,
        'Only winning cash can be withdrawn. Your winning balance is ₹${winningBalance.toStringAsFixed(0)}. Deposit cash (₹${depositBalance.toStringAsFixed(0)}) is reserved for lobby entries.',
      );
      return;
    }

    final holder = _withdrawHolderController.text.trim();
    if (holder.isEmpty) {
      UiHelpers.showErrorBanner(context, 'Please enter the Beneficiary / Account Holder Name.');
      return;
    }

    final upi = _withdrawUpiController.text.trim();
    if (_payoutMethod == 'UPI' && (upi.isEmpty || !upi.contains('@'))) {
      UiHelpers.showErrorBanner(context, 'Please enter a valid UPI ID (e.g. name@okhdfcbank).');
      return;
    }

    if (_payoutMethod == 'BANK') {
      if (_withdrawBankAccController.text.trim().isEmpty || _withdrawIfscController.text.trim().isEmpty) {
        UiHelpers.showErrorBanner(context, 'Please enter your Bank Account Number and IFSC Code.');
        return;
      }
    }

    setState(() => _isProcessing = true);
    try {
      await RateLimiterService.recordWithdrawalAttempt(userId);
      final repo = ref.read(tournamentRepoProvider);
      await repo.submitWithdrawalRequest(
        amount: amt,
        upiId: _payoutMethod == 'UPI' ? upi : _withdrawBankAccController.text.trim(),
        accountHolderName: holder,
        bankAccount: _withdrawBankAccController.text.trim(),
        ifsc: _withdrawIfscController.text.trim(),
        payoutMethod: _payoutMethod,
      );

      await ref.read(authControllerProvider.notifier).refreshProfile();
      ref.invalidate(walletTransactionsProvider);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      _showWithdrawalSuccessDialog(context, amt, _payoutMethod == 'UPI' ? upi : 'Bank Account', holder);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      UiHelpers.showErrorBanner(context, 'Withdrawal failed: ${e.toString()}');
    }
  }

  void _showSubmissionSuccessDialog(BuildContext context, double amount, String utr, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            const SizedBox(width: 10),
            Text('Deposit Submitted!', style: AppTextStyles.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your deposit proof for ₹${amount.toStringAsFixed(0)} has been sent to the Admin for verification.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlueTile,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACCOUNT HOLDER: $name', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('UTR / TXN ID: $utr', style: AppTextStyles.monoCode.copyWith(fontSize: 12, color: AppColors.primaryDark)),
                  const SizedBox(height: 4),
                  Text('STATUS: ⏳ PENDING ADMIN APPROVAL', style: AppTextStyles.badge.copyWith(fontSize: 10, color: AppColors.accentOrange)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TacticalButton(
            label: 'Got It & Close',
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showWithdrawalSuccessDialog(BuildContext context, double amount, String destination, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            const SizedBox(width: 10),
            Text('Winning Payout Submitted!', style: AppTextStyles.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your winning withdrawal of ₹${amount.toStringAsFixed(0)} has been submitted.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlueTile,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BENEFICIARY: $name', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('DESTINATION: $destination', style: AppTextStyles.monoCode.copyWith(fontSize: 12, color: AppColors.primaryDark)),
                  const SizedBox(height: 4),
                  Text('TIMELINE: ⏱️ 15 - 30 Minutes Transfer', style: AppTextStyles.badge.copyWith(fontSize: 10, color: AppColors.primaryDark)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TacticalButton(
            label: 'Got It & Close',
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).value;
    final transactionsState = ref.watch(walletTransactionsProvider);
    final totalBalance = profile?.walletBalance ?? 0.0;
    final depositBalance = profile?.depositBalance ?? 0.0;
    final winningBalance = profile?.winningBalance ?? 0.0;
    final currentGateway = _gateways[_currentGatewayIndex];

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderInput,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      _showQrGatewaySheet
                          ? 'Scan & Pay UPI'
                          : _activeTab == 0
                              ? 'Arena Vault & Deposit'
                              : 'Withdraw Winning Cash',
                      style: AppTextStyles.h3,
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _showQrGatewaySheet ? Icons.arrow_back_rounded : Icons.close_rounded,
                    size: 22,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () {
                    if (_showQrGatewaySheet) {
                      setState(() => _showQrGatewaySheet = false);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),

          // Top Switcher Tabs (Deposit vs Withdraw)
          if (!_showQrGatewaySheet) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeTab = 0),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _activeTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                                color: _activeTab == 0 ? AppColors.primary : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Deposit Funds',
                                style: AppTextStyles.badge.copyWith(
                                  color: _activeTab == 0 ? AppColors.primaryDark : AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeTab = 1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _activeTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events_rounded,
                                size: 18,
                                color: _activeTab == 1 ? AppColors.accentOrange : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Withdraw Winnings',
                                style: AppTextStyles.badge.copyWith(
                                  color: _activeTab == 1 ? AppColors.accentOrange : AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Divider(color: AppColors.border, height: 1),

          Expanded(
            child: _showQrGatewaySheet
                ? _buildQrPaymentView(currentGateway)
                : _activeTab == 0
                    ? _buildDepositOverview(totalBalance, depositBalance, winningBalance, transactionsState)
                    : _buildWithdrawOverview(totalBalance, depositBalance, winningBalance, transactionsState),
          ),
        ],
      ),
    );
  }

  // 1. Vault Overview & Deposit Selector View
  Widget _buildDepositOverview(
    double totalBalance,
    double depositBalance,
    double winningBalance,
    AsyncValue<List<dynamic>> transactionsState,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Balance Card with Breakdown
        _buildBalanceCard(totalBalance, depositBalance, winningBalance),

        const SizedBox(height: 24),

        // Custom Amount Input Section
        Text('Deposit Amount (Enter Any Amount)', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceBlueTile,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Text(
                '₹',
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter amount...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val.trim());
                    if (parsed != null && parsed > 0) {
                      setState(() => _selectedAddAmount = parsed);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Quick Preset Shortcut Pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickAmounts.map((amt) {
            final isSelected = amt == _selectedAddAmount;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedAddAmount = amt;
                  _amountController.text = amt.toStringAsFixed(0);
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '+ ₹${amt.toStringAsFixed(0)}',
                  style: AppTextStyles.monoCode.copyWith(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 22),

        // Amazon / Modern Fintech Lightweight Payment Method Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PAYMENT METHOD', style: AppTextStyles.badge.copyWith(fontSize: 10.5, color: AppColors.textSecondary, letterSpacing: 0.8)),
            Text('Instant 1-Tap Pay', style: AppTextStyles.badge.copyWith(fontSize: 10, color: AppColors.primaryDark)),
          ],
        ),
        const SizedBox(height: 10),

        // 1. PhonePe Tile (Lightweight Amazon-Style)
        _buildLightweightPaymentOption(
          title: 'PhonePe',
          subtitle: 'Instant 1-Tap UPI Launch',
          badge: 'FAST',
          badgeColor: const Color(0xFF5F259F),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF5F259F).withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Text('🟣', style: TextStyle(fontSize: 15)),
            ),
          ),
          onTap: () {
            final parsed = double.tryParse(_amountController.text.trim());
            if (parsed == null || parsed <= 0) {
              UiHelpers.showErrorBanner(context, 'Please enter a valid deposit amount.');
              return;
            }
            setState(() {
              _selectedAddAmount = parsed;
              _showQrGatewaySheet = true;
            });
            final currentGateway = _gateways[_currentGatewayIndex];
            _launchSpecificUpiApp(
              appName: 'PhonePe',
              candidateUrls: [currentGateway.buildPhonePeUrl(parsed)],
              genericUpiUrl: currentGateway.buildUpiUrl(parsed),
            );
          },
        ),

        // 2. Google Pay Tile (Lightweight Amazon-Style)
        _buildLightweightPaymentOption(
          title: 'Google Pay (GPay)',
          subtitle: 'Instant 1-Tap UPI Launch',
          badge: 'POPULAR',
          badgeColor: const Color(0xFF1A73E8),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF5FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Text('🔵', style: TextStyle(fontSize: 15)),
            ),
          ),
          onTap: () {
            final parsed = double.tryParse(_amountController.text.trim());
            if (parsed == null || parsed <= 0) {
              UiHelpers.showErrorBanner(context, 'Please enter a valid deposit amount.');
              return;
            }
            setState(() {
              _selectedAddAmount = parsed;
              _showQrGatewaySheet = true;
            });
            final currentGateway = _gateways[_currentGatewayIndex];
            _launchSpecificUpiApp(
              appName: 'Google Pay',
              candidateUrls: [
                currentGateway.buildGPayUrl(parsed),
                currentGateway.buildTezUrl(parsed),
              ],
              genericUpiUrl: currentGateway.buildUpiUrl(parsed),
            );
          },
        ),

        // 3. Paytm UPI Tile (Lightweight Amazon-Style)
        _buildLightweightPaymentOption(
          title: 'Paytm UPI',
          subtitle: 'Instant 1-Tap UPI Launch',
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF002970).withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 15)),
            ),
          ),
          onTap: () {
            final parsed = double.tryParse(_amountController.text.trim());
            if (parsed == null || parsed <= 0) {
              UiHelpers.showErrorBanner(context, 'Please enter a valid deposit amount.');
              return;
            }
            setState(() {
              _selectedAddAmount = parsed;
              _showQrGatewaySheet = true;
            });
            final currentGateway = _gateways[_currentGatewayIndex];
            _launchSpecificUpiApp(
              appName: 'Paytm',
              candidateUrls: [
                currentGateway.buildPaytmUrl(parsed),
                currentGateway.buildPaytmAltUrl(parsed),
              ],
              genericUpiUrl: currentGateway.buildUpiUrl(parsed),
            );
          },
        ),

        // 4. Dynamic Auto-Amount QR Code Tile
        _buildLightweightPaymentOption(
          title: 'Scan Dynamic QR Code',
          subtitle: 'Pre-filled ₹${_selectedAddAmount.toStringAsFixed(0)} on scan (Any UPI App)',
          badge: 'RECOMMENDED',
          badgeColor: AppColors.primaryDark,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceBlueTile,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.primaryDark),
            ),
          ),
          onTap: () {
            final parsed = double.tryParse(_amountController.text.trim());
            if (parsed == null || parsed <= 0) {
              UiHelpers.showErrorBanner(context, 'Please enter a valid deposit amount.');
              return;
            }
            setState(() {
              _selectedAddAmount = parsed;
              _showQrGatewaySheet = true;
            });
          },
        ),

        const SizedBox(height: 24),

        // Recent Transactions
        _buildRecentTransactions(transactionsState),
      ],
    );
  }

  // 2. Withdrawal Tab View (Strictly Winning Balance Only)
  Widget _buildWithdrawOverview(
    double totalBalance,
    double depositBalance,
    double winningBalance,
    AsyncValue<List<dynamic>> transactionsState,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Balance Card with Breakdown
        _buildBalanceCard(totalBalance, depositBalance, winningBalance),

        const SizedBox(height: 20),

        // Gaming Regulations Notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceBlueTile,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.primaryDark, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WITHDRAWAL POLICY',
                      style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Only verified Winning Cash won from registered tournament victories can be withdrawn. Deposit Cash is reserved for tournament entries.',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Withdrawal Amount Input
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Withdrawal Amount', style: AppTextStyles.sectionTitle),
            TextButton(
              onPressed: () {
                if (winningBalance > 0) {
                  _withdrawAmountController.text = winningBalance.toStringAsFixed(0);
                }
              },
              child: Text(
                'WITHDRAW ALL WINNINGS (₹${winningBalance.toStringAsFixed(0)})',
                style: AppTextStyles.badge.copyWith(color: AppColors.accentOrange, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Row(
            children: [
              Text(
                '₹',
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _withdrawAmountController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Max ₹${winningBalance.toStringAsFixed(0)}...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quick Preset Shortcut Pills for Withdrawals
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [30.0, 50.0, 100.0, 200.0, winningBalance].where((amt) => amt > 0 && amt <= winningBalance).toSet().map((amt) {
            return InkWell(
              onTap: () {
                _withdrawAmountController.text = amt.toStringAsFixed(0);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: Text(
                  amt == winningBalance ? 'All (₹${amt.toStringAsFixed(0)})' : '₹${amt.toStringAsFixed(0)}',
                  style: AppTextStyles.monoCode.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Payout Method Selector (UPI vs Bank)
        Text('Transfer Destination', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _payoutMethod = 'UPI'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _payoutMethod == 'UPI' ? AppColors.surfaceBlueTile : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _payoutMethod == 'UPI' ? AppColors.primary : AppColors.border,
                      width: _payoutMethod == 'UPI' ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 20, color: _payoutMethod == 'UPI' ? AppColors.primaryDark : AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('UPI ID (Instant)', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _payoutMethod = 'BANK'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _payoutMethod == 'BANK' ? AppColors.surfaceBlueTile : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _payoutMethod == 'BANK' ? AppColors.primary : AppColors.border,
                      width: _payoutMethod == 'BANK' ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_rounded, size: 20, color: _payoutMethod == 'BANK' ? AppColors.primaryDark : AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('Bank Account', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Beneficiary Account Holder Name
        TacticalTextField(
          label: 'Account Holder / Beneficiary Name *',
          controller: _withdrawHolderController,
          hint: 'e.g. Rahul Sharma',
        ),

        const SizedBox(height: 12),

        if (_payoutMethod == 'UPI') ...[
          TacticalTextField(
            label: 'Your UPI ID / VPA *',
            controller: _withdrawUpiController,
            hint: 'e.g. username@okhdfcbank or 9876543210@paytm',
          ),
        ] else ...[
          TacticalTextField(
            label: 'Bank Account Number *',
            controller: _withdrawBankAccController,
            hint: 'e.g. 50100293819283',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TacticalTextField(
            label: 'Bank IFSC Code *',
            controller: _withdrawIfscController,
            hint: 'e.g. HDFC0001234',
          ),
        ],

        const SizedBox(height: 24),

        TacticalButton(
          label: _isProcessing
              ? 'Processing Winning Payout...'
              : winningBalance >= 30
                  ? 'Withdraw Winnings (₹${winningBalance.toStringAsFixed(0)} Max)'
                  : 'Zero Winning Balance (Earn via Lobbies)',
          isLoading: _isProcessing,
          variant: winningBalance >= 30 ? TacticalButtonVariant.primary : TacticalButtonVariant.secondary,
          onPressed: winningBalance >= 30 ? () => _handleWithdrawSubmit(winningBalance, depositBalance) : null,
        ),

        const SizedBox(height: 28),

        // Recent Transactions
        _buildRecentTransactions(transactionsState),
      ],
    );
  }

  // 3. Reusable Balance Card with Deposit vs Winning Breakdown
  Widget _buildBalanceCard(double totalBalance, double depositBalance, double winningBalance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00A3E0), Color(0xFF0288D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL ARENA VAULT',
                style: AppTextStyles.badge.copyWith(color: Colors.white70, fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'INSTANT SETTLEMENT',
                  style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${totalBalance.toStringAsFixed(2)}',
            style: AppTextStyles.h1.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 14),

          // Two Sub-cards: Deposit Cash vs Winning Cash
          Row(
            children: [
              // 1. Deposit Cash
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.add_card_rounded, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('DEPOSIT CASH', style: AppTextStyles.badge.copyWith(color: Colors.white70, fontSize: 9)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${depositBalance.toStringAsFixed(0)}',
                        style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      Text('For Joining Lobbies', style: AppTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 9)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 2. Winning Cash
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, size: 14, color: Color(0xFFFFE082)),
                          const SizedBox(width: 4),
                          Text('WINNING CASH', style: AppTextStyles.badge.copyWith(color: Color(0xFFFFE082), fontSize: 9)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${winningBalance.toStringAsFixed(0)}',
                        style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      Text('✅ WITHDRAWABLE', style: AppTextStyles.badge.copyWith(color: Color(0xFFFFE082), fontSize: 8.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Dynamic Auto-Amount UPI QR View & 1-Tap App Pay
  Widget _buildQrPaymentView(PaymentGatewayRoute gateway) {
    final upiPayload = gateway.buildUpiUrl(_selectedAddAmount);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Verified Merchant Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceBlueTile,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AUTO-AMOUNT PRE-FILLED ON SCAN',
                style: AppTextStyles.badge.copyWith(
                  fontSize: 10.5,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Amount to Pay Display
        Center(
          child: Column(
            children: [
              Text('EXACT AMOUNT TO PAY', style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                '₹${_selectedAddAmount.toStringAsFixed(0)}',
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 1-Tap Direct UPI App Payment Bar (Lightweight & Clean)
        Text('⚡ 1-Tap Direct App Pay (No Screenshot Needed):', style: AppTextStyles.sectionTitle.copyWith(fontSize: 12)),
        const SizedBox(height: 8),

        Row(
          children: [
            // PhonePe Button
            Expanded(
              child: InkWell(
                onTap: () => _launchSpecificUpiApp(
                  appName: 'PhonePe',
                  candidateUrls: [gateway.buildPhonePeUrl(_selectedAddAmount)],
                  genericUpiUrl: upiPayload,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF5F259F).withValues(alpha: 0.3), width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5F259F).withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🟣', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          'PhonePe',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: const Color(0xFF5F259F),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Google Pay Button
            Expanded(
              child: InkWell(
                onTap: () => _launchSpecificUpiApp(
                  appName: 'Google Pay',
                  candidateUrls: [
                    gateway.buildGPayUrl(_selectedAddAmount),
                    gateway.buildTezUrl(_selectedAddAmount),
                  ],
                  genericUpiUrl: upiPayload,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3), width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A73E8).withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔵', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          'GPay',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: const Color(0xFF1A73E8),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Paytm Button
            Expanded(
              child: InkWell(
                onTap: () => _launchSpecificUpiApp(
                  appName: 'Paytm',
                  candidateUrls: [
                    gateway.buildPaytmUrl(_selectedAddAmount),
                    gateway.buildPaytmAltUrl(_selectedAddAmount),
                  ],
                  genericUpiUrl: upiPayload,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF002970).withValues(alpha: 0.3), width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF002970).withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          'Paytm',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: const Color(0xFF002970),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Centered Dynamic UPI QR Code with embedded exact amount
        Center(
          child: Column(
            children: [
              Text('OR SCAN QR CODE', style: AppTextStyles.badge.copyWith(color: AppColors.textTertiary, fontSize: 10)),
              const SizedBox(height: 8),
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: upiPayload,
                  version: QrVersions.auto,
                  size: 196.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F172A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Step 2: Confirmation Proof Form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('Anti-Fraud Proof Submission', style: AppTextStyles.h4),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the 12-digit Bank UTR / UPI Ref ID from your payment receipt to verify and credit your vault.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // 1. Account Holder Name (Sender Name)
              TacticalTextField(
                label: 'Account Holder Name / Sender Name *',
                controller: _depositAccountHolderController,
                hint: 'e.g. Rahul Sharma',
              ),

              const SizedBox(height: 12),

              // 2. 12-Digit UPI UTR / Transaction ID with Paste Button
              TacticalTextField(
                label: '12-Digit Bank UTR / Ref ID *',
                controller: _utrController,
                hint: 'e.g. 423891029384 (12 digits)',
                keyboardType: TextInputType.number,
                suffix: IconButton(
                  icon: const Icon(Icons.content_paste_rounded, size: 20, color: AppColors.primaryDark),
                  tooltip: 'Paste UTR',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      final clean = data!.text!.replaceAll(RegExp(r'\D'), '');
                      if (clean.isNotEmpty) {
                        _utrController.text = clean.length > 12 ? clean.substring(0, 12) : clean;
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        TacticalButton(
          label: _isProcessing ? 'Verifying & Submitting...' : 'Submit Payment Proof (₹${_selectedAddAmount.toStringAsFixed(0)})',
          isLoading: _isProcessing,
          onPressed: _handleConfirmPayment,
        ),

        const SizedBox(height: 12),

        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
            label: Text('Change Amount', style: AppTextStyles.bodySmall),
            onPressed: () => setState(() => _showQrGatewaySheet = false),
          ),
        ),
      ],
    );
  }

  // 5. Reusable Recent Transactions List
  Widget _buildRecentTransactions(AsyncValue<List<dynamic>> transactionsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Vault Activity', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 12),
        transactionsState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          ),
          error: (_, _) => Center(
            child: Text('Could not load logs.', style: AppTextStyles.bodySmall),
          ),
          data: (txs) {
            if (txs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No wallet transactions recorded yet.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              );
            }

            return Column(
              children: txs.map((tx) {
                final isCredit = tx.type == 'deposit' || tx.type == 'prize_credit';
                final isWithdrawal = tx.type == 'withdrawal';
                final isPending = tx.status == 'pending';
                final isRejected = tx.status == 'rejected';
                final dateStr = DateFormat('dd MMM, hh:mm a').format(tx.createdAt);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isPending
                            ? AppColors.accentOrange.withValues(alpha: 0.15)
                            : isRejected
                                ? AppColors.secondary.withValues(alpha: 0.15)
                                : isCredit
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : AppColors.secondary.withValues(alpha: 0.15),
                        child: Icon(
                          isPending
                              ? Icons.hourglass_top_rounded
                              : isWithdrawal
                                  ? Icons.outbox_rounded
                                  : isCredit
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                          size: 18,
                          color: isPending
                              ? AppColors.accentOrange
                              : isRejected
                                  ? AppColors.secondary
                                  : isCredit
                                      ? AppColors.success
                                      : AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.description ?? (isWithdrawal ? 'Winning Payout' : isCredit ? 'Vault Deposit' : 'Match Entry'),
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Row(
                              children: [
                                Text(dateStr, style: AppTextStyles.bodySmall),
                                if (isPending) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'PROCESSING',
                                      style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.accentOrange),
                                    ),
                                  ),
                                ] else if (isRejected) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE4E6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'REFUNDED',
                                      style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.secondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isCredit ? "+" : "-"}₹${tx.amount.toStringAsFixed(0)}',
                        style: AppTextStyles.monoCode.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isPending
                              ? AppColors.accentOrange
                              : isRejected
                                  ? AppColors.textTertiary
                                  : isCredit
                                      ? AppColors.success
                                      : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
