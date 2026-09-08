import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class RateLimitResult {
  final bool isAllowed;
  final int remainingAttempts;
  final int totalAllowed;
  final Duration retryAfter;
  final String? customMessage;

  const RateLimitResult({
    required this.isAllowed,
    this.remainingAttempts = 0,
    this.totalAllowed = 0,
    this.retryAfter = Duration.zero,
    this.customMessage,
  });

  int get retryAfterSeconds => retryAfter.inSeconds;

  String get formattedRetryAfter {
    if (retryAfterSeconds <= 0) return '0s';
    final minutes = retryAfter.inMinutes;
    final seconds = retryAfterSeconds % 60;
    if (minutes > 0) {
      return '$minutes min ${seconds > 0 ? '$seconds s' : ''}'.trim();
    }
    return '${seconds}s';
  }

  String get formattedTimer {
    final minutes = retryAfter.inMinutes;
    final seconds = retryAfterSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class RateLimiterService {
  static final RateLimiterService _instance = RateLimiterService._internal();
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  // In-memory timestamps map: actionKey -> List of DateTime attempt timestamps
  final Map<String, List<DateTime>> _attemptHistory = {};
  
  // In-memory lockout map: actionKey -> DateTime lockoutUntil
  final Map<String, DateTime> _lockouts = {};

  // Prefix for SharedPreferences keys
  static const String _prefPrefix = 't69_rl_';

  /// Format an action key with a user identifier (e.g. email, user ID, or IP/device)
  static String formatKey(String action, String identifier) {
    final cleanId = identifier.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_@.]'), '_');
    return '$action:$cleanId';
  }

  // ==========================================
  // 1. PRESET: AUTH - LOGIN RATE LIMIT
  // Max 5 failed attempts in 15 minutes -> 10-minute lockout
  // ==========================================
  static Future<RateLimitResult> checkLogin(String email) async {
    final key = formatKey('login', email);
    return _instance._checkLimit(
      key: key,
      maxAttempts: 5,
      window: const Duration(minutes: 15),
      lockoutDuration: const Duration(minutes: 10),
      actionName: 'login',
    );
  }

  static Future<void> recordFailedLogin(String email) async {
    final key = formatKey('login', email);
    await _instance._recordAttempt(
      key: key,
      maxAttempts: 5,
      window: const Duration(minutes: 15),
      lockoutDuration: const Duration(minutes: 10),
    );
  }

  static Future<void> resetLogin(String email) async {
    final key = formatKey('login', email);
    await _instance._reset(key);
  }

  // ==========================================
  // 2. PRESET: AUTH - RESET PASSWORD / OTP SEND RATE LIMIT
  // 60-second cooldown between requests, max 3 requests in 15 minutes
  // ==========================================
  static Future<RateLimitResult> checkPasswordResetEmail(String email) async {
    final key = formatKey('reset_email_send', email);
    return _instance._checkLimit(
      key: key,
      maxAttempts: 3,
      window: const Duration(minutes: 15),
      cooldown: const Duration(seconds: 60),
      lockoutDuration: const Duration(minutes: 15),
      actionName: 'request recovery code',
    );
  }

  static Future<void> recordPasswordResetEmail(String email) async {
    final key = formatKey('reset_email_send', email);
    await _instance._recordAttempt(
      key: key,
      maxAttempts: 3,
      window: const Duration(minutes: 15),
      cooldown: const Duration(seconds: 60),
      lockoutDuration: const Duration(minutes: 15),
    );
  }

  // ==========================================
  // 3. PRESET: AUTH - RESET PASSWORD OTP VERIFY RATE LIMIT
  // Max 5 incorrect OTP attempts in 15 minutes -> 10-minute lockout
  // ==========================================
  static Future<RateLimitResult> checkPasswordResetVerify(String email) async {
    final key = formatKey('reset_otp_verify', email);
    return _instance._checkLimit(
      key: key,
      maxAttempts: 5,
      window: const Duration(minutes: 15),
      lockoutDuration: const Duration(minutes: 10),
      actionName: 'OTP verification',
    );
  }

  static Future<void> recordFailedPasswordResetVerify(String email) async {
    final key = formatKey('reset_otp_verify', email);
    await _instance._recordAttempt(
      key: key,
      maxAttempts: 5,
      window: const Duration(minutes: 15),
      lockoutDuration: const Duration(minutes: 10),
    );
  }

  static Future<void> resetPasswordResetVerify(String email) async {
    final key = formatKey('reset_otp_verify', email);
    await _instance._reset(key);
  }

  // ==========================================
  // 4. PRESET: AUTH - REGISTER ACCOUNT RATE LIMIT
  // Max 3 registration attempts in 10 minutes
  // ==========================================
  static Future<RateLimitResult> checkRegister(String email) async {
    final key = formatKey('register', email.isEmpty ? 'global' : email);
    return _instance._checkLimit(
      key: key,
      maxAttempts: 3,
      window: const Duration(minutes: 10),
      lockoutDuration: const Duration(minutes: 10),
      actionName: 'account registration',
    );
  }

  static Future<void> recordRegisterAttempt(String email) async {
    final key = formatKey('register', email.isEmpty ? 'global' : email);
    await _instance._recordAttempt(
      key: key,
      maxAttempts: 3,
      window: const Duration(minutes: 10),
      lockoutDuration: const Duration(minutes: 10),
    );
  }

  // ==========================================
  // 5. PRESET: WALLET - DEPOSIT UTR SUBMISSION RATE LIMIT
  // Max 3 UTR verification submissions in 5 minutes (stops fake UTR guessing)
  // ==========================================
  static Future<RateLimitResult> checkDepositUtr(String userIdOrUtr) async {
    final key = formatKey('wallet_utr', userIdOrUtr);
    return _instance._checkLimit(
      key: key,
      maxAttempts: 3,
      window: const Duration(minutes: 5),
      lockoutDuration: const Duration(minutes: 5),
      actionName: 'deposit UTR submission',
    );
  }

  static Future<void> recordDepositUtrAttempt(String userIdOrUtr) async {
    final key = formatKey('wallet_utr', userIdOrUtr);
    await _instance._recordAttempt(
      key: key,
      maxAttempts: 3,
      window: const Duration(minutes: 5),
      lockoutDuration: const Duration(minutes: 5),
    );
  }

  // ==========================================
  // 6. PRESET: WALLET - WITHDRAWAL RATE LIMIT
  // 1 withdrawal request per 2 minutes (stops double-tap/duplicate requests)
  // ==========================================
  static Future<RateLimitResult> checkWithdrawal(String userId) async {
    final key = formatKey('wallet_withdraw', userId);
    return _instance._checkLimit(
      key: key,
      maxAttempts: 1,
      window: const Duration(minutes: 2),
      cooldown: const Duration(minutes: 2),
      lockoutDuration: const Duration(minutes: 2),
      actionName: 'cash withdrawal',
    );
  }

  static Future<void> recordWithdrawalAttempt(String userId) async {
    final key = formatKey('wallet_withdraw', userId);
    await _instance._recordAttempt(
      key: key,
      maxAttempts: 1,
      window: const Duration(minutes: 2),
      cooldown: const Duration(minutes: 2),
      lockoutDuration: const Duration(minutes: 2),
    );
  }

  // ==========================================
  // 7. PRESET: TOURNAMENT - PROOF UPLOAD RATE LIMIT
  // 1 screenshot proof upload per 30 seconds
  // ==========================================
  static Future<RateLimitResult> checkProofUpload(String userId) async {
    final key = formatKey('proof_upload', userId);
    return _instance._checkLimit(
      key: key,
      maxAttempts: 1,
      window: const Duration(seconds: 30),
      cooldown: const Duration(seconds: 30),
      actionName: 'screenshot proof upload',
    );
  }

  static Future<void> recordProofUploadAttempt(String userId) async {
    final key = formatKey('proof_upload', userId);
    await _instance._recordAttempt(
      key: key,
      maxAttempts: 1,
      window: const Duration(seconds: 30),
      cooldown: const Duration(seconds: 30),
    );
  }

  // ==========================================
  // INTERNAL RATE LIMIT ENGINE
  // ==========================================
  Future<RateLimitResult> _checkLimit({
    required String key,
    required int maxAttempts,
    required Duration window,
    Duration? cooldown,
    Duration? lockoutDuration,
    required String actionName,
  }) async {
    final now = DateTime.now();

    // 1. Check active lockout in memory or persistent storage
    final lockoutUntil = await _getLockoutUntil(key);
    if (lockoutUntil != null && lockoutUntil.isAfter(now)) {
      final remaining = lockoutUntil.difference(now);
      return RateLimitResult(
        isAllowed: false,
        remainingAttempts: 0,
        totalAllowed: maxAttempts,
        retryAfter: remaining,
        customMessage: 'Too many attempts for $actionName. Security lockout active for ${remaining.inMinutes > 0 ? '${remaining.inMinutes}m ${remaining.inSeconds % 60}s' : '${remaining.inSeconds}s'}.',
      );
    }

    // 2. Check per-action cooldown (e.g. 60s OTP resend timer)
    final history = _getCleanHistory(key, window);
    if (cooldown != null && history.isNotEmpty) {
      final lastAttempt = history.last;
      final timeSinceLast = now.difference(lastAttempt);
      if (timeSinceLast < cooldown) {
        final remainingCooldown = cooldown - timeSinceLast;
        return RateLimitResult(
          isAllowed: false,
          remainingAttempts: (maxAttempts - history.length).clamp(0, maxAttempts),
          totalAllowed: maxAttempts,
          retryAfter: remainingCooldown,
          customMessage: 'Please wait ${remainingCooldown.inSeconds}s before requesting another $actionName.',
        );
      }
    }

    // 3. Check sliding window attempt count
    if (history.length >= maxAttempts) {
      final oldestAttempt = history.first;
      final windowRemaining = window - now.difference(oldestAttempt);
      final waitDuration = lockoutDuration ?? (windowRemaining.isNegative ? Duration.zero : windowRemaining);

      // Lock out if lockout duration specified
      if (lockoutDuration != null) {
        await _setLockout(key, now.add(lockoutDuration));
      }

      return RateLimitResult(
        isAllowed: false,
        remainingAttempts: 0,
        totalAllowed: maxAttempts,
        retryAfter: waitDuration,
        customMessage: 'Rate limit exceeded ($maxAttempts attempts in ${window.inMinutes} mins). Please wait ${waitDuration.inMinutes > 0 ? '${waitDuration.inMinutes}m ${waitDuration.inSeconds % 60}s' : '${waitDuration.inSeconds}s'}.',
      );
    }

    // Allowed!
    return RateLimitResult(
      isAllowed: true,
      remainingAttempts: maxAttempts - history.length,
      totalAllowed: maxAttempts,
      retryAfter: Duration.zero,
    );
  }

  Future<void> _recordAttempt({
    required String key,
    required int maxAttempts,
    required Duration window,
    Duration? cooldown,
    Duration? lockoutDuration,
  }) async {
    final now = DateTime.now();
    final history = _getCleanHistory(key, window);
    history.add(now);
    _attemptHistory[key] = history;

    // If reached maxAttempts, trigger lockout
    if (history.length >= maxAttempts && lockoutDuration != null) {
      await _setLockout(key, now.add(lockoutDuration));
    }
  }

  Future<void> _reset(String key) async {
    _attemptHistory.remove(key);
    _lockouts.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefPrefix$key');
    } catch (_) {}
  }

  List<DateTime> _getCleanHistory(String key, Duration window) {
    final now = DateTime.now();
    final list = _attemptHistory[key] ?? [];
    final cleaned = list.where((t) => now.difference(t) <= window).toList();
    _attemptHistory[key] = cleaned;
    return cleaned;
  }

  Future<DateTime?> _getLockoutUntil(String key) async {
    // Check in-memory first
    if (_lockouts.containsKey(key)) {
      final inMem = _lockouts[key]!;
      if (inMem.isAfter(DateTime.now())) return inMem;
      _lockouts.remove(key);
    }

    // Check SharedPreferences for persistent lockout
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedEpoch = prefs.getInt('$_prefPrefix$key');
      if (storedEpoch != null) {
        final storedDate = DateTime.fromMillisecondsSinceEpoch(storedEpoch);
        if (storedDate.isAfter(DateTime.now())) {
          _lockouts[key] = storedDate;
          return storedDate;
        } else {
          await prefs.remove('$_prefPrefix$key');
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _setLockout(String key, DateTime lockoutUntil) async {
    _lockouts[key] = lockoutUntil;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefPrefix$key', lockoutUntil.millisecondsSinceEpoch);
    } catch (_) {}
  }
}
