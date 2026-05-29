import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'lw006_constants.dart';
import 'lw006_data_codec.dart';
import 'lw006_disconnect_event.dart';
import 'lw006_protocol_codec.dart';
import 'lw006_protocol_logger.dart';

class Lw006BleClient {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _passwordChar;
  BluetoothCharacteristic? _disconnectChar;
  BluetoothCharacteristic? _paramsChar;
  BluetoothCharacteristic? _storageDataNotifyChar;
  BluetoothCharacteristic? _modelNumberChar;
  BluetoothCharacteristic? _serialNumberChar;
  BluetoothCharacteristic? _firmwareRevisionChar;
  BluetoothCharacteristic? _hardwareRevisionChar;
  BluetoothCharacteristic? _softwareRevisionChar;
  BluetoothCharacteristic? _manufacturerNameChar;

  final Map<String, StreamSubscription<List<int>>> _notifySubscriptions = {};
  final Map<String, Completer<List<int>>> _pendingRequests = {};
  final Map<String, List<List<int>>> _packetBuffers = {};
  final _disconnectController = StreamController<Lw006DisconnectEvent>.broadcast();
  final _storageNotifyController =
      StreamController<Lw006StorageNotifyParseResult>.broadcast();
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  Future<void> _requestChain = Future<void>.value();

  Stream<Lw006DisconnectEvent> get disconnectEvents => _disconnectController.stream;

  Stream<Lw006StorageNotifyParseResult> get storageNotifyEvents =>
      _storageNotifyController.stream;

  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected ?? false;

  Future<void> connectWithRetry(BluetoothDevice device) async {
    _device = device;
    final deadline = DateTime.now().add(Lw006ProtocolConstants.connectTotalTimeout);
    Object? lastError;

    for (var attempt = 0; attempt < Lw006ProtocolConstants.connectMaxAttempts; attempt++) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException(
          'Connection timed out after ${Lw006ProtocolConstants.connectTotalTimeout.inSeconds}s',
        );
      }

