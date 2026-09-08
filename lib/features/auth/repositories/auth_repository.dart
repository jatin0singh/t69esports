import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../models/user_profile.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isEmailConfirmed => currentUser?.emailConfirmedAt != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign Up with Email, Password & Username
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'username': username.trim().toLowerCase(),
          'full_name': fullName?.trim() ?? '',
        },
      );
      return response;
    } on AuthException catch (e) {
      throw _parseAuthException(e);
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Verify Email OTP for Sign Up
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.signup,
      );
      return response;
    } on AuthException catch (e) {
      throw _parseAuthException(e);
    } catch (e) {
      throw Exception('OTP verification failed: ${e.toString()}');
    }
  }

  /// Resend Sign Up Verification Email / OTP
  Future<void> resendSignupOtp(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
    } on AuthException catch (e) {
      throw _parseAuthException(e);
    } catch (e) {
      throw Exception('Failed to resend code: ${e.toString()}');
    }
  }

  /// Sign In with Email & Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw _parseAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign In with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      final success = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 't69esports://login-callback/',
      );
      return success;
    } on AuthException catch (e) {
      throw _parseAuthException(e);
    } catch (e) {
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Send Password Recovery Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 't69esports://reset-callback/',
      );
    } on AuthException catch (e) {
      throw _parseAuthException(e);
    } catch (e) {
      throw Exception('Failed to send password reset: ${e.toString()}');
    }
  }

  /// Verify Password Reset OTP (6-Digit Code) and Update to New Password
  Future<void> verifyPasswordResetOtpAndSetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final res = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );

      if (res.session == null) {
        throw Exception('Invalid or expired verification code.');
      }

      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw _parseAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  /// Fetch user profile from Supabase
  Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        // If trigger didn't catch it yet, fallback to creating profile
        final fallbackProfile = UserProfile(
          id: user.id,
          username: user.userMetadata?['username'] ?? user.email?.split('@').first ?? 'Gamer',
          fullName: user.userMetadata?['full_name'],
          isOnboarded: false,
        );
        await _client.from('profiles').insert(fallbackProfile.toJson());
        return fallbackProfile;
      }

      return UserProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch profile: ${e.toString()}');
    }
  }

  /// Update Gamer Profile details
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      final response = await _client
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  /// Complete First-time Gamer Onboarding
  Future<UserProfile> completeOnboarding({
    required String gameIgn,
    required String gameUid,
    required String primaryGame,
    String? discordTag,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated session.');

    try {
      final updates = {
        'game_ign': gameIgn.trim(),
        'game_uid': gameUid.trim(),
        'primary_game': primaryGame,
        'discord_tag': discordTag?.trim(),
        'avatar_url': avatarUrl,
        'is_onboarded': true,
      };

      final response = await _client
          .from('profiles')
          .update(updates)
          .eq('id', user.id)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to complete onboarding: ${e.toString()}');
    }
  }

  /// Translate Supabase auth error messages into user-friendly tactical explanations
  String _parseAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'Invalid email or password. Please verify your credentials.';
    } else if (msg.contains('user already registered') || msg.contains('already registered')) {
      return 'An account with this email address already exists.';
    } else if (msg.contains('email not confirmed')) {
      return 'Email not confirmed. Please check your inbox for verification.';
    } else if (msg.contains('rate limit')) {
      return 'Security limit exceeded. Please wait a moment before trying again.';
    } else if (msg.contains('password')) {
      return e.message;
    }
    return e.message;
  }
}
