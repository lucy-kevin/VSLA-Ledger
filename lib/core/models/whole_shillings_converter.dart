import 'package:freezed_annotation/freezed_annotation.dart';

/// Reads a money amount from JSON, refusing anything that is not a whole
/// number.
///
/// Without this, the generated code quietly cuts 10000.5 down to 10000. For
/// money we would rather fail loudly than lose half a shilling in silence.
class WholeShillingsConverter implements JsonConverter<int, Object> {
  const WholeShillingsConverter();

  @override
  int fromJson(Object json) {
    if (json is int) return json;
    throw FormatException(
      'A money amount must be a whole number of shillings, but got: $json',
    );
  }

  @override
  Object toJson(int amountUgx) => amountUgx;
}