      try {
        if (device.isConnected) {
          await device.disconnect();
        }
        await device.connect(
          timeout: remaining,
          autoConnect: false,
        );
        if (Platform.isAndroid) {
          await device.requestMtu(247);
        }
        await _discoverServices(device);
        await _enableNotifications();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _listenConnectionState(device);
        return;
      } catch (error) {
        lastError = error;
        debugPrint('LW006 connect attempt ${attempt + 1} failed: $error');
        if (attempt < Lw006ProtocolConstants.connectMaxAttempts - 1) {
          await Future<void>.delayed(
            const Duration(milliseconds: Lw006ProtocolConstants.connectRetryDelayMs),
          );
        }
      }
    }

    throw lastError ?? Exception('Connection failed');
  }

  Future<void> disconnect() async {
    await _clearSubscriptions();
    final device = _device;
    _device = null;
    if (device != null && device.isConnected) {
      await device.disconnect();
    }
  }

  Future<bool> verifyPassword(String password) async {
    final characteristic = _requireCharacteristic(_passwordChar, 'password');
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw006ProtocolCodec.buildPasswordFrame(password),
      key: Lw006ProtocolConstants.passwordCmd,
      matcher: Lw006ProtocolCodec.isPasswordSuccess,
    );
    return Lw006ProtocolCodec.isPasswordSuccess(response);
  }

  Future<Lw006ParamResult> readParam({
    required int key,
    Lw006ParamChannel channel = Lw006ParamChannel.runtime,
    bool packet = false,
  }) async {
    final characteristic = _characteristicForChannel(channel);
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw006ProtocolCodec.buildReadFrame(key: key, packet: packet),
      key: key,
    );
    final parsed = Lw006ProtocolCodec.parseReadResponse(response);
    if (parsed == null) {
      throw Lw006ProtocolException(
        'Invalid read response for 0x${key.toRadixString(16)}',
      );
    }
    return Lw006ParamResult(
      key: parsed.key,
      data: parsed.data,
      raw: response,
    );
  }

  Future<bool> writeParam({
    required int key,
    required List<int> data,
    Lw006ParamChannel channel = Lw006ParamChannel.runtime,
    bool packet = false,
    int packetCount = 1,
    int packetIndex = 0,
  }) async {
    final characteristic = _characteristicForChannel(channel);
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw006ProtocolCodec.buildWriteFrame(
        key: key,
        data: data,
        packet: packet,
        packetCount: packetCount,
        packetIndex: packetIndex,
      ),
      key: key,
      matcher: (value) => Lw006ProtocolCodec.isWriteSuccess(value, key),
    );
    return Lw006ProtocolCodec.isWriteSuccess(response, key);
  }

  Future<String> readDeviceInfoString(
    BluetoothCharacteristic characteristic, {
    required String name,
  }) async {
    final value = await characteristic.read();
    Lw006ProtocolLogger.logGattRead(name: name, value: value);
    return String.fromCharCodes(value.where((b) => b != 0)).trim();
  }

  Future<String> readModelNumber() => readDeviceInfoString(
        _requireCharacteristic(_modelNumberChar, 'model number'),
        name: 'modelNumber',
      );
  Future<String> readSerialNumber() => readDeviceInfoString(
        _requireCharacteristic(_serialNumberChar, 'serial number'),
        name: 'serialNumber',
      );
  Future<String> readFirmwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_firmwareRevisionChar, 'firmware revision'),
        name: 'firmwareRevision',
      );
  Future<String> readHardwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_hardwareRevisionChar, 'hardware revision'),
        name: 'hardwareRevision',
      );
  Future<String> readSoftwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_softwareRevisionChar, 'software revision'),
        name: 'softwareRevision',
      );
  Future<String> readManufacturerName() => readDeviceInfoString(
        _requireCharacteristic(_manufacturerNameChar, 'manufacturer name'),
        name: 'manufacturerName',
      );

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final deviceInfo = _findService(services, Lw006Uuids.deviceInfoService);
    final custom = _findService(services, Lw006Uuids.customService);

    if (deviceInfo == null) {
      throw Lw006ProtocolException('Device Information Service not found');
    }
    if (custom == null) {
      throw Lw006ProtocolException('Custom service 0xAA00 not found');
    }

    _modelNumberChar = _findCharacteristic(deviceInfo, Lw006Uuids.modelNumber);
    _serialNumberChar = _findCharacteristic(deviceInfo, Lw006Uuids.serialNumber);
    _firmwareRevisionChar = _findCharacteristic(deviceInfo, Lw006Uuids.firmwareRevision);
    _hardwareRevisionChar = _findCharacteristic(deviceInfo, Lw006Uuids.hardwareRevision);
    _softwareRevisionChar = _findCharacteristic(deviceInfo, Lw006Uuids.softwareRevision);
    _manufacturerNameChar = _findCharacteristic(deviceInfo, Lw006Uuids.manufacturerName);

    _passwordChar = _findCharacteristic(custom, Lw006Uuids.password);
    _disconnectChar = _findCharacteristic(custom, Lw006Uuids.disconnectNotify);
    _paramsChar = _findCharacteristic(custom, Lw006Uuids.params);
    _storageDataNotifyChar = _findCharacteristic(custom, Lw006Uuids.storageDataNotify);

    if (_passwordChar == null || _paramsChar == null || _disconnectChar == null) {
      throw Lw006ProtocolException('Required custom characteristics not found');
    }
  }

  Future<void> _enableNotifications() async {
    await _subscribeCharacteristic(_passwordChar!, 'password');
    await _subscribeCharacteristic(_disconnectChar!, 'disconnect');
    await _subscribeCharacteristic(_paramsChar!, 'params');
    if (_storageDataNotifyChar != null) {
      await _subscribeCharacteristic(_storageDataNotifyChar!, 'storageData');
    }
  }

  Future<void> _subscribeCharacteristic(
    BluetoothCharacteristic characteristic,
    String channelKey,
  ) async {
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions[channelKey]?.cancel();
    _notifySubscriptions[channelKey] = characteristic.onValueReceived.listen(
      (value) => _handleNotification(channelKey, value),
    );
  }

  void _handleNotification(String channelKey, List<int> value) {
    if (value.isEmpty) {
      return;
    }

    if (channelKey == 'disconnect') {
      Lw006ProtocolLogger.logDisconnectNotify(value);
      final event = Lw006DisconnectEvent.fromNotificationBytes(value);
      if (event != null) {
        _disconnectController.add(event);
      }
      return;
    }

    if (channelKey == 'storageData') {
      Lw006ProtocolLogger.logRx(channel: channelKey, payload: value);
      final parsed = Lw006DataCodec.parseStorageNotify(value);
      if (parsed != null) {
        _storageNotifyController.add(parsed);
      }
      return;
    }

    if (value[0] == Lw006ProtocolConstants.headPacket) {
      Lw006ProtocolLogger.logRx(channel: channelKey, payload: value, partialPacket: true);
      final requestKey = _requestKeyFromPacket(value);
      _packetBuffers.putIfAbsent(requestKey, () => []).add(value);
      final packets = _packetBuffers[requestKey]!;
      final expectedCount = value[3];
      if (packets.length >= expectedCount) {
        final merged = Lw006ProtocolCodec.reassemblePacketResponses(packets);
        _packetBuffers.remove(requestKey);
        Lw006ProtocolLogger.logRx(channel: channelKey, payload: merged);
        _completeRequest(requestKey, merged);
      }
      return;
    }

    Lw006ProtocolLogger.logRx(channel: channelKey, payload: value);
    final requestKey = _requestKeyFromFrame(value);
    _completeRequest(requestKey, value);
  }

  Future<List<int>> _sendFrame({
    required BluetoothCharacteristic characteristic,
    required List<int> payload,
    required int key,
    bool Function(List<int> value)? matcher,
  }) {
    return _enqueueRequest(() async {
      final requestKey = _requestKey(key);
      final completer = Completer<List<int>>();
      _pendingRequests[requestKey] = completer;

      try {
        Lw006ProtocolLogger.logTx(
          channel: _channelNameForCharacteristic(characteristic),
          key: key,
          payload: payload,
        );
        final withoutResponse = _shouldWriteWithoutResponse(characteristic);
        await characteristic.write(payload, withoutResponse: withoutResponse);
        final response = await completer.future.timeout(
          Lw006ProtocolConstants.requestTimeout,
          onTimeout: () {
            Lw006ProtocolLogger.logError('Request timeout for $requestKey');
            throw Lw006ProtocolTimeoutException(requestKey);
          },
        );
        if (matcher != null && !matcher(response)) {
          Lw006ProtocolLogger.logError('Unexpected response for $requestKey');
          throw Lw006ProtocolException('Unexpected response for $requestKey');
        }
        return response;
      } finally {
        _pendingRequests.remove(requestKey);
        _packetBuffers.remove(requestKey);
      }
    });
  }

  Future<T> _enqueueRequest<T>(Future<T> Function() action) {
    final task = _requestChain.then((_) => action());
    _requestChain = task.then((_) {}, onError: (_) {});
    return task;
  }

  bool _shouldWriteWithoutResponse(BluetoothCharacteristic characteristic) {
    final properties = characteristic.properties;
    if (properties.write) {
      return false;
    }
    return properties.writeWithoutResponse;
  }

  void _completeRequest(String requestKey, List<int> value) {
    final completer = _pendingRequests[requestKey];
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  BluetoothCharacteristic _characteristicForChannel(Lw006ParamChannel channel) {
    switch (channel) {
      case Lw006ParamChannel.runtime:
        return _requireCharacteristic(_paramsChar, 'params');
      case Lw006ParamChannel.storageData:
        return _requireCharacteristic(_storageDataNotifyChar, 'storage data');
    }
  }

  BluetoothService? _findService(List<BluetoothService> services, String uuid) {
    final target = Guid(uuid);
    for (final service in services) {
      if (service.uuid == target) {
        return service;
      }
    }
    return null;
  }

  BluetoothCharacteristic? _findCharacteristic(
    BluetoothService service,
    String uuid,
  ) {
    final target = Guid(uuid);
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == target) {
        return characteristic;
      }
    }
    return null;
  }

  BluetoothCharacteristic _requireCharacteristic(
    BluetoothCharacteristic? characteristic,
    String name,
  ) {
    if (characteristic == null) {
      throw Lw006ProtocolException('$name characteristic unavailable');
    }
    return characteristic;
  }

  String _channelNameForCharacteristic(BluetoothCharacteristic characteristic) {
    if (identical(characteristic, _passwordChar)) return 'password';
    if (identical(characteristic, _paramsChar)) return 'params';
    if (identical(characteristic, _storageDataNotifyChar)) return 'storageData';
    return characteristic.uuid.toString();
  }

  String _requestKey(int key) => key.toRadixString(16);

  String _requestKeyFromFrame(List<int> value) {
    if (value.length < 3) {
      return 'unknown';
    }
    return _requestKey(value[2] & 0xFF);
  }

  String _requestKeyFromPacket(List<int> value) {
    if (value.length < 3) {
      return 'unknown';
    }
    return _requestKey(value[2] & 0xFF);
  }

  void _listenConnectionState(BluetoothDevice device) {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _disconnectController.add(Lw006DisconnectEvent.generic);
      }
    });
  }

  Future<void> _clearSubscriptions() async {
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    for (final subscription in _notifySubscriptions.values) {
      await subscription.cancel();
    }
    _notifySubscriptions.clear();
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          Lw006ProtocolException('Connection closed'),
        );
      }
    }
    _pendingRequests.clear();
    _packetBuffers.clear();
  }
}

enum Lw006ParamChannel {
  runtime,
  storageData,
}

class Lw006ParamResult {
  const Lw006ParamResult({
    required this.key,
    required this.data,
    required this.raw,
  });

  final int key;
  final List<int> data;
  final List<int> raw;
}

class Lw006ProtocolException implements Exception {
  Lw006ProtocolException(this.message);

  final String message;

  @override
  String toString() => 'Lw006ProtocolException: $message';
}

class Lw006ProtocolTimeoutException extends TimeoutException {
  Lw006ProtocolTimeoutException(String requestKey)
      : super(requestKey, Lw006ProtocolConstants.requestTimeout);

  static const userMessage = 'Failed';
}
