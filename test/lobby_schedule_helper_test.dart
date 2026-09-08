import 'package:flutter_test/flutter_test.dart';
import 'package:t69esports/features/tournaments/utils/lobby_schedule_helper.dart';
import 'package:t69esports/features/tournaments/models/tournament_model.dart';

void main() {
  group('LobbyScheduleHelper Tests', () {
    test('getActiveUpcomingSlot calculates correct 12AM, 12PM, 3PM, 6PM, 9PM daily slots', () {
      // 10:00 AM -> next slot is 12:00 PM
      final t1 = DateTime(2026, 9, 8, 10, 0);
      expect(LobbyScheduleHelper.getActiveUpcomingSlot(t1), DateTime(2026, 9, 8, 12, 0));

      // 1:30 PM (13:30) -> next slot is 3:00 PM (15:00)
      final t2 = DateTime(2026, 9, 8, 13, 30);
      expect(LobbyScheduleHelper.getActiveUpcomingSlot(t2), DateTime(2026, 9, 8, 15, 0));

      // 4:45 PM (16:45) -> next slot is 6:00 PM (18:00)
      final t3 = DateTime(2026, 9, 8, 16, 45);
      expect(LobbyScheduleHelper.getActiveUpcomingSlot(t3), DateTime(2026, 9, 8, 18, 0));

      // 7:15 PM (19:15) -> next slot is 9:00 PM (21:00)
      final t4 = DateTime(2026, 9, 8, 19, 15);
      expect(LobbyScheduleHelper.getActiveUpcomingSlot(t4), DateTime(2026, 9, 8, 21, 0));

      // 10:00 PM (22:00) -> next slot is 12:00 AM (00:00) tomorrow
      final t5 = DateTime(2026, 9, 8, 22, 0);
      expect(LobbyScheduleHelper.getActiveUpcomingSlot(t5), DateTime(2026, 9, 9, 0, 0));
    });

    test('getNextSlotAfter transitions sequentially across all 5 slots', () {
      final slot12am = DateTime(2026, 9, 8, 0, 0);
      final slot12pm = LobbyScheduleHelper.getNextSlotAfter(slot12am);
      expect(slot12pm, DateTime(2026, 9, 8, 12, 0));

      final slot3pm = LobbyScheduleHelper.getNextSlotAfter(slot12pm);
      expect(slot3pm, DateTime(2026, 9, 8, 15, 0));

      final slot6pm = LobbyScheduleHelper.getNextSlotAfter(slot3pm);
      expect(slot6pm, DateTime(2026, 9, 8, 18, 0));

      final slot9pm = LobbyScheduleHelper.getNextSlotAfter(slot6pm);
      expect(slot9pm, DateTime(2026, 9, 8, 21, 0));

      final nextDay12am = LobbyScheduleHelper.getNextSlotAfter(slot9pm);
      expect(nextDay12am, DateTime(2026, 9, 9, 0, 0));
    });

    test('formatSlotTime formats properly in 12-hour AM/PM', () {
      expect(LobbyScheduleHelper.formatSlotTime(DateTime(2026, 9, 8, 0, 0)), '12:00 AM');
      expect(LobbyScheduleHelper.formatSlotTime(DateTime(2026, 9, 8, 12, 0)), '12:00 PM');
      expect(LobbyScheduleHelper.formatSlotTime(DateTime(2026, 9, 8, 15, 0)), '03:00 PM');
      expect(LobbyScheduleHelper.formatSlotTime(DateTime(2026, 9, 8, 18, 0)), '06:00 PM');
      expect(LobbyScheduleHelper.formatSlotTime(DateTime(2026, 9, 8, 21, 0)), '09:00 PM');
    });

    test('isLobbyVisibleToUser hides locked/live/completed lobbies for non-registered users', () {
      final openLobby = TournamentModel(
        id: 't-open',
        title: 'Solo Rush',
        game: 'FREE FIRE',
        bannerUrl: '',
        startTime: DateTime.now().add(const Duration(hours: 2)),
        status: 'open',
      );

      final liveLobby = TournamentModel(
        id: 't-live',
        title: 'Solo Rush',
        game: 'FREE FIRE',
        bannerUrl: '',
        startTime: DateTime.now().subtract(const Duration(minutes: 10)),
        status: 'live',
      );

      final completedLobby = TournamentModel(
        id: 't-done',
        title: 'Solo Rush',
        game: 'FREE FIRE',
        bannerUrl: '',
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        status: 'completed',
      );

      final fullLobby = TournamentModel(
        id: 't-full',
        title: 'Solo Rush',
        game: 'FREE FIRE',
        bannerUrl: '',
        startTime: DateTime.now().add(const Duration(hours: 2)),
        status: 'open',
        maxSlots: 48,
        filledSlots: 48,
      );

      // Non-registered user
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: openLobby, isUserRegistered: false), true);
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: fullLobby, isUserRegistered: false), false);
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: liveLobby, isUserRegistered: false), false);
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: completedLobby, isUserRegistered: false), false);

      // Registered user (always true even if full/live/completed)
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: openLobby, isUserRegistered: true), true);
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: fullLobby, isUserRegistered: true), true);
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: liveLobby, isUserRegistered: true), true);
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: completedLobby, isUserRegistered: true), true);
    });

    test('getActiveMatchSlot correctly keeps current slot until 30 minutes after start time', () {
      // 10:00 AM -> active slot is 12:00 PM today
      final t1 = DateTime(2026, 9, 8, 10, 0);
      expect(LobbyScheduleHelper.getActiveMatchSlot(t1), DateTime(2026, 9, 8, 12, 0));

      // 12:15 PM (15 mins after 12:00 PM start) -> STILL 12:00 PM (Late Entry Active)
      final t2 = DateTime(2026, 9, 8, 12, 15);
      expect(LobbyScheduleHelper.getActiveMatchSlot(t2), DateTime(2026, 9, 8, 12, 0));

      // 12:35 PM (35 mins after 12:00 PM start, cutoff 12:30 passed) -> advances to 3:00 PM today
      final t3 = DateTime(2026, 9, 8, 12, 35);
      expect(LobbyScheduleHelper.getActiveMatchSlot(t3), DateTime(2026, 9, 8, 15, 0));
    });

    test('Parallel multi-lobbies before 12:00 PM share the 12:00 PM match time', () {
      final now10am = DateTime(2026, 9, 8, 10, 0);

      // Lobby #1 (Full)
      final lobby1 = TournamentModel(
        id: 't-1',
        title: 'FF Solo Rush - Lobby #1 (Rs 15)',
        game: 'FREE FIRE',
        bannerUrl: '',
        startTime: DateTime(2026, 9, 8, 12, 0),
        status: 'open',
        maxSlots: 48,
        filledSlots: 48,
      );

      // Lobby #2 (Open for next players)
      final lobby2 = TournamentModel(
        id: 't-2',
        title: 'FF Solo Rush - Lobby #2 (Rs 15)',
        game: 'FREE FIRE',
        bannerUrl: '',
        startTime: DateTime(2026, 9, 8, 15, 0), // raw DB had 3pm
        status: 'open',
        maxSlots: 48,
        filledSlots: 0,
      );

      // Effective start time for Lobby #2 before 12:00 PM is 12:00 PM!
      expect(LobbyScheduleHelper.getEffectiveStartTime(lobby2, now10am), DateTime(2026, 9, 8, 12, 0));

      // For non-registered player:
      // Lobby #1 (Full) is hidden
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: lobby1, isUserRegistered: false, fromTime: now10am), false);
      // Lobby #2 is visible and displayed at 12:00 PM!
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: lobby2, isUserRegistered: false, fromTime: now10am), true);
    });

    test('isLobbyExpiredUnbooked correctly detects deserted lobbies after 30 minutes', () {
      final matchTime = DateTime(2026, 9, 8, 12, 0); // 12:00 PM

      final emptyLobby = TournamentModel(
        id: 't-empty',
        title: 'Solo Rush',
        game: 'FREE FIRE',
        bannerUrl: '',
        startTime: matchTime,
        status: 'open',
        filledSlots: 0,
      );

      final bookedLobby = TournamentModel(
        id: 't-booked',
        title: 'Solo Rush',
        game: 'FREE FIRE',
        bannerUrl: '',
        startTime: matchTime,
        status: 'open',
        filledSlots: 3,
      );

      // At 12:20 PM (20 minutes after start) -> NOT expired yet (still allows bookings)
      final time1220 = DateTime(2026, 9, 8, 12, 20);
      expect(LobbyScheduleHelper.isLobbyExpiredUnbooked(emptyLobby, time1220), false);
      expect(LobbyScheduleHelper.isLateEntryAllowed(emptyLobby, time1220), true);
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: emptyLobby, isUserRegistered: false, fromTime: time1220), true);

      // At 12:35 PM (35 minutes after start) -> EXPIRED for empty lobby
      final time1235 = DateTime(2026, 9, 8, 12, 35);
      expect(LobbyScheduleHelper.isLobbyExpiredUnbooked(emptyLobby, time1235), true);
      expect(LobbyScheduleHelper.isLateEntryAllowed(emptyLobby, time1235), false);
      // Empty lobby disappears from user feed
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: emptyLobby, isUserRegistered: false, fromTime: time1235), false);

      // But a booked lobby with players at 12:35 PM is NOT unbooked expired
      expect(LobbyScheduleHelper.isLobbyExpiredUnbooked(bookedLobby, time1235), false);
      expect(LobbyScheduleHelper.isLateEntryAllowed(bookedLobby, time1235), true);
      expect(LobbyScheduleHelper.isLobbyVisibleToUser(tournament: bookedLobby, isUserRegistered: false, fromTime: time1235), true);
    });
  });
}
