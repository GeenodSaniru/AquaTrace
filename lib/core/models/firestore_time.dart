import 'package:cloud_firestore/cloud_firestore.dart';

/// Parses the timestamp representations that can appear in AquaTrace
/// documents.
///
/// Client code historically wrote ISO-8601 strings, while trusted backend
/// code (Cloud Functions / Admin SDK) writes native Firestore `Timestamp`
/// values. Both - plus [DateTime] and epoch milliseconds - are accepted so a
/// document written by either side renders correctly.
///
/// Returns `null` when the value is missing or cannot be interpreted. Callers
/// must decide how to present an unknown time; they should never silently
/// substitute "now", because that would reorder history.
DateTime? parseFirestoreTime(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    if (value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }
  return null;
}

/// Sentinel used for records whose time is unknown. It sorts before every real
/// record, so unknown entries sink to the end of newest-first lists and the
/// start of oldest-first timelines.
final DateTime unknownTime = DateTime.fromMillisecondsSinceEpoch(
  0,
  isUtc: true,
);

/// Whether [value] is a real time rather than the [unknownTime] sentinel.
bool isKnownTime(DateTime value) => value.millisecondsSinceEpoch > 0;
