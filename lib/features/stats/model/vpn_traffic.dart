import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

/// Traffic that went through the provider's servers, which A-VPN's core sends as extra SystemInfo fields
/// (100: uplink, 101: downlink) that the generated code doesn't know. Null with a core that doesn't send them.
extension VpnTraffic on SystemInfo {
  static const _uplinkField = 100;
  static const _downlinkField = 101;

  int? get vpnUplinkTotal => _unknownVarint(_uplinkField);

  int? get vpnDownlinkTotal => _unknownVarint(_downlinkField);

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
  final text = unit == 0 || value >= 100 ? value.round().toString() : value.toStringAsFixed(1);
  return '${text.replaceAll('.', decimalSeparator)} ${units[unit]}';
}
