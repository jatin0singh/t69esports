import 'package:intl/intl.dart';
import '../models/tournament_model.dart';

class LobbyScheduleHelper {
  /// Standard 5 daily match slot hours (in 24-hour local format):
  /// 0: 12:00 AM (Midnight)
  /// 12: 12:00 PM (Noon)
  /// 15: 3:00 PM (Afternoon)
  /// 18: 6:00 PM (Evening)
  /// 21: 9:00 PM (Night)
  static const List<int> dailySlotHours = [0, 12, 15, 18, 21];

  /// Get the active match schedule time slot for any given time.
  /// Each slot remains active until 30 minutes after its start time:
  /// - 00:30 to 12:30 -> 12:00 PM Today
  /// - 12:30 to 15:30 -> 03:00 PM Today
  /// - 15:30 to 18:30 -> 06:00 PM Today
  /// - 18:30 to 21:30 -> 09:00 PM Today
  /// - 21:30 to 00:30 (next day) -> 12:00 AM (Midnight)
  static DateTime getActiveMatchSlot([DateTime? fromTime]) {
    final now = fromTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final hour in dailySlotHours) {
      final slotTime = today.add(Duration(hours: hour));
      final slotCutoff = slotTime.add(const Duration(minutes: 30));
      if (now.isBefore(slotCutoff)) {
        return slotTime;
      }
    }

    // Past 21:30 (9:30 PM), active slot is 00:00 (12:00 AM) tomorrow
    return today.add(const Duration(days: 1));
  }

  /// Alias for backward compatibility
  static DateTime getActiveUpcomingSlot([DateTime? fromTime]) => getActiveMatchSlot(fromTime);

  /// Get the next upcoming slot after a given slot time
  static DateTime getNextSlotAfter(DateTime currentSlot) {
    final hour = currentSlot.hour;
    final day = DateTime(currentSlot.year, currentSlot.month, currentSlot.day);

    final currentIndex = dailySlotHours.indexOf(hour);
    if (currentIndex != -1 && currentIndex < dailySlotHours.length - 1) {
      return day.add(Duration(hours: dailySlotHours[currentIndex + 1]));
    }

    // Next day's first slot (12:00 AM / 00:00)
    return day.add(const Duration(days: 1));
  }

  /// Returns the effective scheduled start time for a lobby:
  /// - If the tournament is already completed, live, or has registered players (filledSlots > 0),
  ///   its assigned startTime is preserved.
  /// - If the tournament is open and unbooked (filledSlots == 0),
  ///   its match time dynamically aligns to the active match schedule slot (e.g. 12:00 PM),
  ///   ensuring all parallel lobbies before 12:00 PM share the 12:00 PM schedule.
  static DateTime getEffectiveStartTime(TournamentModel tournament, [DateTime? fromTime]) {
    final status = tournament.status.toLowerCase();
    if (status == 'completed' || status == 'live' || tournament.isIdpLocked) {
      return tournament.startTime;
    }
    if (tournament.filledSlots > 0) {
      return tournament.startTime;
    }

    return getActiveMatchSlot(fromTime);
  }

  /// Get all 5 daily slots starting from today
  static List<DateTime> getUpcomingSlotsList({int count = 5}) {
    final List<DateTime> list = [];
    var current = getActiveMatchSlot();
    while (list.length < count) {
      list.add(current);
      current = getNextSlotAfter(current);
    }
    return list;
  }

  /// Formats slot time into clean 12-hour format e.g. "12:00 AM", "03:00 PM"
  static String formatSlotTime(DateTime time) {
    return DateFormat('hh:mm a').format(time.toLocal());
  }

  /// Full formatted string e.g. "Today • 03:00 PM" or "Tomorrow • 12:00 AM"
  static String formatSlotWithDay(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localTime = time.toLocal();
    final targetDay = DateTime(localTime.year, localTime.month, localTime.day);

    final diff = targetDay.difference(today).inDays;
    final timeStr = formatSlotTime(localTime);

    if (diff == 0) {
      return 'Today • $timeStr';
    } else if (diff == 1) {
      return 'Tomorrow • $timeStr';
    } else {
      return '${DateFormat('dd MMM').format(localTime)} • $timeStr';
    }
  }

  /// Returns true if match scheduled time has passed by >= 30 minutes and 0 slots were booked,
  /// meaning this unbooked lobby is automatically expired and must disappear from user feed.
  static bool isLobbyExpiredUnbooked(TournamentModel tournament, [DateTime? fromTime]) {
    // Only applies if nobody booked a slot
    if (tournament.filledSlots > 0) return false;

    final status = tournament.status.toLowerCase();
    if (status == 'completed' || status == 'cancelled') return true;

    final now = fromTime ?? DateTime.now();
    final expiryTime = tournament.startTime.toLocal().add(const Duration(minutes: 30));
    return now.isAfter(expiryTime);
  }

  /// Checks if a lobby's match time has passed, but host hasn't started/locked it yet
  /// meaning late players are still permitted to purchase remaining slots
  static bool isLateEntryAllowed(TournamentModel tournament, [DateTime? fromTime]) {
    if (tournament.isIdpLocked) return false;
    final status = tournament.status.toLowerCase();
    if (status != 'open') return false;
    if (tournament.filledSlots >= tournament.maxSlots) return false;

    // Unbooked lobbies (0 players after 30 mins) expire and cannot accept late entry
    if (isLobbyExpiredUnbooked(tournament, fromTime)) return false;

    final now = fromTime ?? DateTime.now();
    return now.isAfter(tournament.startTime.toLocal());
  }

  /// Determines if a lobby should be visible to a specific user
  static bool isLobbyVisibleToUser({
    required TournamentModel tournament,
    required bool isUserRegistered,
    DateTime? fromTime,
  }) {
    // If player purchased a slot in this lobby, it is ALWAYS visible
    if (isUserRegistered) return true;

    // If player did NOT purchase a slot:

    // 1. If lobby is FULL (all slots booked) -> hide from non-registered players
    if (tournament.filledSlots >= tournament.maxSlots) {
      return false;
    }

    // 2. If not even one slot is booked after 30 minutes of lobby time,
    // the lobby disappears and next timing lobby comes
    if (isLobbyExpiredUnbooked(tournament, fromTime)) {
      return false;
    }

    // 3. Hide if lobby is live/locked or completed or cancelled
    final isLiveOrLocked = (tournament.status.toLowerCase() == 'live') ||
        (tournament.isIdpLocked && tournament.isClaimed);
    final isCompleted = tournament.status.toLowerCase() == 'completed';
    final isCancelled = tournament.status.toLowerCase() == 'cancelled';

    if (isLiveOrLocked || isCompleted || isCancelled) {
      return false;
    }

    return true;
  }
}
