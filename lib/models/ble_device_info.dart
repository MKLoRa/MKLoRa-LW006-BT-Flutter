import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String hexString(List<int> data) {
  return data
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

class BleDeviceInfo {
  final DeviceIdentifier id;
  final String name;
  final String macAddress;
  final int rssi;
  final int? txPowerLevel;
  final int deviceType;
  final int workMode;
  final int batteryPercent;
  final int batteryVoltageMv;
  final bool passwordEnabled;
  final List<int> rawServiceData;
  final int lastScanMs;
  final int scanIntervalMs;

  BleDeviceInfo({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    required this.txPowerLevel,
    required this.deviceType,
    required this.workMode,
    required this.batteryPercent,
    required this.batteryVoltageMv,
    required this.passwordEnabled,
    required this.rawServiceData,
    this.lastScanMs = 0,
    this.scanIntervalMs = 0,
  });

  /// MAC from advertisement Service Data (0xAA0D), not [id] / CoreBluetooth UUID.
  String get advMacAddress =>
      macAddress.isNotEmpty ? macAddress : macFromAdvServiceData(rawServiceData);

  String get scanIntervalLabel =>
      scanIntervalMs == 0 ? '<->N/A' : '<->${scanIntervalMs}ms';

  BleDeviceInfo copyWith({
    DeviceIdentifier? id,
    String? name,
    String? macAddress,
    int? rssi,
    int? txPowerLevel,
    int? deviceType,
    int? workMode,
    int? batteryPercent,
    int? batteryVoltageMv,
    bool? passwordEnabled,
    List<int>? rawServiceData,
    int? lastScanMs,
    int? scanIntervalMs,
  }) {
    return BleDeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      txPowerLevel: txPowerLevel ?? this.txPowerLevel,
      deviceType: deviceType ?? this.deviceType,
      workMode: workMode ?? this.workMode,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryVoltageMv: batteryVoltageMv ?? this.batteryVoltageMv,
      passwordEnabled: passwordEnabled ?? this.passwordEnabled,
      rawServiceData: rawServiceData ?? this.rawServiceData,
      lastScanMs: lastScanMs ?? this.lastScanMs,
      scanIntervalMs: scanIntervalMs ?? this.scanIntervalMs,
    );
  }

  static bool _isLw006AdvUuid(Guid uuid) {
    return uuid.toString().toLowerCase().contains('aa0d');
  }

  static List<int>? _lw006AdvPayload(AdvertisementData adv) {
    for (final entry in adv.serviceData.entries) {
      if (_isLw006AdvUuid(entry.key) && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    for (final data in adv.serviceData.values) {
      if (data.length >= 8) {
        return data;
      }
    }
    return null;
  }

  /// Parses the 6-byte MAC embedded in LW006 advertisement Service Data.
  static String macFromAdvServiceData(List<int> data) {
    if (data.length < 8) {
      return '';
    }

    var offset = 2;
    if (data.length >= 10 && data[0] == 0xAA && data[1] == 0x0D) {
      offset = 4;
    }
    if (data.length < offset + 6) {
      return '';
    }

    return data
        .sublist(offset, offset + 6)
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  static BleDeviceInfo? fromScanResult(ScanResult result) {
    final adv = result.advertisementData;
    final data = _lw006AdvPayload(adv);
    if (data == null || data.length < 8) {
      return null;
    }

    final payloadOffset =
        (data.length >= 10 && data[0] == 0xAA && data[1] == 0x0D) ? 2 : 0;
    final deviceType = data[payloadOffset] & 0xFF;
    final txPower = data.length > payloadOffset + 8 ? data[payloadOffset + 8] : adv.txPowerLevel;
    final batteryPercent =
        data.length > payloadOffset + 9 ? data[payloadOffset + 9] & 0xFF : 0;
    final batteryVoltageMv = data.length > payloadOffset + 11
        ? ((data[payloadOffset + 10] & 0xFF) << 8) | (data[payloadOffset + 11] & 0xFF)
        : 0;
    final statusByte =
        data.length > payloadOffset + 12 ? data[payloadOffset + 12] & 0xFF : 0;
    final passwordEnabled = ((statusByte >> 7) & 0x01) == 1;
    final workMode = statusByte & 0x7F;

    return BleDeviceInfo(
      id: result.device.remoteId,
      name: adv.advName.isNotEmpty ? adv.advName : result.device.advName,
      macAddress: macFromAdvServiceData(data),
      rssi: result.rssi,
      txPowerLevel: txPower,
      deviceType: deviceType,
      workMode: workMode,
      batteryPercent: batteryPercent,
      batteryVoltageMv: batteryVoltageMv,
      passwordEnabled: passwordEnabled,
      rawServiceData: data,
    );
  }
}
