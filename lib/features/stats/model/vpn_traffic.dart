import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

/// Traffic that went through the provider's servers, which A-VPN's core sends as extra SystemInfo fields
/// (100: uplink, 101: downlink, 102: session start) that the generated code doesn't know. Null with a core that doesn't send them.
extension VpnTraffic on SystemInfo {
  static const _uplinkField = 100;
  static const _downlinkField = 101;
  static const _startedAtField = 102;

  int? get vpnUplinkTotal => _unknownVarint(_uplinkField);

  int? get vpnDownlinkTotal => _unknownVarint(_downlinkField);

  /// When the VPN session started (field 102); reloads on a network or server change keep it.
  DateTime? get sessionStartedAt {
    final ms = _unknownVarint(_startedAtField);
    return ms == null || ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  int? _unknownVarint(int field) {
    final values = unknownFields.getField(field)?.varints;
    return values == null || values.isEmpty ? null : values.last.toInt();
  }
}

/// "12,4 МБ" with [units] such as Б, КБ, МБ, ГБ, ТБ; one decimal under 100, none above.
String formatBytes(int bytes, List<String> units, {String decimalSeparator = ','}) {
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  var text = unit == 0 || value >= 100 ? value.round().toString() : value.toStringAsFixed(1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2); // "10 МБ", not "10,0 МБ"
  return '${text.replaceAll('.', decimalSeparator)} ${units[unit]}';
}
