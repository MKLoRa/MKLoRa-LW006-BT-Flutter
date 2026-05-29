import 'lw006_ble_client.dart';
import 'lw006_param_key.dart';

class Lw006ProtocolApi {
  Lw006ProtocolApi(this._client);

  final Lw006BleClient _client;

  Lw006BleClient get client => _client;

  Future<bool> verifyPassword(String password) {
    return _client.verifyPassword(password);
  }

  Future<Lw006ParamResult> readParam(
    Lw006ParamKey key, {
    Lw006ParamChannel channel = Lw006ParamChannel.runtime,
    bool packet = false,
  }) {
    if (!key.canRead) {
      throw Lw006ProtocolException('Parameter ${key.name} is write-only');
    }
    return _client.readParam(
      key: key.key,
      channel: channel,
      packet: packet,
    );
  }

  Future<bool> writeParam(
    Lw006ParamKey key,
    List<int> data, {
    Lw006ParamChannel channel = Lw006ParamChannel.runtime,
    bool packet = false,
    int packetCount = 1,
    int packetIndex = 0,
  }) {
    if (!key.canWrite) {
      throw Lw006ProtocolException('Parameter ${key.name} is read-only');
    }
    return _client.writeParam(
      key: key.key,
      data: data,
      channel: channel,
      packet: packet,
      packetCount: packetCount,
      packetIndex: packetIndex,
    );
  }
}

class Lw006DeviceInfoApi {
  Lw006DeviceInfoApi(this._client);

  final Lw006BleClient _client;

  Future<String> readModelNumber() => _client.readModelNumber();
  Future<String> readSerialNumber() => _client.readSerialNumber();
  Future<String> readFirmwareRevision() => _client.readFirmwareRevision();
  Future<String> readHardwareRevision() => _client.readHardwareRevision();
  Future<String> readSoftwareRevision() => _client.readSoftwareRevision();
  Future<String> readManufacturerName() => _client.readManufacturerName();
}
