/// Money handling for the app.
///
/// **Money is `int` whole rupees.** The business does not deal in paise: daily
/// wages, kharchi and settlements are always whole rupees, and every screen has
/// always rendered `toStringAsFixed(0)`. Representing them as `double` bought
/// nothing and risked accumulating binary-floating-point drift across the
/// repeated `salary - advances` arithmetic — in an app whose entire job is
/// "what do I owe you", that is the wrong trade.
///
/// Firestore stores these as its normal `number` type. Existing documents that
/// were written as doubles (`650.0`) read back correctly through [asRupees],
/// so **no data migration is required**.
///
/// The only place a fraction legitimately appears is *days worked* (half days
/// are `0.5`), so salary is computed as `double` and rounded once, at the edge,
/// via [roundRupees].
library;

/// Reads a money value out of an untyped Firestore field.
///
/// Handles `int`, `double`, numeric strings and null/garbage (→ 0). Never
/// throws: Firestore documents are not schema-enforced and one malformed
/// document must not take down the payroll screen.
int asRupees(Object? raw) {
  if (raw is int) return raw;
  if (raw is double) return raw.isFinite ? raw.round() : 0;
  if (raw is num) return raw.round();
  if (raw is String) {
    final parsed = num.tryParse(raw.trim());
    if (parsed != null && parsed.isFinite) return parsed.round();
  }
  return 0;
}

/// Reads a fractional day count (`1.0`, `0.5`) out of an untyped field.
double asDays(Object? raw) {
  if (raw is num) return raw.isFinite ? raw.toDouble() : 0;
  if (raw is String) {
    final parsed = double.tryParse(raw.trim());
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return 0;
}

/// Rounds a computed amount to whole rupees (half away from zero).
///
/// Used where a half day produces a `.5` rupee amount — e.g. 2.5 days at ₹655
/// is ₹1637.50, which is banked as ₹1638.
int roundRupees(double value) => value.isFinite ? value.round() : 0;

/// Indian digit grouping: `100000` → `1,00,000`.
///
/// Last three digits, then groups of two. Handles negatives.
String groupIndian(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  if (digits.length <= 3) return negative ? '-$digits' : digits;

  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);

  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);

  final grouped = '${groups.join(',')},$last3';
  return negative ? '-$grouped' : grouped;
}

/// Display form with the rupee sign: `₹1,00,000`, `-₹500`.
String rupees(int value) =>
    value < 0 ? '-₹${groupIndian(-value)}' : '₹${groupIndian(value)}';

/// Unformatted rupee digits for CSV/export: `100000`, `-500`.
String rupeesPlain(int value) => value.toString();

/// Days worked, trimmed: `22`, `22.5`.
String formatDays(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

/// Daily-rate label for a period: `₹600/day`, or `₹600–₹650/day` when the rate
/// changed part-way through it.
///
/// [rates] must be ascending and distinct — the rates actually applied to worked
/// days. [fallback] is used when no days were worked, so the card still shows
/// what the rate *was* rather than nothing.
///
/// Screens showing a specific month must use this rather than
/// `worker.dailyWage`: a July card labelled with today's rate contradicts its
/// own salary figure, which reads as a bug even when the arithmetic is right.
String rateLabel(List<int> rates, {required int fallback}) {
  if (rates.isEmpty) return '${rupees(fallback)}/day';
  if (rates.length == 1) return '${rupees(rates.single)}/day';
  return '${rupees(rates.first)}–${rupees(rates.last)}/day';
}
