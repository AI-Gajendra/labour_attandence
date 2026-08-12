/// Shared date / month key helpers.
///
/// Two string formats are persisted in Firestore and must never drift:
///   * **dateKey**  — `YYYY-MM-DD`, used for `date` fields and as half of the
///     composite attendance document id (`{workerId}_{dateKey}`).
///   * **monthKey** — `YYYY-MM`, used for `month` fields and as half of the
///     settlement document id (`{workerId}_{monthKey}`).
///
/// All dates are **device-local**. There is deliberately no timezone handling —
/// a working day is whatever the phone in the contractor's pocket says it is.
library;

const List<String> kMonthsShort = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

const List<String> kMonthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> kWeekdaysLong = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

/// Zero-padded two-digit string. `7` → `'07'`.
String two(int n) => n.toString().padLeft(2, '0');

// ── Keys ──

/// `YYYY-MM-DD` for a local date.
String dateKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// `YYYY-MM` for a local date.
String monthKey(DateTime d) => '${d.year}-${two(d.month)}';

/// Extracts `YYYY-MM` from a `YYYY-MM-DD` key. Returns the input unchanged if
/// it is not long enough to contain a month.
String monthKeyOfDateKey(String key) =>
    key.length >= 7 ? key.substring(0, 7) : key;

/// Parses a `YYYY-MM-DD` key. Returns null on anything malformed rather than
/// throwing — Firestore documents are not schema-enforced.
DateTime? parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

/// Day-of-month from a `YYYY-MM-DD` key, or null if malformed.
int? dayOfDateKey(String key) => parseDateKey(key)?.day;

/// Parses a `YYYY-MM` key to the first day of that month.
DateTime? parseMonthKey(String key) {
  final parts = key.split('-');
  if (parts.length < 2) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (y == null || m == null || m < 1 || m > 12) return null;
  return DateTime(y, m);
}

/// The `YYYY-MM` key of the month before [key]. Returns [key] if unparseable.
String previousMonthKey(String key) {
  final d = parseMonthKey(key);
  if (d == null) return key;
  return monthKey(addMonths(d, -1));
}

// ── Arithmetic ──

/// First day of [d]'s month, time cleared.
DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month);

/// [d]'s month shifted by [delta] months (negative shifts backwards).
DateTime addMonths(DateTime d, int delta) => DateTime(d.year, d.month + delta);

/// Number of days in [d]'s month.
int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// True when [a] and [b] are the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ── Display ──

/// `MONDAY, AUG 11, 2026`
String displayFullDate(DateTime d) =>
    '${kWeekdaysLong[d.weekday - 1]}, ${kMonthsShort[d.month - 1]} ${d.day}, ${d.year}';

/// `August 2026`
String displayMonthLong(DateTime d) => '${kMonthsLong[d.month - 1]} ${d.year}';

/// `11 AUG 2026`
String displayDayMonth(DateTime d) =>
    '${d.day} ${kMonthsShort[d.month - 1]} ${d.year}';

/// `11 AUG 2026` from a `YYYY-MM-DD` key; falls back to the raw key.
String displayDateKey(String key) {
  final d = parseDateKey(key);
  return d == null ? key : displayDayMonth(d);
}

/// `11 Aug 2026, 14:05` from a [DateTime].
String displayTimestamp(DateTime d) {
  final month = kMonthsShort[d.month - 1];
  final pretty = month[0] + month.substring(1).toLowerCase();
  return '${d.day} $pretty ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}
