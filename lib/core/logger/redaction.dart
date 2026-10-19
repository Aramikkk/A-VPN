import 'package:logging/logging.dart';

// Subscription credentials can live anywhere in a URL, including its path.
// Retain only the scheme and host for diagnosis; never log userinfo or tokens.
final _urls = RegExp(r'''[a-zA-Z][a-zA-Z0-9+.-]*://[^\s<>"\'\)\]]+''');

String redactLogText(String text) => text.replaceAllMapped(_urls, (match) {
  final uri = Uri.tryParse(match[0]!);
  if (uri == null || uri.host.isEmpty) return '[redacted URL]';
  return '${uri.scheme}://${uri.host}/REDACTED';
});

LogRecord redactLogRecord(LogRecord record) {
  Object? clean(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    final redacted = redactLogText(text);
    return redacted == text ? value : redacted;
  }

  return _RedactedRecord(record, clean(record.error), clean(record.object));
}

class _RedactedRecord extends LogRecord {
  _RedactedRecord(LogRecord source, Object? error, Object? object)
    : _time = source.time,
      _sequenceNumber = source.sequenceNumber,
      super(
        source.level,
        redactLogText(source.message),
        source.loggerName,
        error,
        source.stackTrace == null ? null : StackTrace.fromString(redactLogText(source.stackTrace.toString())),
        source.zone,
        object,
      );

  // Preserve the original record time and ordering when sanitizing at a sink.
  final DateTime _time;
  final int _sequenceNumber;
  @override
  DateTime get time => _time;
  @override
  int get sequenceNumber => _sequenceNumber;
}
