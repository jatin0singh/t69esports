import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../models/tournament_model.dart';
import '../models/banner_model.dart';
import '../models/sponsor_model.dart';
import '../utils/lobby_schedule_helper.dart';
import '../../wallet/models/wallet_transaction_model.dart';

class TournamentRepository {
  final SupabaseClient _client;

  TournamentRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  Future<List<BannerModel>> getActiveBanners() async {
    try {
      final response = await _client
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('order_index', ascending: true);

      return (response as List).map((json) => BannerModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SponsorModel>> getActiveSponsors() async {
    try {
      final response = await _client
          .from('sponsors')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true);

      return (response as List).map((json) => SponsorModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static const List<Map<String, dynamic>> _masterCategories = [
    {
      'title_prefix': 'FF Solo Rush',
      'format': 'Solo BR',
      'entry_fee': 15.0,
      'prize_pool': 720.0,
      'per_kill': 9.0,
      'map_name': 'Bermuda',
      'max_slots': 48,
      'banner_url': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
    },
    {
      'title_prefix': 'FF Solo Apex',
      'format': 'Solo BR',
      'entry_fee': 20.0,
      'prize_pool': 960.0,
      'per_kill': 12.0,
      'map_name': 'Bermuda',
      'max_slots': 48,
      'banner_url': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
    },
    {
      'title_prefix': 'FF Duo Rush',
      'format': 'Duo BR',
      'entry_fee': 20.0,
      'prize_pool': 960.0,
      'per_kill': 12.0,
      'map_name': 'Bermuda',
      'max_slots': 48,
      'banner_url': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
    },
    {
      'title_prefix': 'FF Squad Mayhem',
      'format': 'Squad BR',
      'entry_fee': 25.0,
      'prize_pool': 1200.0,
      'per_kill': 15.0,
      'map_name': 'Bermuda',
      'max_slots': 48,
      'banner_url': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
    },
    {
      'title_prefix': 'FF Clash Squad 1v1',
      'format': 'CS 1v1',
      'entry_fee': 20.0,
      'prize_pool': 35.0,
      'per_kill': 0.0,
      'map_name': 'Bermuda',
      'max_slots': 2,
      'banner_url': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title_prefix': 'FF Clash Squad 2v2',
      'format': 'CS 2v2',
      'entry_fee': 20.0,
      'prize_pool': 70.0,
      'per_kill': 0.0,
      'map_name': 'Bermuda CS',
      'max_slots': 4,
      'banner_url': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=600&q=80',
    },
    {
      'title_prefix': 'FF Clash Squad 4v4',
      'format': 'CS 4v4',
      'entry_fee': 20.0,
      'prize_pool': 140.0,
      'per_kill': 0.0,
      'map_name': 'Bermuda CS',
      'max_slots': 8,
      'banner_url': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=600&q=80',
    },
  ];

  Future<List<TournamentModel>> getTournaments({String? game}) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      );
      if (!hasConnection || connectivityResult.every((r) => r == ConnectivityResult.none)) {
        throw Exception('No internet connection. Please check your network.');
      }
    } catch (e) {
      if (e.toString().contains('No internet')) rethrow;
    }

    try {
      var query = _client.from('tournaments').select().neq('game', 'SYSTEM');
      if (game != null && game.isNotEmpty) {
        query = query.ilike('game', '%$game%');
      }
      final response = await query.order('start_time', ascending: true).timeout(
            const Duration(milliseconds: 2500),
          );
      final list = (response as List).map((json) => TournamentModel.fromJson(json)).toList();
      _syncAndRollUnbookedTournaments(list);
      _ensureStandbyLobbiesExist(list);

      final activeSlot = LobbyScheduleHelper.getActiveMatchSlot();
      return list.map((t) {
        if (t.status.toLowerCase() == 'open' && t.filledSlots == 0) {
          if (t.startTime.isBefore(activeSlot)) {
            return t.copyWith(startTime: activeSlot);
          }
        }
        return t;
      }).toList();
    } catch (e) {
      throw Exception('Network error fetching tournaments: ${e.toString()}');
    }
  }

  /// Automatically rolls unbooked open tournaments forward to the active match slot in Supabase
  void _syncAndRollUnbookedTournaments(List<TournamentModel> tournaments) {
    final activeSlot = LobbyScheduleHelper.getActiveMatchSlot();
    for (final t in tournaments) {
      if (t.status.toLowerCase() == 'open' && t.filledSlots == 0) {
        if (t.startTime.isBefore(activeSlot)) {
          _client.from('tournaments').update({
            'start_time': activeSlot.toIso8601String(),
            'status': 'open',
          }).eq('id', t.id).catchError((_) {});
        }
      }
    }
  }

  /// Ensures that for every active game category, there is always at least one open/standby lobby.
  /// If all lobbies in a category are full (e.g. Lobby #1, #2, #3 are filled),
  /// it automatically creates Lobby #4, Lobby #5, etc. on-the-fly in Supabase!
  void _ensureStandbyLobbiesExist(List<TournamentModel> tournaments) {
    final activeSlot = LobbyScheduleHelper.getActiveMatchSlot();

    for (final master in _masterCategories) {
      final format = master['format'] as String;
      final entryFee = (master['entry_fee'] as num).toDouble();

      final matching = tournaments.where((t) {
        if (t.game != 'FREE FIRE') return false;
        if (t.format.trim().toLowerCase() != format.trim().toLowerCase()) return false;
        if (t.entryFee.toInt() != entryFee.toInt()) return false;
        return true;
      }).toList();

      // Count open unfilled lobbies
      final availableCount = matching.where((t) {
        if (t.status.toLowerCase() != 'open') return false;
        if (t.filledSlots >= t.maxSlots) return false;
        return true;
      }).length;

      if (availableCount < 1) {
        _spawnNextStandbyLobbyFromTemplate(master, matching, activeSlot);
      }
    }
  }

  Future<void> _spawnNextStandbyLobbyFromTemplate(
    Map<String, dynamic> master,
    List<TournamentModel> categoryList,
    DateTime activeSlot,
  ) async {
    try {
      int maxNum = 0;
      final reg = RegExp(r'Lobby\s*#(\d+)', caseSensitive: false);

      for (final t in categoryList) {
        final match = reg.firstMatch(t.title);
        if (match != null) {
          final numVal = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (numVal > maxNum) maxNum = numVal;
        }
      }

      final nextNum = maxNum + 1;
      final prefix = master['title_prefix'] as String;
      final fee = (master['entry_fee'] as num).toDouble();
      final feeStr = fee > 0 ? ' (Rs ${fee.toInt()})' : '';
      final newTitle = '$prefix - Lobby #$nextNum$feeStr';

      await _client.from('tournaments').insert({
        'title': newTitle,
        'game': 'FREE FIRE',
        'entry_fee': fee,
        'prize_pool': (master['prize_pool'] as num).toDouble(),
        'per_kill': (master['per_kill'] as num).toDouble(),
        'format': master['format'],
        'map_name': master['map_name'],
        'max_slots': master['max_slots'],
        'filled_slots': 0,
        'start_time': activeSlot.toIso8601String(),
        'status': 'open',
        'banner_url': master['banner_url'],
        'rules': jsonEncode({
          'created_by': 'T69_AUTO_REPLENISH',
          'chat': [
            {
              'sender': '👑 T69 SYSTEM',
              'message': 'Official Match Lobby initialized by T69 League Administration.',
              'isHost': true,
              'time': DateTime.now().toIso8601String(),
            }
          ]
        }),
      });
    } catch (_) {}
  }

  Future<void> _spawnStandbyLobbyForSingle(TournamentModel tournament) async {
    try {
      final all = await getFreeFireTournaments();
      final categoryList = all
          .where((t) =>
              t.format.trim().toLowerCase() == tournament.format.trim().toLowerCase() &&
              t.entryFee.toInt() == tournament.entryFee.toInt())
          .toList();
      final activeSlot = LobbyScheduleHelper.getActiveMatchSlot();
      final master = _masterCategories.firstWhere(
        (m) =>
            m['format'].toString().toLowerCase() == tournament.format.toLowerCase() &&
            (m['entry_fee'] as num).toInt() == tournament.entryFee.toInt(),
        orElse: () => {
          'title_prefix': tournament.title.split('-')[0].trim(),
          'format': tournament.format,
          'entry_fee': tournament.entryFee,
          'prize_pool': tournament.prizePool,
          'per_kill': tournament.perKill,
          'map_name': tournament.mapName,
          'max_slots': tournament.maxSlots,
          'banner_url': tournament.bannerUrl,
        },
      );
      await _spawnNextStandbyLobbyFromTemplate(master, categoryList, activeSlot);
    } catch (_) {}
  }

  Future<List<TournamentModel>> getFreeFireTournaments() async {
    return getTournaments(game: 'FREE FIRE');
  }

  Future<List<WalletTransactionModel>> getUserTransactions() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List).map((json) => WalletTransactionModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addWalletFunds(double amount) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    try {
      // 1. Fetch current balance
      final profileRes = await _client
          .from('profiles')
          .select('wallet_balance')
          .eq('id', user.id)
          .single();

      final currentBalance = (profileRes['wallet_balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance + amount;

      // 2. Update profile
      await _client
          .from('profiles')
          .update({'wallet_balance': newBalance})
          .eq('id', user.id);

      // 3. Record transaction
      await _client.from('wallet_transactions').insert({
        'user_id': user.id,
        'amount': amount,
        'type': 'deposit',
        'description': 'Direct Wallet Load (Demo/UPI)',
        'status': 'completed',
      });
    } catch (e) {
      throw Exception('Failed to add funds: ${e.toString()}');
    }
  }

  Future<void> addNewSponsor({
    required String name,
    required String logoUrl,
    String? websiteUrl,
    String tier = 'partner',
  }) async {
    try {
      await _client.from('sponsors').insert({
        'name': name.trim(),
        'logo_url': logoUrl.trim(),
        'website_url': websiteUrl?.trim(),
        'tier': tier,
        'is_active': true,
      });
    } catch (e) {
      throw Exception('Failed to add sponsor: ${e.toString()}');
    }
  }

  Future<void> deleteSponsor(String sponsorId) async {
    try {
      await _client.from('sponsors').delete().eq('id', sponsorId);
    } catch (e) {
      throw Exception('Failed to delete sponsor: ${e.toString()}');
    }
  }

  Future<void> addNewBanner({
    required String title,
    String? subtitle,
    required String imageUrl,
    String actionType = 'tournament',
    String? actionTarget,
    String tag = 'FEATURED',
  }) async {
    try {
      await _client.from('banners').insert({
        'title': title.trim(),
        'subtitle': subtitle?.trim(),
        'image_url': imageUrl.trim(),
        'action_type': actionType,
        'action_target': actionTarget?.trim(),
        'tag': tag.toUpperCase().trim(),
        'is_active': true,
        'order_index': 0,
      });
    } catch (e) {
      throw Exception('Failed to upload banner: ${e.toString()}');
    }
  }

  Future<bool> isUserRegistered(String tournamentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await _client
          .from('tournament_registrations')
          .select('id')
          .eq('tournament_id', tournamentId)
          .eq('user_id', user.id)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> registerForTournament({
    required TournamentModel tournament,
    required String gameIgn,
    required String gameUid,
    String? teamName,
    List<String>? players,
    int? slotNumber,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Authentication session required.');

    try {
      // 1. Verify latest tournament status and rules from DB
      final tRes = await _client
          .from('tournaments')
          .select('status, rules, entry_fee, max_slots')
          .eq('id', tournament.id)
          .single();

      final currentStatus = (tRes['status']?.toString() ?? '').toLowerCase();
      if (currentStatus == 'cancelled') {
        throw Exception('This match lobby has been cancelled.');
      } else if (currentStatus == 'completed') {
        throw Exception('This match has already completed.');
      } else if (currentStatus == 'live') {
        throw Exception('This match is now LIVE in Free Fire. Registrations are closed.');
      }

      Map<String, dynamic> meta = {};
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        try {
          meta = jsonDecode(existingRules) as Map<String, dynamic>;
        } catch (_) {}
      }

      final isIdpLocked = meta['idp_locked'] as bool? ?? false;
      if (isIdpLocked) {
        throw Exception('Room ID & Password has been broadcasted for this lobby. Registrations are locked.');
      }

      // Check if user was kicked or banned from this tournament
      final kickedList = List<Map<String, dynamic>>.from((meta['kicked_teams'] as List?) ?? []);
      final isKicked = kickedList.any((k) {
        final kUserId = k['user_id']?.toString();
        final kUid = k['game_uid']?.toString();
        return (kUserId != null && kUserId.isNotEmpty && kUserId == user.id) ||
            (kUid != null && kUid.isNotEmpty && kUid == gameUid.trim());
      });

      if (isKicked) {
        final kickInfo = kickedList.firstWhere(
          (k) =>
              (k['user_id']?.toString() != null && k['user_id'].toString() == user.id) ||
              (k['game_uid']?.toString() != null && k['game_uid'].toString() == gameUid.trim()),
          orElse: () => <String, dynamic>{},
        );
        final reason = kickInfo['reason'] ?? 'Violation of lobby rules';
        final role = kickInfo['role'] ?? 'Admin';
        throw Exception('Access Denied: You were removed from this lobby by $role ($reason). Re-joining is blocked.');
      }

      // Check if user is already registered in this tournament
      final existingReg = await _client
          .from('tournament_registrations')
          .select('id, slot_number')
          .eq('tournament_id', tournament.id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingReg != null) {
        throw Exception('You are already registered in Slot #${existingReg['slot_number']} of this lobby.');
      }

      final targetSlot = slotNumber ?? (tournament.filledSlots + 1);

      // Check if target slot is already occupied
      final slotOccupied = await _client
          .from('tournament_registrations')
          .select('id')
          .eq('tournament_id', tournament.id)
          .eq('slot_number', targetSlot)
          .maybeSingle();

      if (slotOccupied != null) {
        throw Exception('Slot #$targetSlot has already been taken by another player. Please select another slot.');
      }

      // 2. Check and deduct wallet balance
      final profileRes = await _client
          .from('profiles')
          .select('wallet_balance, deposit_balance, winning_balance')
          .eq('id', user.id)
          .single();

      final currentBalance = (profileRes['wallet_balance'] as num?)?.toDouble() ?? 0.0;
      var depositBal = (profileRes['deposit_balance'] as num?)?.toDouble() ?? 0.0;
      var winBal = (profileRes['winning_balance'] as num?)?.toDouble() ?? 0.0;

      final entryFee = (tRes['entry_fee'] as num?)?.toDouble() ?? tournament.entryFee;
      if (currentBalance < entryFee) {
        throw Exception('Insufficient funds. Vault balance: ₹${currentBalance.toStringAsFixed(0)}, needed: ₹${entryFee.toStringAsFixed(0)}.');
      }

      // Deduct entry fee: prioritize deposit_balance, then winning_balance
      var feeToDeduct = entryFee;
      if (depositBal >= feeToDeduct) {
        depositBal -= feeToDeduct;
        feeToDeduct = 0.0;
      } else {
        feeToDeduct -= depositBal;
        depositBal = 0.0;
        winBal = (winBal - feeToDeduct).clamp(0.0, double.infinity);
      }

      final newTotalBalance = depositBal + winBal;

      await _client.from('profiles').update({
        'deposit_balance': depositBal,
        'winning_balance': winBal,
        'wallet_balance': newTotalBalance,
      }).eq('id', user.id);

      // 3. Register in tournament_registrations
      final finalIgn = (teamName != null && teamName.isNotEmpty) ? '$teamName: $gameIgn' : gameIgn.trim();

      await _client.from('tournament_registrations').insert({
        'tournament_id': tournament.id,
        'user_id': user.id,
        'game_ign': finalIgn,
        'game_uid': gameUid.trim(),
        'slot_number': targetSlot,
      });

      // 4. Also sync slot team name & players lineup to tournament rules meta
      try {
        final tRes = await _client.from('tournaments').select('rules').eq('id', tournament.id).single();
        Map<String, dynamic> meta = {};
        final existingRules = tRes['rules']?.toString() ?? '';
        if (existingRules.trim().startsWith('{')) {
          meta = jsonDecode(existingRules) as Map<String, dynamic>;
        }
        final scoresList = List<Map<String, dynamic>>.from(meta['scores'] ?? []);
        final teamNameToUse = (teamName != null && teamName.isNotEmpty) ? teamName : gameIgn.trim();
        final playersList = (players != null && players.isNotEmpty) ? players : [gameIgn.trim()];

        bool found = false;
        for (final s in scoresList) {
          if (s['slot'] == targetSlot) {
            s['team_name'] = teamNameToUse;
            s['players'] = playersList;
            s['captain_ign'] = gameIgn.trim();
            s['uid'] = gameUid.trim();
            s['user_id'] = user.id;
            found = true;
            break;
          }
        }
        if (!found) {
          scoresList.add({
            'slot': targetSlot,
            'team_name': teamNameToUse,
            'players': playersList,
            'captain_ign': gameIgn.trim(),
            'uid': gameUid.trim(),
            'user_id': user.id,
            'total': 0,
            'kills_sum': 0,
            'kills': {},
            'place': {},
          });
        }
        meta['scores'] = scoresList;
        await _client.from('tournaments').update({
          'rules': jsonEncode(meta),
        }).eq('id', tournament.id);
      } catch (_) {}

      // 5. Log wallet transaction
      if (tournament.entryFee > 0) {
        await _client.from('wallet_transactions').insert({
          'user_id': user.id,
          'amount': tournament.entryFee,
          'type': 'tournament_entry',
          'description': 'Lobby Entry: ${tournament.title}',
          'status': 'completed',
        });
      }

      // 6. Update filled slots to exact count of registrations
      final currentRegs = await _client
          .from('tournament_registrations')
          .select('id')
          .eq('tournament_id', tournament.id);
      final realCount = (currentRegs as List).length;

      await _client
          .from('tournaments')
          .update({'filled_slots': realCount})
          .eq('id', tournament.id);

      if (realCount >= tournament.maxSlots) {
        _spawnStandbyLobbyForSingle(tournament);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> submitDepositRequest({
    required double amount,
    required String utrNumber,
    required String accountHolderName,
    required String gatewayUsed,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    final cleanUtr = utrNumber.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleanUtr.length != 12 || !RegExp(r'^\d{12}$').hasMatch(cleanUtr)) {
      throw Exception('Invalid UTR format. Indian Bank UTR must be exactly 12 numeric digits (e.g. 423891029384).');
    }

    try {
      // Anti-Fraud Check: Ensure UTR hasn't already been submitted
      final existing = await _client
          .from('wallet_transactions')
          .select('id, status, created_at')
          .eq('utr_number', cleanUtr)
          .maybeSingle();

      if (existing != null) {
        throw Exception('This 12-digit UTR ($cleanUtr) has already been submitted previously. Duplicate UTR submissions are strictly blocked for fraud prevention.');
      }

      await _client.from('wallet_transactions').insert({
        'user_id': user.id,
        'amount': amount,
        'type': 'deposit',
        'description': 'UPI Load • $accountHolderName (UTR: $cleanUtr)',
        'utr_number': cleanUtr,
        'account_holder_name': accountHolderName.trim(),
        'gateway_used': gatewayUsed.trim(),
        'status': 'pending',
      });
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> fetchAdminPaymentRequests({String? statusFilter}) async {
    try {
      dynamic query = _client
          .from('wallet_transactions')
          .select('*, profiles:user_id(username, full_name, game_ign, game_uid, wallet_balance)')
          .eq('type', 'deposit');

      if (statusFilter != null && statusFilter != 'ALL') {
        query = query.eq('status', statusFilter.toLowerCase());
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  Future<void> approveDepositPayment({
    required String transactionId,
    required String userId,
    required double amount,
  }) async {
    try {
      // 1. Fetch user's current balances
      final profileRes = await _client
          .from('profiles')
          .select('wallet_balance, deposit_balance, winning_balance')
          .eq('id', userId)
          .single();

      final currentDeposit = (profileRes['deposit_balance'] as num?)?.toDouble() ?? 0.0;
      final currentWin = (profileRes['winning_balance'] as num?)?.toDouble() ?? 0.0;
      final newDeposit = currentDeposit + amount;
      final newTotal = newDeposit + currentWin;

      // 2. Update user profile balance
      await _client.from('profiles').update({
        'deposit_balance': newDeposit,
        'wallet_balance': newTotal,
      }).eq('id', userId);

      // 3. Update transaction status to completed
      await _client
          .from('wallet_transactions')
          .update({'status': 'completed'})
          .eq('id', transactionId);
    } catch (e) {
      throw Exception('Failed to approve payment: ${e.toString()}');
    }
  }

  Future<void> rejectDepositPayment({required String transactionId}) async {
    try {
      await _client
          .from('wallet_transactions')
          .update({'status': 'rejected'})
          .eq('id', transactionId);
    } catch (e) {
      throw Exception('Failed to reject payment: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchTournamentRegistrations(String tournamentId) async {
    try {
      final response = await _client
          .from('tournament_registrations')
          .select('*, profiles:user_id(username, full_name, avatar_url, wallet_balance)')
          .eq('tournament_id', tournamentId)
          .order('slot_number', ascending: true);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchUserRegistrationForTournament(String tournamentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('tournament_registrations')
          .select('*')
          .eq('tournament_id', tournamentId)
          .eq('user_id', user.id)
          .maybeSingle();

      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      return null;
    }
  }

  Future<Set<String>> getUserRegisteredTournamentIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    try {
      final res = await _client
          .from('tournament_registrations')
          .select('tournament_id')
          .eq('user_id', user.id);

      final set = <String>{};
      for (final item in res as List) {
        if (item['tournament_id'] != null) {
          set.add(item['tournament_id'].toString());
        }
      }
      return set;
    } catch (_) {
      return {};
    }
  }

  Future<void> submitWithdrawalRequest({
    required double amount,
    required String upiId,
    required String accountHolderName,
    String? bankAccount,
    String? ifsc,
    String payoutMethod = 'UPI',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Authentication session required.');

    try {
      // 1. Check current winning balance
      final profileRes = await _client
          .from('profiles')
          .select('wallet_balance, deposit_balance, winning_balance')
          .eq('id', user.id)
          .single();

      final winBal = (profileRes['winning_balance'] as num?)?.toDouble() ?? 0.0;
      final depositBal = (profileRes['deposit_balance'] as num?)?.toDouble() ?? 0.0;

      if (winBal < amount) {
        throw Exception(
          'Only winning cash can be withdrawn. Your withdrawable winning balance is ₹${winBal.toStringAsFixed(0)}. Deposit cash (₹${depositBal.toStringAsFixed(0)}) is reserved for joining tournaments.',
        );
      }

      // 2. Deduct from winning balance & total wallet balance
      final newWinBal = winBal - amount;
      final newTotalBal = depositBal + newWinBal;

      await _client.from('profiles').update({
        'winning_balance': newWinBal,
        'wallet_balance': newTotalBal,
      }).eq('id', user.id);

      // 3. Insert withdrawal transaction with pending status
      await _client.from('wallet_transactions').insert({
        'user_id': user.id,
        'amount': amount,
        'type': 'withdrawal',
        'description': 'Winning Payout to $accountHolderName ($upiId)',
        'account_holder_name': accountHolderName.trim(),
        'payout_upi_id': upiId.trim(),
        'payout_account_number': bankAccount?.trim(),
        'payout_ifsc': ifsc?.trim(),
        'payout_method': payoutMethod,
        'status': 'pending',
      });
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> fetchAdminWithdrawalRequests({String? statusFilter}) async {
    try {
      dynamic query = _client
          .from('wallet_transactions')
          .select('*, profiles:user_id(username, full_name, game_ign, game_uid, wallet_balance, deposit_balance, winning_balance)')
          .eq('type', 'withdrawal');

      if (statusFilter != null && statusFilter != 'ALL') {
        query = query.eq('status', statusFilter.toLowerCase());
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  Future<void> approveWithdrawalPayout({required String transactionId}) async {
    try {
      await _client
          .from('wallet_transactions')
          .update({'status': 'completed'})
          .eq('id', transactionId);
    } catch (e) {
      throw Exception('Failed to mark payout completed: ${e.toString()}');
    }
  }

  Future<void> rejectAndRefundWithdrawal({
    required String transactionId,
    required String userId,
    required double amount,
  }) async {
    try {
      // 1. Fetch user's current balances
      final profileRes = await _client
          .from('profiles')
          .select('wallet_balance, deposit_balance, winning_balance')
          .eq('id', userId)
          .single();

      final winBal = (profileRes['winning_balance'] as num?)?.toDouble() ?? 0.0;
      final depositBal = (profileRes['deposit_balance'] as num?)?.toDouble() ?? 0.0;
      final newWinBal = winBal + amount;
      final newTotalBal = depositBal + newWinBal;

      // 2. Refund balance back to winning balance
      await _client.from('profiles').update({
        'winning_balance': newWinBal,
        'wallet_balance': newTotalBal,
      }).eq('id', userId);

      // 3. Mark transaction rejected
      await _client
          .from('wallet_transactions')
          .update({'status': 'rejected'})
          .eq('id', transactionId);
    } catch (e) {
      throw Exception('Failed to reject & refund: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> fetchUserStats() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return {'matches': 0, 'wins': 0, 'winRate': 0, 'earnings': 0.0};
    }

    try {
      // 1. Real matches count from tournament_registrations
      final matchesRes = await _client
          .from('tournament_registrations')
          .select('id')
          .eq('user_id', user.id);
      final matchesCount = (matchesRes as List).length;

      // 2. Profile for winning balance
      final profileRes = await _client
          .from('profiles')
          .select('winning_balance')
          .eq('id', user.id)
          .maybeSingle();
      final winningBal = (profileRes?['winning_balance'] as num?)?.toDouble() ?? 0.0;

      // 3. Transactions for wins and total earnings
      final txsRes = await _client
          .from('wallet_transactions')
          .select('amount, type, description')
          .eq('user_id', user.id);

      int winsCount = 0;
      double prizeSum = 0.0;

      for (final item in txsRes as List) {
        final type = item['type']?.toString() ?? '';
        final desc = item['description']?.toString() ?? '';
        final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;

        if (type == 'prize_credit' ||
            desc.toLowerCase().contains('booyah') ||
            desc.toLowerCase().contains('1st') ||
            desc.toLowerCase().contains('champion')) {
          winsCount++;
          prizeSum += amt;
        }
      }

      if (prizeSum < winningBal) prizeSum = winningBal;

      final winRate = matchesCount > 0 ? ((winsCount / matchesCount) * 100).round() : 0;

      return {
        'matches': matchesCount,
        'wins': winsCount,
        'winRate': winRate,
        'earnings': prizeSum,
      };
    } catch (_) {
      return {'matches': 0, 'wins': 0, 'winRate': 0, 'earnings': 0.0};
    }
  }

  // ==========================================
  // --- HOST & ESPORTS CONTROLLER APIS ---
  // ==========================================

  Future<List<TournamentModel>> fetchAllTournamentsForHost() async {
    try {
      final response = await _client
          .from('tournaments')
          .select()
          .order('start_time', ascending: true);
      final list = (response as List).map((json) => TournamentModel.fromJson(json)).toList();
      _syncAndRollUnbookedTournaments(list);
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<TournamentModel?> fetchTournamentById(String tournamentId) async {
    try {
      final res = await _client.from('tournaments').select().eq('id', tournamentId).maybeSingle();
      if (res != null) return TournamentModel.fromJson(res);
    } catch (_) {}
    return null;
  }

  /// 1. Claim a tournament lobby as host (Requires Level 40+ agreement & Anti-Self-Playing validation)
  Future<void> claimTournamentAsHost({
    required String tournamentId,
    required String hostId,
    required String hostName,
    required String hostMobile,
    required String hostIgn,
    required String hostUid,
  }) async {
    // 1. Fetch existing tournament metadata
    final tournamentRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).single();
    Map<String, dynamic> meta = {};
    try {
      final existingRules = tournamentRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Check if already claimed by someone else
    if (meta['host_id'] != null && meta['host_id'].toString().isNotEmpty && meta['host_id'] != hostId) {
      throw Exception('This lobby has already been claimed by another certified host.');
    }

    meta['host_id'] = hostId;
    meta['host_name'] = hostName.trim();
    meta['host_mobile'] = hostMobile.trim();
    meta['host_ign'] = hostIgn.trim();
    meta['host_uid'] = hostUid.trim();
    meta['host_rating'] = 4.9;
    meta['host_reward'] = 30;
    meta['allow_screenshots'] = meta['allow_screenshots'] ?? true;
    meta['idp_locked'] = meta['idp_locked'] ?? false;
    meta['claimed_at'] = DateTime.now().toIso8601String();

    await _client.from('tournaments').update({
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);
  }

  /// 2. Lock & Broadcast Custom Room ID and Password (IDP) to Players with Lateness Penalty Check
  Future<void> lockAndBroadcastIdp({
    required String tournamentId,
    required String roomId,
    required String roomPassword,
    required bool allowScreenshots,
  }) async {
    final tRes = await _client.from('tournaments').select('rules, start_time').eq('id', tournamentId).single();
    final startTime = DateTime.tryParse(tRes['start_time']?.toString() ?? '') ?? DateTime.now();

    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    final now = DateTime.now();
    meta['idp_locked'] = true;
    meta['idp_broadcasted_at'] = now.toIso8601String();
    meta['allow_screenshots'] = allowScreenshots;

    // Rule 1: 10-Minute Lateness Penalty Check
    final latenessMinutes = now.difference(startTime).inMinutes;
    if (latenessMinutes > 10) {
      meta['host_reward'] = 15; // 50% penalty applied
      meta['late_penalty_applied'] = true;
    } else {
      meta['host_reward'] = 30;
      meta['late_penalty_applied'] = false;
    }

    await _client.from('tournaments').update({
      'room_id': roomId.trim(),
      'room_password': roomPassword.trim(),
      'status': 'live',
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);
  }

  /// 3. Unlock IDP to allow editing if wrong room created
  Future<void> unlockIdp({required String tournamentId}) async {
    final tRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).single();
    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    meta['idp_locked'] = false;

    await _client.from('tournaments').update({
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);
  }

  /// 4. Toggle screenshot uploads permission
  Future<void> toggleScreenshotUploads({required String tournamentId, required bool allow}) async {
    final tRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).single();
    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    meta['allow_screenshots'] = allow;

    await _client.from('tournaments').update({
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);
  }

  /// 5. Save & Broadcast 6-Match Esports / Clash Squad Scoring Sheet to Players in Real Time
  Future<void> saveAndBroadcastScores({
    required String tournamentId,
    required List<Map<String, dynamic>> scores,
    Map<String, dynamic>? csResult,
  }) async {
    final tRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).single();
    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    meta['scores'] = scores;
    if (csResult != null) {
      meta['cs_result'] = csResult;
    }
    meta['scores_updated_at'] = DateTime.now().toIso8601String();

    await _client.from('tournaments').update({
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);
  }

  /// 6. Upload Player Result Screenshot Proof
  Future<void> uploadPlayerScreenshotProof({
    required String tournamentId,
    required String playerName,
    required String slotNumber,
    required String screenshotUrl,
  }) async {
    final tRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).single();
    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    final proofs = List<Map<String, dynamic>>.from((meta['screenshot_proofs'] as List?) ?? []);
    proofs.add({
      'player_name': playerName,
      'slot': slotNumber,
      'url': screenshotUrl,
      'time': DateTime.now().toIso8601String(),
    });
    meta['screenshot_proofs'] = proofs;

    await _client.from('tournaments').update({
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);
  }

  /// 7. Send Real-Time Room Coordination Message
  Future<void> sendHostChatMessage({
    required String tournamentId,
    required String senderName,
    required String message,
    required bool isHost,
  }) async {
    final tRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).single();
    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    final chatList = List<Map<String, dynamic>>.from((meta['chat'] as List?) ?? []);
    chatList.add({
      'sender': senderName,
      'message': message.trim(),
      'isHost': isHost,
      'time': DateTime.now().toIso8601String(),
    });
    meta['chat'] = chatList;

    await _client.from('tournaments').update({
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);
  }

  /// 8. Finish Tournament & Submit Payouts for Top 3 Winners and Host Compensation
  /// 8. Finish Tournament & Submit Payouts for Top 3 Winners and Host Compensation
  Future<void> finishTournamentAndSubmitPayout({
    required String tournamentId,
    required Map<String, dynamic> top1,
    required Map<String, dynamic> top2,
    required Map<String, dynamic> top3,
    required double top1Prize,
    required double top2Prize,
    required double top3Prize,
    required int hostReward,
    required String hostId,
    required String hostName,
    List<Map<String, dynamic>> leaderboard = const [],
    List<Map<String, dynamic>> registrations = const [],
  }) async {
    final tRes = await _client.from('tournaments').select('title, format, rules').eq('id', tournamentId).single();
    final matchTitle = tRes['title']?.toString() ?? 'Esports Tournament';
    final format = tRes['format']?.toString() ?? 'Squad BR';

    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    meta['payout_submitted'] = true;
    meta['payout_submitted_at'] = DateTime.now().toIso8601String();
    meta['top1'] = top1;
    meta['top2'] = top2;
    meta['top3'] = top3;
    meta['top1_prize'] = top1Prize;
    meta['top2_prize'] = top2Prize;
    meta['top3_prize'] = top3Prize;
    meta['host_reward'] = hostReward;

    // 1. Credit / Submit Winner 1 Prize
    if (top1['user_id'] != null && top1Prize > 0) {
      await _creditWinnerPrize(
        userId: top1['user_id'].toString(),
        amount: top1Prize,
        desc: '🥇 1st Place Champion - $matchTitle',
      );
    }

    // 2. Credit / Submit Winner 2 Prize
    if (top2['user_id'] != null && top2Prize > 0) {
      await _creditWinnerPrize(
        userId: top2['user_id'].toString(),
        amount: top2Prize,
        desc: '🥈 2nd Place Runner-Up - $matchTitle',
      );
    }

    // 3. Credit / Submit Winner 3 Prize
    if (top3['user_id'] != null && top3Prize > 0) {
      await _creditWinnerPrize(
        userId: top3['user_id'].toString(),
        amount: top3Prize,
        desc: '🥉 3rd Place Podium - $matchTitle',
      );
    }

    // 4. Credit Host Compensation Reward
    if (hostId.isNotEmpty && hostReward > 0) {
      await _creditWinnerPrize(
        userId: hostId,
        amount: hostReward.toDouble(),
        desc: '🎮 Host Match Compensation Reward - $matchTitle',
      );
    }

    // Collect all participant IDs and winner IDs
    final Set<String> participantIdSet = {};
    final Set<String> winnerIdSet = {};

    if (top1['user_id'] != null && top1Prize > 0) {
      winnerIdSet.add(top1['user_id'].toString());
    }
    if (top2['user_id'] != null && top2Prize > 0) {
      winnerIdSet.add(top2['user_id'].toString());
    }
    if (top3['user_id'] != null && top3Prize > 0) {
      winnerIdSet.add(top3['user_id'].toString());
    }

    for (final reg in registrations) {
      final uId = reg['user_id']?.toString();
      if (uId != null && uId.isNotEmpty) participantIdSet.add(uId);
    }
    for (final s in leaderboard) {
      final uId = s['user_id']?.toString();
      if (uId != null && uId.isNotEmpty) participantIdSet.add(uId);
    }
    if (top1['user_id'] != null) participantIdSet.add(top1['user_id'].toString());
    if (top2['user_id'] != null) participantIdSet.add(top2['user_id'].toString());
    if (top3['user_id'] != null) participantIdSet.add(top3['user_id'].toString());

    final participantsList = <Map<String, dynamic>>[];
    for (final s in leaderboard) {
      final uId = s['user_id']?.toString() ?? '';
      final team = s['team_name']?.toString() ?? '';
      final slot = s['slot'];
      final kills = s['kills_sum'] ?? 0;
      final total = s['total'] ?? 0;
      final isTop1 = top1['user_id']?.toString() == uId || top1['team_name'] == team;
      final isTop2 = top2['user_id']?.toString() == uId || top2['team_name'] == team;
      final isTop3 = top3['user_id']?.toString() == uId || top3['team_name'] == team;
      final prize = isTop1 ? top1Prize : (isTop2 ? top2Prize : (isTop3 ? top3Prize : 0.0));

      participantsList.add({
        'user_id': uId,
        'team_name': team,
        'slot': slot,
        'kills': kills,
        'total_pts': total,
        'prize': prize,
        'is_winner': prize > 0,
        'placement': isTop1 ? 1 : (isTop2 ? 2 : (isTop3 ? 3 : null)),
      });
    }

    // 5. Create Permanent Match History Record
    final historyItem = {
      'id': 'MATCH_${DateTime.now().millisecondsSinceEpoch}',
      'tournament_id': tournamentId,
      'title': matchTitle,
      'format': format,
      'game': 'FREE FIRE',
      'type': 'winner_podium',
      'top1_team': top1['team_name'] ?? 'Winner',
      'top1_user_id': top1['user_id']?.toString(),
      'top1_prize': top1Prize,
      'top2_team': top2['team_name'] ?? 'Runner Up',
      'top2_user_id': top2['user_id']?.toString(),
      'top2_prize': top2Prize,
      'top3_team': top3['team_name'] ?? 'Podium 3',
      'top3_user_id': top3['user_id']?.toString(),
      'top3_prize': top3Prize,
      'host_reward': hostReward,
      'host_id': hostId,
      'host_name': hostName,
      'participant_ids': participantIdSet.toList(),
      'winner_ids': winnerIdSet.toList(),
      'participants': participantsList,
      'leaderboard': leaderboard,
      'completed_at': DateTime.now().toIso8601String(),
    };

    final historyList = List<Map<String, dynamic>>.from(meta['match_history'] ?? []);
    historyList.insert(0, historyItem);
    meta['match_history'] = historyList;

    // Wipe match-in-progress state
    meta.remove('payout_submitted');
    meta.remove('payout_submitted_at');
    meta.remove('top1');
    meta.remove('top2');
    meta.remove('top3');
    meta['scores'] = [];
    meta['chat'] = [];
    meta['screenshot_proofs'] = [];
    meta['kicked_teams'] = [];
    meta['idp_locked'] = false;
    meta['idp_broadcasted_at'] = null;

    // 6. Automatic Lobby Refresh for Next Match
    final nextStartTime = LobbyScheduleHelper.getActiveMatchSlot();
    await _client.from('tournaments').update({
      'room_id': null,
      'room_password': null,
      'status': 'open',
      'filled_slots': 0,
      'start_time': nextStartTime.toIso8601String(),
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);

    // 7. Delete all old player registrations so slots open completely
    await _client.from('tournament_registrations').delete().eq('tournament_id', tournamentId);
  }

  /// 8b. Finish Solo Per-Kill Tournament & Submit Payouts for All Players with Kills
  Future<void> finishSoloPerKillTournamentAndSubmitPayout({
    required String tournamentId,
    required double perKillRate,
    required List<Map<String, dynamic>> leaderboard,
    required int hostReward,
    required String hostId,
    required String hostName,
    List<Map<String, dynamic>> registrations = const [],
  }) async {
    final tRes = await _client.from('tournaments').select('title, format, rules').eq('id', tournamentId).single();
    final matchTitle = tRes['title']?.toString() ?? 'Solo Free Fire Match';
    final format = tRes['format']?.toString() ?? 'Solo BR';

    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Distribute Per-Kill payouts to every player with kills > 0
    int totalKills = 0;
    double totalKillPrize = 0.0;
    final Set<String> winnerIdSet = {};
    final Set<String> participantIdSet = {};
    final List<Map<String, dynamic>> participantsList = [];

    for (final reg in registrations) {
      final uId = reg['user_id']?.toString();
      if (uId != null && uId.isNotEmpty) participantIdSet.add(uId);
    }

    for (final player in leaderboard) {
      final uId = player['user_id']?.toString() ?? '';
      final kills = (player['kills_sum'] as num?)?.toInt() ?? 0;
      final ign = player['captain_ign'] ?? player['game_ign'] ?? player['team_name'] ?? 'Player';
      final slot = player['slot'];

      if (uId.isNotEmpty) participantIdSet.add(uId);

      double killPrize = 0.0;
      if (uId.isNotEmpty && kills > 0) {
        killPrize = kills * perKillRate;
        totalKills += kills;
        totalKillPrize += killPrize;
        winnerIdSet.add(uId);
        await _creditWinnerPrize(
          userId: uId,
          amount: killPrize,
          desc: '💀 Solo Kill Reward ($kills Kills x ₹${perKillRate.toStringAsFixed(0)}) - $matchTitle',
        );
      }

      participantsList.add({
        'user_id': uId,
        'game_ign': ign,
        'slot': slot,
        'kills': kills,
        'prize': killPrize,
        'is_winner': kills > 0,
      });
    }

    // Credit Host Reward
    if (hostId.isNotEmpty && hostReward > 0) {
      await _creditWinnerPrize(
        userId: hostId,
        amount: hostReward.toDouble(),
        desc: '🎮 Host Match Compensation Reward - $matchTitle',
      );
    }

    // Create Permanent Match History Record
    final historyItem = {
      'id': 'SOLO_${DateTime.now().millisecondsSinceEpoch}',
      'tournament_id': tournamentId,
      'title': matchTitle,
      'format': format,
      'game': 'FREE FIRE',
      'type': 'solo_per_kill',
      'per_kill_rate': perKillRate,
      'total_kills': totalKills,
      'total_payout': totalKillPrize,
      'host_reward': hostReward,
      'host_id': hostId,
      'host_name': hostName,
      'participant_ids': participantIdSet.toList(),
      'winner_ids': winnerIdSet.toList(),
      'participants': participantsList,
      'leaderboard': leaderboard,
      'completed_at': DateTime.now().toIso8601String(),
    };

    final historyList = List<Map<String, dynamic>>.from(meta['match_history'] ?? []);
    historyList.insert(0, historyItem);
    meta['match_history'] = historyList;

    // Wipe match-in-progress state
    meta.remove('payout_submitted');
    meta.remove('payout_submitted_at');
    meta.remove('payout_type');
    meta.remove('per_kill_rate');
    meta['scores'] = [];
    meta['chat'] = [];
    meta['screenshot_proofs'] = [];
    meta['kicked_teams'] = [];
    meta['idp_locked'] = false;
    meta['idp_broadcasted_at'] = null;

    // Automatic Lobby Refresh for Next Match
    final nextStartTime = LobbyScheduleHelper.getActiveMatchSlot();
    await _client.from('tournaments').update({
      'room_id': null,
      'room_password': null,
      'status': 'open',
      'filled_slots': 0,
      'start_time': nextStartTime.toIso8601String(),
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);

    // Delete all old player registrations so slots open completely
    await _client.from('tournament_registrations').delete().eq('tournament_id', tournamentId);
  }

  Future<void> _creditWinnerPrize({
    required String userId,
    required double amount,
    required String desc,
  }) async {
    try {
      final pRes = await _client.from('profiles').select('wallet_balance, winning_balance').eq('id', userId).maybeSingle();
      if (pRes != null) {
        final winBal = (pRes['winning_balance'] as num?)?.toDouble() ?? 0.0;
        final totalBal = (pRes['wallet_balance'] as num?)?.toDouble() ?? 0.0;
        await _client.from('profiles').update({
          'winning_balance': winBal + amount,
          'wallet_balance': totalBal + amount,
        }).eq('id', userId);
      }

      await _client.from('wallet_transactions').insert({
        'user_id': userId,
        'amount': amount,
        'type': 'prize_credit',
        'description': desc,
        'status': 'completed',
      });
    } catch (_) {}
  }

  /// 8c. Finish Clash Squad Tournament (Winner Takes All ₹85 PP, Host ₹10, Auto-Refresh Lobby & Save History)
  Future<void> finishClashSquadTournamentAndSubmitPayout({
    required String tournamentId,
    required String winningSide, // 'LEFT SIDE' or 'RIGHT SIDE'
    required int leftScore,
    required int rightScore,
    required String leftTeamName,
    required String rightTeamName,
    required double winnerPrize,
    required int hostReward,
    required String hostId,
    required String hostName,
    List<Map<String, dynamic>> registrations = const [],
  }) async {
    final tRes = await _client.from('tournaments').select('title, format, rules').eq('id', tournamentId).single();
    final matchTitle = tRes['title']?.toString() ?? 'Free Fire Clash Squad Duel';
    final format = tRes['format']?.toString() ?? '1v1 Clash Squad';

    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    final isLeftWinner = winningSide.toUpperCase().contains('LEFT') || winningSide == '1' || winningSide == 'TEAM 1';
    final winningSlot = isLeftWinner ? 1 : 2;

    // 1. Find registered players on the winning side
    final winningRegs = registrations.where((r) => (r['slot_number'] as num?)?.toInt() == winningSlot).toList();
    final leftRegs = registrations.where((r) => (r['slot_number'] as num?)?.toInt() == 1).toList();
    final rightRegs = registrations.where((r) => (r['slot_number'] as num?)?.toInt() == 2).toList();

    final leftPlayers = leftRegs.map((r) => r['game_ign']?.toString() ?? r['profiles']?['username']?.toString() ?? 'Player 1').toList();
    final rightPlayers = rightRegs.map((r) => r['game_ign']?.toString() ?? r['profiles']?['username']?.toString() ?? 'Player 2').toList();

    final Set<String> winnerIdSet = {};
    final Set<String> participantIdSet = {};
    final List<Map<String, dynamic>> participantsList = [];

    for (final reg in registrations) {
      final uId = reg['user_id']?.toString();
      if (uId != null && uId.isNotEmpty) participantIdSet.add(uId);
    }

    // 2. Real-Money Prize Distribution to Winner(s)
    if (winningRegs.isNotEmpty && winnerPrize > 0) {
      final perPlayerPrize = winnerPrize / winningRegs.length;
      for (final reg in winningRegs) {
        final uId = reg['user_id']?.toString() ?? '';
        final ign = reg['game_ign'] ?? 'Player';
        if (uId.isNotEmpty) {
          winnerIdSet.add(uId);
          await _creditWinnerPrize(
            userId: uId,
            amount: perPlayerPrize,
            desc: '👑 Clash Squad Victory ($winningSide - $ign) - $matchTitle',
          );
        }
      }
    } else {
      // Fallback: Check if scores metadata has user_id for winning slot
      final scoresList = List<Map<String, dynamic>>.from(meta['scores'] ?? []);
      for (final s in scoresList) {
        if ((s['slot'] as num?)?.toInt() == winningSlot && s['user_id'] != null && s['user_id'].toString().isNotEmpty) {
          final uId = s['user_id'].toString();
          winnerIdSet.add(uId);
          participantIdSet.add(uId);
          await _creditWinnerPrize(
            userId: uId,
            amount: winnerPrize,
            desc: '👑 Clash Squad Victory ($winningSide) - $matchTitle',
          );
        }
      }
    }

    for (final reg in leftRegs) {
      final uId = reg['user_id']?.toString() ?? '';
      final ign = reg['game_ign'] ?? reg['profiles']?['username'] ?? leftTeamName;
      participantsList.add({
        'user_id': uId,
        'game_ign': ign,
        'slot': 1,
        'side': 'LEFT SIDE',
        'team_name': leftTeamName,
        'is_winner': isLeftWinner,
        'prize': isLeftWinner ? (winnerPrize / (winningRegs.isNotEmpty ? winningRegs.length : 1)) : 0.0,
      });
    }

    for (final reg in rightRegs) {
      final uId = reg['user_id']?.toString() ?? '';
      final ign = reg['game_ign'] ?? reg['profiles']?['username'] ?? rightTeamName;
      participantsList.add({
        'user_id': uId,
        'game_ign': ign,
        'slot': 2,
        'side': 'RIGHT SIDE',
        'team_name': rightTeamName,
        'is_winner': !isLeftWinner,
        'prize': !isLeftWinner ? (winnerPrize / (winningRegs.isNotEmpty ? winningRegs.length : 1)) : 0.0,
      });
    }

    // 3. Credit Host Compensation (₹10)
    if (hostId.isNotEmpty && hostReward > 0) {
      await _creditWinnerPrize(
        userId: hostId,
        amount: hostReward.toDouble(),
        desc: '🎮 Host Match Compensation (Clash Squad) - $matchTitle',
      );
    }

    // 4. Create Permanent Match History Record
    final historyItem = {
      'id': 'CS_${DateTime.now().millisecondsSinceEpoch}',
      'tournament_id': tournamentId,
      'title': matchTitle,
      'format': format,
      'game': 'FREE FIRE',
      'type': 'clash_squad',
      'winning_side': winningSide,
      'winning_team_name': isLeftWinner ? leftTeamName : rightTeamName,
      'left_score': leftScore,
      'right_score': rightScore,
      'left_team_name': leftTeamName,
      'right_team_name': rightTeamName,
      'left_players': leftPlayers.isNotEmpty ? leftPlayers : [leftTeamName],
      'right_players': rightPlayers.isNotEmpty ? rightPlayers : [rightTeamName],
      'prize_pool': winnerPrize,
      'host_reward': hostReward,
      'host_id': hostId,
      'host_name': hostName,
      'participant_ids': participantIdSet.toList(),
      'winner_ids': winnerIdSet.toList(),
      'participants': participantsList,
      'completed_at': DateTime.now().toIso8601String(),
    };

    final historyList = List<Map<String, dynamic>>.from(meta['match_history'] ?? []);
    historyList.insert(0, historyItem);
    meta['match_history'] = historyList;
    
    // Store last_completed_match so lobby room leaderboard shows recent winner, but clear active in-progress markers
    meta['last_completed_match'] = historyItem;
    meta.remove('cs_result');
    meta.remove('top1');
    meta.remove('top2');
    meta.remove('top3');
    meta.remove('payout_submitted');
    meta.remove('payout_submitted_at');
    meta.remove('payout_type');

    // 5. Automatic Lobby Refresh for Next Match
    // Reset credentials and slots so new players can immediately register for the next match
    final nextStartTime = LobbyScheduleHelper.getActiveMatchSlot();
    meta['idp_locked'] = false;
    meta['idp_broadcasted_at'] = null;
    meta['chat'] = [];
    meta['screenshot_proofs'] = [];
    meta['scores'] = [];
    meta['kicked_teams'] = [];

    await _client.from('tournaments').update({
      'room_id': null,
      'room_password': null,
      'status': 'open',
      'filled_slots': 0,
      'start_time': nextStartTime.toIso8601String(),
      'rules': jsonEncode(meta),
    }).eq('id', tournamentId);

    // Clear old registrations from this tournament so new slots open up
    await _client.from('tournament_registrations').delete().eq('tournament_id', tournamentId);
  }

  /// Fetch Completed Match History for a specific user (or all if user is coordinator/admin).
  /// Only matches the user played in or hosted are returned for personal accounts.
  Future<List<Map<String, dynamic>>> fetchCompletedMatchHistory({
    String? userId,
    String? userIgn,
  }) async {
    final List<Map<String, dynamic>> results = [];
    try {
      final tList = await _client.from('tournaments').select('id, title, format, game, rules, status, start_time');
      for (final t in tList as List) {
        final rulesStr = t['rules']?.toString() ?? '';
        if (rulesStr.trim().startsWith('{')) {
          try {
            final meta = jsonDecode(rulesStr) as Map<String, dynamic>;
            final matchHistory = meta['match_history'] as List?;
            if (matchHistory != null && matchHistory.isNotEmpty) {
              for (final m in matchHistory) {
                if (m is Map) {
                  final map = Map<String, dynamic>.from(m);
                  if (_isUserParticipantInMatch(map, userId: userId, userIgn: userIgn)) {
                    results.add(map);
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Sort by most recently completed
    results.sort((a, b) {
      final aTime = DateTime.tryParse(a['completed_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b['completed_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return results;
  }

  /// Check whether a user participated in, won, or hosted a given match
  bool _isUserParticipantInMatch(
    Map<String, dynamic> match, {
    String? userId,
    String? userIgn,
  }) {
    // If no user filter requested, return all (e.g. for coordinator tools)
    if ((userId == null || userId.isEmpty) && (userIgn == null || userIgn.isEmpty)) {
      return true;
    }

    final cleanUserId = userId?.trim() ?? '';
    final cleanIgn = userIgn?.trim().toLowerCase() ?? '';

    // 1. Check direct host_id
    if (cleanUserId.isNotEmpty && match['host_id']?.toString() == cleanUserId) {
      return true;
    }

    // 2. Check participant_ids list
    final participantIds = (match['participant_ids'] as List?)?.map((id) => id.toString()).toSet() ?? {};
    if (cleanUserId.isNotEmpty && participantIds.contains(cleanUserId)) {
      return true;
    }

    // 3. Check winner_ids list
    final winnerIds = (match['winner_ids'] as List?)?.map((id) => id.toString()).toSet() ?? {};
    if (cleanUserId.isNotEmpty && winnerIds.contains(cleanUserId)) {
      return true;
    }

    // 4. Check single user_id / winner_id / top placements
    if (cleanUserId.isNotEmpty) {
      if (match['user_id']?.toString() == cleanUserId) return true;
      if (match['winner_id']?.toString() == cleanUserId) return true;
      if (match['top1_user_id']?.toString() == cleanUserId) return true;
      if (match['top2_user_id']?.toString() == cleanUserId) return true;
      if (match['top3_user_id']?.toString() == cleanUserId) return true;
    }

    // 5. Check participants structured list
    final participants = (match['participants'] as List?)?.whereType<Map>().toList();
    if (participants != null && participants.isNotEmpty) {
      for (final p in participants) {
        if (cleanUserId.isNotEmpty && p['user_id']?.toString() == cleanUserId) return true;
        if (cleanIgn.isNotEmpty) {
          final ign = p['game_ign']?.toString().toLowerCase() ?? '';
          final team = p['team_name']?.toString().toLowerCase() ?? '';
          if (ign == cleanIgn || team == cleanIgn) return true;
        }
      }
    }

    // 6. Check leaderboard list (for Solo / BR)
    final leaderboard = (match['leaderboard'] as List?)?.whereType<Map>().toList();
    if (leaderboard != null && leaderboard.isNotEmpty) {
      for (final p in leaderboard) {
        if (cleanUserId.isNotEmpty && p['user_id']?.toString() == cleanUserId) return true;
        if (cleanIgn.isNotEmpty) {
          final ign = (p['captain_ign'] ?? p['game_ign'] ?? p['team_name'])?.toString().toLowerCase() ?? '';
          if (ign == cleanIgn || ign.contains(cleanIgn)) return true;
        }
      }
    }

    // 7. Check Clash Squad player names / lists
    if (cleanIgn.isNotEmpty) {
      final leftPlayers = (match['left_players'] as List?)?.map((p) => p.toString().toLowerCase()).toList() ?? [];
      final rightPlayers = (match['right_players'] as List?)?.map((p) => p.toString().toLowerCase()).toList() ?? [];
      if (leftPlayers.any((p) => p == cleanIgn || p.contains(cleanIgn))) return true;
      if (rightPlayers.any((p) => p == cleanIgn || p.contains(cleanIgn))) return true;

      final leftTeam = match['left_team_name']?.toString().toLowerCase() ?? '';
      final rightTeam = match['right_team_name']?.toString().toLowerCase() ?? '';
      final winTeam = match['winning_team_name']?.toString().toLowerCase() ?? '';
      if (leftTeam.contains(cleanIgn) || rightTeam.contains(cleanIgn) || winTeam.contains(cleanIgn)) {
        return true;
      }
    }

    return false;
  }

  /// 9. Automated Rule 2: 20-Minute Missing IDP Auto-Cancellation & Full Player Refund
  Future<void> cancelTournamentAndRefundPlayers({
    required String tournamentId,
    required String reason,
  }) async {
    final tRes = await _client.from('tournaments').select('title, entry_fee').eq('id', tournamentId).single();
    final entryFee = (tRes['entry_fee'] as num?)?.toDouble() ?? 0.0;
    final title = tRes['title']?.toString() ?? 'Tournament';

    final registrations = await _client
        .from('tournament_registrations')
        .select('user_id')
        .eq('tournament_id', tournamentId);

    // Refund every registered player
    for (final reg in registrations as List) {
      final uId = reg['user_id']?.toString() ?? '';
      if (uId.isNotEmpty && entryFee > 0) {
        try {
          final pRes = await _client.from('profiles').select('wallet_balance, deposit_balance').eq('id', uId).maybeSingle();
          if (pRes != null) {
            final depBal = (pRes['deposit_balance'] as num?)?.toDouble() ?? 0.0;
            final totBal = (pRes['wallet_balance'] as num?)?.toDouble() ?? 0.0;
            await _client.from('profiles').update({
              'deposit_balance': depBal + entryFee,
              'wallet_balance': totBal + entryFee,
            }).eq('id', uId);
          }

          await _client.from('wallet_transactions').insert({
            'user_id': uId,
            'amount': entryFee,
            'type': 'refund',
            'description': 'Refund: $title ($reason)',
            'status': 'completed',
          });
        } catch (_) {}
      }
    }

    await _client.from('tournaments').update({
      'status': 'cancelled',
    }).eq('id', tournamentId);
  }

  /// 10. Reset Lobby for Next Schedule
  Future<void> resetLobbyForNextSchedule({required String tournamentId}) async {
    final tRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).maybeSingle();
    Map<String, dynamic> meta = {};
    try {
      final existingRules = tRes?['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        meta = jsonDecode(existingRules) as Map<String, dynamic>;
      }
    } catch (_) {}

    final matchHistory = meta['match_history'];
    meta.clear();
    if (matchHistory != null) {
      meta['match_history'] = matchHistory;
    }
    meta['scores'] = [];
    meta['chat'] = [];
    meta['screenshot_proofs'] = [];
    meta['kicked_teams'] = [];
    meta['idp_locked'] = false;
    meta['idp_broadcasted_at'] = null;

    final nextTime = LobbyScheduleHelper.getActiveMatchSlot();
    await _client.from('tournaments').update({
      'room_id': null,
      'room_password': null,
      'rules': jsonEncode(meta),
      'status': 'open',
      'filled_slots': 0,
      'start_time': nextTime.toIso8601String(),
    }).eq('id', tournamentId);

    // Clear old registrations
    await _client.from('tournament_registrations').delete().eq('tournament_id', tournamentId);
  }

  /// 11. Instant Kick Player from Lobby (Admin / Host Power)
  Future<void> kickPlayerFromLobby({
    required String tournamentId,
    required String userId,
    required int slotNumber,
    required bool refundEntryFee,
    required String reason,
    required String adminOrHostName,
    String? teamOrPlayerName,
    String? gameUid,
    bool isHostBan = false,
  }) async {
    try {
      // 1. Fetch tournament info
      final tRes = await _client
          .from('tournaments')
          .select('title, entry_fee, rules')
          .eq('id', tournamentId)
          .single();

      final entryFee = (tRes['entry_fee'] as num?)?.toDouble() ?? 0.0;
      final tournamentTitle = tRes['title']?.toString() ?? 'Tournament Lobby';

      Map<String, dynamic> meta = {};
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        try {
          meta = jsonDecode(existingRules) as Map<String, dynamic>;
        } catch (_) {}
      }

      String targetDisplayName = teamOrPlayerName ?? 'Slot #$slotNumber';
      String targetUid = gameUid ?? '';

      // Attempt to resolve player / team name if not provided
      if (teamOrPlayerName == null || teamOrPlayerName.isEmpty) {
        try {
          var regQuery = _client.from('tournament_registrations').select('game_ign, team_name, game_uid, user_id');
          if (userId.isNotEmpty) {
            regQuery = regQuery.eq('user_id', userId).eq('tournament_id', tournamentId);
          } else {
            regQuery = regQuery.eq('slot_number', slotNumber).eq('tournament_id', tournamentId);
          }
          final regData = await regQuery.maybeSingle();
          if (regData != null) {
            final tName = regData['team_name']?.toString();
            final ign = regData['game_ign']?.toString();
            targetDisplayName = (tName != null && tName.isNotEmpty) ? tName : (ign ?? 'Player');
            targetUid = regData['game_uid']?.toString() ?? targetUid;
          }
        } catch (_) {}
      }

      // 2. Refund if requested & entryFee > 0
      if (refundEntryFee && entryFee > 0 && userId.isNotEmpty) {
        final profileRes = await _client
            .from('profiles')
            .select('wallet_balance, deposit_balance')
            .eq('id', userId)
            .maybeSingle();

        if (profileRes != null) {
          final curDep = (profileRes['deposit_balance'] as num?)?.toDouble() ?? 0.0;
          final curTot = (profileRes['wallet_balance'] as num?)?.toDouble() ?? 0.0;
          final newDep = curDep + entryFee;
          final newTot = curTot + entryFee;

          await _client.from('profiles').update({
            'deposit_balance': newDep,
            'wallet_balance': newTot,
          }).eq('id', userId);

          await _client.from('wallet_transactions').insert({
            'user_id': userId,
            'amount': entryFee,
            'type': 'refund',
            'description': 'Lobby Refund (Slot #$slotNumber removed: $reason) - $tournamentTitle',
            'status': 'completed',
          });
        }
      }

      // 3. Delete registration from tournament_registrations
      if (userId.isNotEmpty) {
        await _client
            .from('tournament_registrations')
            .delete()
            .eq('tournament_id', tournamentId)
            .eq('user_id', userId);
      } else {
        await _client
            .from('tournament_registrations')
            .delete()
            .eq('tournament_id', tournamentId)
            .eq('slot_number', slotNumber);
      }

      // 4. Update tournament rules metadata
      final scoresList = List<Map<String, dynamic>>.from(meta['scores'] ?? []);
      scoresList.removeWhere((s) => s['slot'] == slotNumber || (userId.isNotEmpty && s['user_id'] == userId));
      meta['scores'] = scoresList;

      // 5. Store in kicked_teams list so players in lobby see who got kicked and reason
      final kickedList = List<Map<String, dynamic>>.from((meta['kicked_teams'] as List?) ?? []);
      kickedList.removeWhere((k) => (k['slot'] as num?)?.toInt() == slotNumber || (userId.isNotEmpty && k['user_id'] == userId));
      kickedList.insert(0, {
        'slot': slotNumber,
        'user_id': userId,
        'team_name': targetDisplayName,
        'game_uid': targetUid,
        'reason': reason,
        'action': isHostBan ? 'KICKED & BANNED' : (refundEntryFee ? 'KICKED (REFUNDED)' : 'KICKED (NO REFUND)'),
        'enforced_by': 'T69 Team',
        'role': 'T69 TEAM',
        'time': DateTime.now().toIso8601String(),
      });
      meta['kicked_teams'] = kickedList;

      // 6. Broadcast system notice to lobby chat
      final chatList = List<Map<String, dynamic>>.from(meta['chat'] ?? []);
      chatList.add({
        'sender': '🛡️ T69 TEAM SECURITY',
        'message': 'Slot #$slotNumber ($targetDisplayName) was REMOVED by T69 Team. Reason: $reason.',
        'isHost': true,
        'time': DateTime.now().toIso8601String(),
      });
      meta['chat'] = chatList;

      // 7. Recalculate filled slots
      final regRes = await _client
          .from('tournament_registrations')
          .select('id')
          .eq('tournament_id', tournamentId);
      final remainingCount = (regRes as List).length;

      await _client.from('tournaments').update({
        'filled_slots': remainingCount,
        'rules': jsonEncode(meta),
      }).eq('id', tournamentId);
    } catch (e) {
      throw Exception('Failed to kick player: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// 12. Instant Ban Team & Disqualify (Host / Esports Security Power)
  Future<void> banTeamAndDisqualify({
    required String tournamentId,
    required int slotNumber,
    required String teamOrPlayerName,
    required String reason,
    required String hostName,
    required bool removeRegistration,
    String? userId,
  }) async {
    try {
      if (removeRegistration) {
        await kickPlayerFromLobby(
          tournamentId: tournamentId,
          userId: userId ?? '',
          slotNumber: slotNumber,
          refundEntryFee: false, // Cheaters/violators get 0 refund
          reason: reason,
          adminOrHostName: hostName,
          teamOrPlayerName: teamOrPlayerName,
          isHostBan: true,
        );
      } else {
        // Disqualify and mark score 0 on leaderboard
        final tRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).single();
        Map<String, dynamic> meta = {};
        final existingRules = tRes['rules']?.toString() ?? '';
        if (existingRules.trim().startsWith('{')) {
          try {
            meta = jsonDecode(existingRules) as Map<String, dynamic>;
          } catch (_) {}
        }

        final scoresList = List<Map<String, dynamic>>.from(meta['scores'] ?? []);
        bool found = false;
        for (final s in scoresList) {
          if (s['slot'] == slotNumber) {
            s['is_banned'] = true;
            s['ban_reason'] = reason;
            s['total'] = 0;
            s['placement_pts'] = 0;
            s['kills_sum'] = 0;
            s['team_name'] = '🚫 BANNED: ${s['team_name'] ?? teamOrPlayerName}';
            found = true;
            break;
          }
        }
        if (!found) {
          scoresList.add({
            'slot': slotNumber,
            'team_name': '🚫 BANNED: $teamOrPlayerName',
            'is_banned': true,
            'ban_reason': reason,
            'total': 0,
            'placement_pts': 0,
            'kills_sum': 0,
          });
        }
        meta['scores'] = scoresList;

        // Store into kicked_teams
        final kickedList = List<Map<String, dynamic>>.from((meta['kicked_teams'] as List?) ?? []);
        kickedList.removeWhere((k) => (k['slot'] as num?)?.toInt() == slotNumber);
        kickedList.insert(0, {
          'slot': slotNumber,
          'user_id': userId ?? '',
          'team_name': teamOrPlayerName,
          'reason': reason,
          'action': 'DISQUALIFIED ON LEADERBOARD (0 PTS)',
          'enforced_by': 'T69 Team',
          'role': 'T69 TEAM',
          'time': DateTime.now().toIso8601String(),
        });
        meta['kicked_teams'] = kickedList;

        // Broadcast warning to lobby chat
        final chatList = List<Map<String, dynamic>>.from(meta['chat'] ?? []);
        chatList.add({
          'sender': '🛡️ T69 TEAM SECURITY',
          'message': 'Slot #$slotNumber ($teamOrPlayerName) has been DISQUALIFIED & BANNED by T69 Team. Reason: $reason (0 Pts / Prize Blocked).',
          'isHost': true,
          'time': DateTime.now().toIso8601String(),
        });
        meta['chat'] = chatList;

        await _client.from('tournaments').update({
          'rules': jsonEncode(meta),
        }).eq('id', tournamentId);
      }
    } catch (e) {
      throw Exception('Failed to ban team: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// 13. Super-Admin / Host: Unban or Allow Player to Re-enter Lobby
  Future<void> unbanOrAllowPlayerRejoin({
    required String tournamentId,
    required String userId,
    String? gameUid,
  }) async {
    try {
      final tRes = await _client.from('tournaments').select('rules').eq('id', tournamentId).single();
      Map<String, dynamic> meta = {};
      final existingRules = tRes['rules']?.toString() ?? '';
      if (existingRules.trim().startsWith('{')) {
        try {
          meta = jsonDecode(existingRules) as Map<String, dynamic>;
        } catch (_) {}
      }

      final kickedList = List<Map<String, dynamic>>.from((meta['kicked_teams'] as List?) ?? []);
      kickedList.removeWhere((k) {
        final kUserId = k['user_id']?.toString();
        final kUid = k['game_uid']?.toString();
        return (userId.isNotEmpty && kUserId == userId) ||
            (gameUid != null && gameUid.isNotEmpty && kUid == gameUid.trim());
      });
      meta['kicked_teams'] = kickedList;

      await _client.from('tournaments').update({
        'rules': jsonEncode(meta),
      }).eq('id', tournamentId);
    } catch (e) {
      throw Exception('Failed to unban player: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // =========================================================================
  // 🌟 SUPER-ADMIN GOD-MODE CONTROL METHODS
  // =========================================================================

  /// 1. Create a brand new custom tournament / lobby from Admin Panel
  Future<TournamentModel> createAdminTournament({
    required String title,
    required String game,
    required double entryFee,
    required double prizePool,
    required double perKill,
    required String format,
    required String mapName,
    required int maxSlots,
    required DateTime startTime,
    String? bannerUrl,
  }) async {
    try {
      final res = await _client.from('tournaments').insert({
        'title': title.trim(),
        'game': game.trim(),
        'entry_fee': entryFee,
        'prize_pool': prizePool,
        'per_kill': perKill,
        'format': format.trim(),
        'map_name': mapName.trim(),
        'max_slots': maxSlots,
        'filled_slots': 0,
        'start_time': startTime.toIso8601String(),
        'status': 'open',
        'banner_url': bannerUrl?.trim() ?? 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80',
        'rules': jsonEncode({
          'created_by': 'SUPER_ADMIN',
          'chat': [
            {
              'sender': '👑 T69 SYSTEM',
              'message': 'Official Match Lobby initialized by T69 League Administration.',
              'isHost': true,
              'time': DateTime.now().toIso8601String(),
            }
          ]
        }),
      }).select().single();

      return TournamentModel.fromJson(res);
    } catch (e) {
      throw Exception('Failed to create tournament: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// 2. Update existing tournament details (Entry fee, Prize, Start Time, Map, Status)
  Future<void> updateTournamentDetails({
    required String tournamentId,
    String? title,
    double? entryFee,
    double? prizePool,
    double? perKill,
    DateTime? startTime,
    String? mapName,
    int? maxSlots,
    String? status,
    String? roomId,
    String? roomPassword,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (title != null) updates['title'] = title.trim();
      if (entryFee != null) updates['entry_fee'] = entryFee;
      if (prizePool != null) updates['prize_pool'] = prizePool;
      if (perKill != null) updates['per_kill'] = perKill;
      if (startTime != null) updates['start_time'] = startTime.toIso8601String();
      if (mapName != null) updates['map_name'] = mapName.trim();
      if (maxSlots != null) updates['max_slots'] = maxSlots;
      if (status != null) updates['status'] = status;
      if (roomId != null) updates['room_id'] = roomId.trim();
      if (roomPassword != null) updates['room_password'] = roomPassword.trim();

      if (updates.isNotEmpty) {
        await _client.from('tournaments').update(updates).eq('id', tournamentId);
      }
    } catch (e) {
      throw Exception('Failed to update tournament: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// 3. Emergency Cancel Tournament with 100% Automatic Refund to all registered players
  Future<int> cancelTournamentWithAutoRefund({
    required String tournamentId,
    required String reason,
  }) async {
    try {
      // 1. Fetch tournament details
      final tRes = await _client.from('tournaments').select().eq('id', tournamentId).single();
      final entryFee = (tRes['entry_fee'] as num?)?.toDouble() ?? 0.0;
      final tournamentTitle = tRes['title']?.toString() ?? 'Tournament';

      // 2. Fetch all registrations
      final regs = await _client.from('tournament_registrations').select('user_id, game_ign').eq('tournament_id', tournamentId);
      int refundedCount = 0;

      for (var reg in regs) {
        final userId = reg['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;

        if (entryFee > 0) {
          // Fetch current profile balance
          final profileRes = await _client.from('profiles').select('wallet_balance, deposit_balance').eq('id', userId).maybeSingle();
          if (profileRes != null) {
            final currentWallet = (profileRes['wallet_balance'] as num?)?.toDouble() ?? 0.0;
            final currentDeposit = (profileRes['deposit_balance'] as num?)?.toDouble() ?? 0.0;

            await _client.from('profiles').update({
              'wallet_balance': currentWallet + entryFee,
              'deposit_balance': currentDeposit + entryFee,
            }).eq('id', userId);

            // Log refund transaction
            await _client.from('wallet_transactions').insert({
              'user_id': userId,
              'amount': entryFee,
              'type': 'refund',
              'description': '⚡ 100% Auto-Refund: $tournamentTitle ($reason)',
              'status': 'completed',
            });
            refundedCount++;
          }
        }
      }

      // 3. Mark tournament as cancelled and clear slots
      await _client.from('tournaments').update({
        'status': 'cancelled',
        'filled_slots': 0,
      }).eq('id', tournamentId);

      return refundedCount;
    } catch (e) {
      throw Exception('Failed to cancel and refund match: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// 4. Delete tournament permanently
  Future<void> deleteTournament(String tournamentId) async {
    try {
      await _client.from('tournaments').delete().eq('id', tournamentId);
    } catch (e) {
      throw Exception('Failed to delete tournament: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// 5. Fetch all registered user profiles with search and sorting
  Future<List<Map<String, dynamic>>> getAllProfiles({String query = ''}) async {
    try {
      var dbQuery = _client.from('profiles').select();
      if (query.trim().isNotEmpty) {
        final q = '%${query.trim()}%';
        dbQuery = dbQuery.or('username.ilike.$q,full_name.ilike.$q,game_ign.ilike.$q,game_uid.ilike.$q');
      }
      final res = await dbQuery.order('created_at', ascending: false).limit(100);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw Exception('Failed to fetch player profiles: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// 6. Adjust user wallet balance (+ Credit or - Debit) with reason log
  Future<void> adjustUserWalletBalance({
    required String userId,
    required double amount, // positive for credit, negative for debit
    required String balanceType, // 'deposit' or 'winning'
    required String reason,
    required String adminName,
  }) async {
    try {
      final profile = await _client.from('profiles').select().eq('id', userId).single();
      final currentWallet = (profile['wallet_balance'] as num?)?.toDouble() ?? 0.0;
      final currentDeposit = (profile['deposit_balance'] as num?)?.toDouble() ?? 0.0;
      final currentWinning = (profile['winning_balance'] as num?)?.toDouble() ?? 0.0;

      double newWallet = currentWallet + amount;
      if (newWallet < 0) newWallet = 0;

      double newDeposit = currentDeposit;
      double newWinning = currentWinning;

      if (balanceType == 'winning') {
        newWinning = currentWinning + amount;
        if (newWinning < 0) newWinning = 0;
      } else {
        newDeposit = currentDeposit + amount;
        if (newDeposit < 0) newDeposit = 0;
      }

      await _client.from('profiles').update({
        'wallet_balance': newWallet,
        'deposit_balance': newDeposit,
        'winning_balance': newWinning,
      }).eq('id', userId);

      // Record transaction log
      await _client.from('wallet_transactions').insert({
        'user_id': userId,
        'amount': amount.abs(),
        'type': amount >= 0 ? 'bonus' : 'adjustment',
        'description': amount >= 0
            ? '💰 Admin Credit by $adminName: $reason (${balanceType.toUpperCase()})'
            : '🔻 Admin Debit by $adminName: $reason (${balanceType.toUpperCase()})',
        'status': 'completed',
      });
    } catch (e) {
      throw Exception('Failed to adjust wallet balance: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// 7. Toggle player verified status
  Future<void> toggleUserVerifiedBadge(String userId, bool isVerified) async {
    try {
      await _client.from('profiles').update({
        'is_verified': isVerified,
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update verified status: ${e.toString()}');
    }
  }

  /// 8. Toggle player ban / active role
  Future<void> toggleUserBanStatus(String userId, bool isBanned, {String? reason}) async {
    try {
      await _client.from('profiles').update({
        'role': isBanned ? 'banned' : 'player',
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update ban status: ${e.toString()}');
    }
  }

  /// 9. Delete banner
  Future<void> deleteBanner(String bannerId) async {
    try {
      await _client.from('banners').delete().eq('id', bannerId);
    } catch (e) {
      throw Exception('Failed to delete banner: ${e.toString()}');
    }
  }

  /// 10. Toggle banner active status
  Future<void> toggleBannerStatus(String bannerId, bool isActive) async {
    try {
      await _client.from('banners').update({
        'is_active': isActive,
      }).eq('id', bannerId);
    } catch (e) {
      throw Exception('Failed to update banner status: ${e.toString()}');
    }
  }

  /// 11. Fetch all banners for Admin Management (both active and inactive)
  Future<List<BannerModel>> getAllBannersForAdmin() async {
    try {
      final response = await _client
          .from('banners')
          .select()
          .order('order_index', ascending: true);
      return (response as List).map((json) => BannerModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 12. Super-Admin Revenue, P&L & Financial Ledger Engine
  Future<Map<String, dynamic>> fetchAdminRevenueAnalytics({String timeRange = 'ALL'}) async {
    try {
      // 1. Fetch all transactions with linked profiles
      final txRes = await _client
          .from('wallet_transactions')
          .select('*, profiles:user_id(username, full_name, game_ign, game_uid, wallet_balance, deposit_balance, winning_balance)')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> allTxs = List<Map<String, dynamic>>.from(txRes as List);

      // 2. Fetch all profiles for vault liability calculation
      final profileRes = await _client
          .from('profiles')
          .select('wallet_balance, deposit_balance, winning_balance');
      final List<Map<String, dynamic>> allProfiles = List<Map<String, dynamic>>.from(profileRes as List);

      double totalVaultLiability = 0.0;
      double totalDepositBalance = 0.0;
      double totalWinningBalance = 0.0;
      for (final p in allProfiles) {
        final dep = (p['deposit_balance'] as num?)?.toDouble() ?? 0.0;
        final win = (p['winning_balance'] as num?)?.toDouble() ?? 0.0;
        final tot = (p['wallet_balance'] as num?)?.toDouble() ?? (dep + win);
        totalDepositBalance += dep;
        totalWinningBalance += win;
        totalVaultLiability += tot;
      }

      // 3. Filter transactions based on time range
      final now = DateTime.now();
      DateTime? thresholdDate;
      if (timeRange == 'TODAY') {
        thresholdDate = DateTime(now.year, now.month, now.day);
      } else if (timeRange == 'WEEK') {
        thresholdDate = now.subtract(const Duration(days: 7));
      } else if (timeRange == 'MONTH') {
        thresholdDate = DateTime(now.year, now.month, 1);
      }

      final filteredTxs = allTxs.where((tx) {
        if (thresholdDate == null) return true;
        final createdAtStr = tx['created_at']?.toString();
        if (createdAtStr == null) return true;
        final txDate = DateTime.tryParse(createdAtStr)?.toLocal();
        if (txDate == null) return true;
        return txDate.isAfter(thresholdDate);
      }).toList();

      // 4. Calculate Financial Metrics
      double totalDepositsCompleted = 0.0;
      double totalDepositsPending = 0.0;
      double totalWithdrawalsCompleted = 0.0;
      double totalWithdrawalsPending = 0.0;
      double totalEntryFees = 0.0;
      double totalPrizes = 0.0;
      double totalRefunds = 0.0;
      double totalBonuses = 0.0;
      double totalAdjustments = 0.0;

      // Mode-specific aggregations
      double csEntries = 0.0;
      double csPrizes = 0.0;
      int csCount = 0;

      double soloEntries = 0.0;
      double soloPrizes = 0.0;
      int soloCount = 0;

      double duoEntries = 0.0;
      double duoPrizes = 0.0;
      int duoCount = 0;

      double squadEntries = 0.0;
      double squadPrizes = 0.0;
      int squadCount = 0;

      for (final tx in filteredTxs) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final type = (tx['type']?.toString() ?? '').toLowerCase();
        final status = (tx['status']?.toString() ?? '').toLowerCase();
        final desc = (tx['description']?.toString() ?? '').toLowerCase();

        if (type == 'deposit') {
          if (status == 'completed') {
            totalDepositsCompleted += amount;
          } else if (status == 'pending') {
            totalDepositsPending += amount;
          }
        } else if (type == 'withdrawal') {
          if (status == 'completed') {
            totalWithdrawalsCompleted += amount;
          } else if (status == 'pending') {
            totalWithdrawalsPending += amount;
          }
        } else if (type == 'tournament_entry') {
          if (status == 'completed') {
            totalEntryFees += amount;
            if (desc.contains('clash') || desc.contains('cs') || desc.contains('1v1') || desc.contains('2v2') || desc.contains('4v4')) {
              csEntries += amount;
              csCount++;
            } else if (desc.contains('solo')) {
              soloEntries += amount;
              soloCount++;
            } else if (desc.contains('duo')) {
              duoEntries += amount;
              duoCount++;
            } else if (desc.contains('squad')) {
              squadEntries += amount;
              squadCount++;
            } else {
              // Default to clash squad or solo
              csEntries += amount;
              csCount++;
            }
          }
        } else if (type == 'prize_credit') {
          if (status == 'completed') {
            totalPrizes += amount;
            if (desc.contains('clash') || desc.contains('cs') || desc.contains('1v1') || desc.contains('2v2') || desc.contains('4v4')) {
              csPrizes += amount;
            } else if (desc.contains('solo')) {
              soloPrizes += amount;
            } else if (desc.contains('duo')) {
              duoPrizes += amount;
            } else if (desc.contains('squad')) {
              squadPrizes += amount;
            } else {
              csPrizes += amount;
            }
          }
        } else if (type == 'refund') {
          if (status == 'completed') {
            totalRefunds += amount;
          }
        } else if (type == 'bonus') {
          if (status == 'completed') {
            totalBonuses += amount;
          }
        } else if (type == 'adjustment') {
          if (status == 'completed') {
            totalAdjustments += amount;
          }
        }
      }

      // Net calculations
      final matchOperatorProfit = totalEntryFees - totalPrizes;
      final matchProfitMargin = totalEntryFees > 0 ? (matchOperatorProfit / totalEntryFees) * 100 : 0.0;
      final netCashflow = totalDepositsCompleted - totalWithdrawalsCompleted;
      final netHousePosition = netCashflow - totalVaultLiability;

      return {
        'timeRange': timeRange,
        'totalDepositsCompleted': totalDepositsCompleted,
        'totalDepositsPending': totalDepositsPending,
        'totalWithdrawalsCompleted': totalWithdrawalsCompleted,
        'totalWithdrawalsPending': totalWithdrawalsPending,
        'totalEntryFees': totalEntryFees,
        'totalPrizes': totalPrizes,
        'totalRefunds': totalRefunds,
        'totalBonuses': totalBonuses,
        'totalAdjustments': totalAdjustments,
        'matchOperatorProfit': matchOperatorProfit,
        'matchProfitMargin': matchProfitMargin,
        'netCashflow': netCashflow,
        'totalVaultLiability': totalVaultLiability,
        'totalDepositBalance': totalDepositBalance,
        'totalWinningBalance': totalWinningBalance,
        'netHousePosition': netHousePosition,
        'totalUsersCount': allProfiles.length,
        'modeBreakdown': {
          'clashSquad': {
            'name': 'Clash Squad (1v1, 2v2, 4v4)',
            'entries': csEntries,
            'prizes': csPrizes,
            'profit': csEntries - csPrizes,
            'margin': csEntries > 0 ? ((csEntries - csPrizes) / csEntries) * 100 : 0.0,
            'count': csCount,
          },
          'soloBR': {
            'name': 'Solo Battle Royale',
            'entries': soloEntries,
            'prizes': soloPrizes,
            'profit': soloEntries - soloPrizes,
            'margin': soloEntries > 0 ? ((soloEntries - soloPrizes) / soloEntries) * 100 : 0.0,
            'count': soloCount,
          },
          'duoBR': {
            'name': 'Duo Battle Royale',
            'entries': duoEntries,
            'prizes': duoPrizes,
            'profit': duoEntries - duoPrizes,
            'margin': duoEntries > 0 ? ((duoEntries - duoPrizes) / duoEntries) * 100 : 0.0,
            'count': duoCount,
          },
          'squadBR': {
            'name': 'Squad Battle Royale',
            'entries': squadEntries,
            'prizes': squadPrizes,
            'profit': squadEntries - squadPrizes,
            'margin': squadEntries > 0 ? ((squadEntries - squadPrizes) / squadEntries) * 100 : 0.0,
            'count': squadCount,
          },
        },
        'ledger': filteredTxs,
      };
    } catch (e) {
      throw Exception('Failed to calculate revenue analytics: ${e.toString()}');
    }
  }
}


