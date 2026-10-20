/// The time now, in UTC, rounded down to the millisecond.
///
/// Phones measure time in microseconds, but servers such as PocketBase keep
/// only milliseconds. Rounding here, where records are made, means a record
/// is exactly the same on every phone and on every server.
DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch,
  isUtc: true,
);
