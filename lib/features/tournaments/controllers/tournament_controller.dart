import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tournament_model.dart';
import '../models/banner_model.dart';
import '../models/sponsor_model.dart';
import '../../wallet/models/wallet_transaction_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../repositories/tournament_repository.dart';

final tournamentRepoProvider = Provider<TournamentRepository>((ref) {
  return TournamentRepository();
});

final bannersProvider = FutureProvider<List<BannerModel>>((ref) async {
  final repo = ref.watch(tournamentRepoProvider);
  return repo.getActiveBanners();
});

final sponsorsProvider = FutureProvider<List<SponsorModel>>((ref) async {
  final repo = ref.watch(tournamentRepoProvider);
  return repo.getActiveSponsors();
});

final tournamentsProvider =
    FutureProvider.family<List<TournamentModel>, String?>((ref, game) async {
  final repo = ref.watch(tournamentRepoProvider);
  return repo.getTournaments(game: game);
});

final freeFireTournamentsProvider = FutureProvider<List<TournamentModel>>((ref) async {
  final repo = ref.watch(tournamentRepoProvider);
  return repo.getFreeFireTournaments();
});

final walletTransactionsProvider =
    FutureProvider<List<WalletTransactionModel>>((ref) async {
  final authUser = ref.watch(authControllerProvider).value;
  if (authUser == null) return [];
  final repo = ref.watch(tournamentRepoProvider);
  return repo.getUserTransactions();
});

final userRegisteredTournamentIdsProvider = FutureProvider<Set<String>>((ref) async {
  final authUser = ref.watch(authControllerProvider).value;
  if (authUser == null) return {};
  final repo = ref.watch(tournamentRepoProvider);
  return repo.getUserRegisteredTournamentIds();
});

final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authUser = ref.watch(authControllerProvider).value;
  if (authUser == null) return {};
  final repo = ref.watch(tournamentRepoProvider);
  return repo.fetchUserStats();
});

final matchHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authUser = ref.watch(authControllerProvider).value;
  final repo = ref.watch(tournamentRepoProvider);
  return repo.fetchCompletedMatchHistory(
    userId: authUser?.id,
    userIgn: authUser?.gameIgn,
  );
});

