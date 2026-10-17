/// Parses provider "event channel" names of the form
///
///     NFL 03: Falcons vs Bears (10.18 1:00PM ET)
///     NHL 01: Sabres @ Maple Leafs [Sabres Feed] (10.15 7:00PM ET)
///     NFL 15: No Event Scheduled
///
/// into a kickoff instant and title so the TV Guide can show a synthetic
/// cell when the provider's XMLTV feed carries nothing for the channel.
///
/// Only names that carry an explicit "(MM.DD H:MMAM/PM ZONE)" suffix with a
/// recognised zone are parsed. The date is always read as month.day (the
/// observed provider format); there is no day.month detection. Anything else (for example "MLS 01: ... Oct 14
/// 7:30 PM" with no zone, or free-form titles) returns null so no event is
/// ever invented. "No Event" placeholders are reported as such and never
/// produce a programme.
class SportsEventNameParser {
  SportsEventNameParser({this.defaultDuration = const Duration(hours: 3)});

  /// Length used for the synthetic cell; providers do not publish an end time.
  final Duration defaultDuration;

  static final _slotPattern = RegExp(r'^([A-Z]{2,5})\s+(\d{1,3}):\s*(.*)$');
  static final _noEventPattern = RegExp(r'^no\s+event', caseSensitive: false);
  static final _kickoffPattern = RegExp(r'\((\d{1,2})\.(\d{1,2})\s+(\d{1,2}):(\d{2})\s*([AP]M)\s+([A-Z]{2,4})\)\s*$', caseSensitive: false);

  /// Zones the provider has been seen to use, with standard-time UTC offsets
  /// in hours. Two-letter forms ("ET") follow US daylight-saving rules; the
  /// explicit S/D forms are fixed. Ambiguous abbreviations (for example
  /// "AST", Atlantic or Arabia) are deliberately absent so they reject.
  static const _zones = <String, _Zone>{
    'ET': _Zone(-5, usDst: true),
    'EST': _Zone(-5),
    'EDT': _Zone(-4),
    'CT': _Zone(-6, usDst: true),
    'CST': _Zone(-6),
    'CDT': _Zone(-5),
    'MT': _Zone(-7, usDst: true),
    'MST': _Zone(-7),
    'MDT': _Zone(-6),
    'PT': _Zone(-8, usDst: true),
    'PST': _Zone(-8),
    'PDT': _Zone(-7),
    'UTC': _Zone(0),
    'GMT': _Zone(0),
  };

  /// [reference] anchors the month/day to a year: the candidate year whose
  /// date lies nearest the reference wins, so a December schedule parsed in
  /// January resolves to the previous year and vice versa.
  SportsEventInfo? parse(String name, {required DateTime reference}) {
    final slot = _slotPattern.firstMatch(name.trim());
    if (slot == null) return null;
    final league = slot.group(1)!;
    final slotNumber = int.parse(slot.group(2)!);
    final body = slot.group(3)!.trim();

    if (_noEventPattern.hasMatch(body)) {
      return SportsEventInfo.noEvent(league: league, slot: slotNumber, rawTitle: body);
    }

    final kick = _kickoffPattern.firstMatch(body);
    if (kick == null) return null;
    final zone = _zones[kick.group(6)!.toUpperCase()];
    if (zone == null) return null;

    final month = int.parse(kick.group(1)!);
    final day = int.parse(kick.group(2)!);
    var hour = int.parse(kick.group(3)!);
    final minute = int.parse(kick.group(4)!);
    final pm = kick.group(5)!.toUpperCase() == 'PM';
    if (month < 1 || month > 12 || day < 1 || day > 31 || hour < 1 || hour > 12 || minute > 59) return null;
    if (pm && hour != 12) hour += 12;
    if (!pm && hour == 12) hour = 0;

    final year = _nearestYear(month, day, reference);
    final wall = DateTime.utc(year, month, day, hour, minute);
    if (wall.month != month || wall.day != day) return null; // e.g. 2.30
    final offsetHours = zone.usDst && _isUsDaylight(wall) ? zone.standardOffsetHours + 1 : zone.standardOffsetHours;
    final startUtc = wall.subtract(Duration(hours: offsetHours));

    final title = body.substring(0, kick.start).trim();
    if (title.isEmpty) return null;

    return SportsEventInfo(
      league: league,
      slot: slotNumber,
      title: title,
      start: startUtc.toLocal(),
      end: startUtc.add(defaultDuration).toLocal(),
      zone: kick.group(6)!.toUpperCase(),
    );
  }

  static int _nearestYear(int month, int day, DateTime reference) {
    var best = reference.year;
    Duration? bestDiff;
    for (final y in [reference.year - 1, reference.year, reference.year + 1]) {
      final candidate = DateTime.utc(y, month, day);
      final diff = candidate.difference(DateTime.utc(reference.year, reference.month, reference.day)).abs();
      if (bestDiff == null || diff < bestDiff) {
        bestDiff = diff;
        best = y;
      }
    }
    return best;
  }

  /// US rule since 2007: DST from 02:00 local on the second Sunday of March
  /// to 02:00 local on the first Sunday of November. [wall] is local wall
  /// clock expressed as a UTC DateTime so no host-zone conversion happens.
  static bool _isUsDaylight(DateTime wall) {
    final start = _nthSunday(wall.year, 3, 2).add(const Duration(hours: 2));
    final end = _nthSunday(wall.year, 11, 1).add(const Duration(hours: 2));
    return !wall.isBefore(start) && wall.isBefore(end);
  }

  static DateTime _nthSunday(int year, int month, int n) {
    final first = DateTime.utc(year, month, 1);
    final offset = (DateTime.sunday - first.weekday) % 7;
    return DateTime.utc(year, month, 1 + offset + 7 * (n - 1));
  }
}

class _Zone {
  const _Zone(this.standardOffsetHours, {this.usDst = false});
  final int standardOffsetHours;
  final bool usDst;
}

class SportsEventInfo {
  const SportsEventInfo({required this.league, required this.slot, required this.title, required this.start, required this.end, required this.zone}) : isNoEvent = false;

  const SportsEventInfo.noEvent({required this.league, required this.slot, required String rawTitle})
      : title = rawTitle,
        start = null,
        end = null,
        zone = null,
        isNoEvent = true;

  final String league;
  final int slot;
  final String title;

  /// Local-time kickoff; null for "No Event" placeholders.
  final DateTime? start;
  final DateTime? end;

  /// Zone abbreviation as written in the name, null for placeholders.
  final String? zone;
  final bool isNoEvent;

  bool get hasKickoff => start != null && end != null;
}
