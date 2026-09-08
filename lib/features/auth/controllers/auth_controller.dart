import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<sp.AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AsyncValue.loading()) {
    init();
  }

  Future<void> init() async {
    if (_repo.currentUser == null) {
      state = const AsyncValue.data(null);
      return;
    }
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    try {
      state = const AsyncValue.loading();
      final profile = await _repo.getCurrentProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signIn(email: email, password: password);
      final profile = await _repo.getCurrentProfile();
      state = AsyncValue.data(profile);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final res = await _repo.signUp(
        email: email,
        password: password,
        username: username,
        fullName: fullName,
      );
      if (res.session != null) {
        final profile = await _repo.getCurrentProfile();
        state = AsyncValue.data(profile);
      } else {
        // Confirmation required or session not yet established
        state = const AsyncValue.data(null);
      }
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    state = const AsyncValue.loading();
    try {
      final res = await _repo.verifyEmailOtp(email: email, token: token);
      if (res.session != null) {
        final profile = await _repo.getCurrentProfile();
        state = AsyncValue.data(profile);
        return true;
      }
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> resendSignupOtp(String email) async {
    try {
      await _repo.resendSignupOtp(email);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final res = await _repo.signInWithGoogle();
      return res;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _repo.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> completeOnboarding({
    required String gameIgn,
    required String gameUid,
    required String primaryGame,
    String? discordTag,
    String? avatarUrl,
  }) async {
    try {
      final updated = await _repo.completeOnboarding(
        gameIgn: gameIgn,
        gameUid: gameUid,
        primaryGame: primaryGame,
        discordTag: discordTag,
        avatarUrl: avatarUrl,
      );
      state = AsyncValue.data(updated);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
