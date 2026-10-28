/// The time now, in UTC, rounded down to the millisecond.
///
/// Phones measure time in microseconds, but servers such as PocketBase keep
/// only milliseconds. Rounding here, where records are made, means a record
/// is exactly the same on every phone and on every server.
DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch,
  isUtc: true,
);

/// The calendar day of [moment], with no time of day, as UTC midnight.
///
/// A meeting is a day, not a moment. Using UTC midnight for every day means
/// the same day is the same value on every phone and every server.
DateTime dateOnly(DateTime moment) =>
    DateTime.utc(moment.year, moment.month, moment.day);
