import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/ble_device_info.dart';
import 'lw006_ble_client.dart';
import 'lw006_export_data_store.dart';
import 'lw006_protocol_api.dart';

class Lw006DeviceSession {
  Lw006DeviceSession._({
    required this.deviceInfo,
    required this.client,
    required this.protocol,
    required this.deviceInfoApi,
  });

  final BleDeviceInfo deviceInfo;
  final Lw006BleClient client;
  final Lw006ProtocolApi protocol;
  final Lw006DeviceInfoApi deviceInfoApi;
  final Lw006ExportDataStore exportData = Lw006ExportDataStore();

  static Lw006DeviceSession? _active;

  static Lw006DeviceSession? get active => _active;

  static Future<Lw006DeviceSession> connect({
    required BleDeviceInfo deviceInfo,
    String? password,
  }) async {
    final bluetoothDevice = BluetoothDevice.fromId(deviceInfo.id.str);
    final client = Lw006BleClient();

    await client.connectWithRetry(bluetoothDevice);

    if (password != null && password.isNotEmpty) {
      final verified = await client.verifyPassword(password);
      if (!verified) {
        await client.disconnect();
        throw Lw006ProtocolException('Password verification failed');
      }
    }

    final session = Lw006DeviceSession._(
      deviceInfo: deviceInfo,
      client: client,
      protocol: Lw006ProtocolApi(client),
      deviceInfoApi: Lw006DeviceInfoApi(client),
    );
    _active = session;
    return session;
  }

  Future<void> disconnect() async {
    await client.disconnect();
    clearActiveIfMatches(this);
  }

  static void clearActiveIfMatches(Lw006DeviceSession session) {
    if (_active == session) {
      _active = null;
    }
  }
}
