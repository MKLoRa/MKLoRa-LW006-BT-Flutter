import 'dart:convert';
import 'dart:typed_data';

import 'lw006_param_key.dart';
import 'lw006_protocol_api.dart';

class Lw006ParamHelpers {
  Lw006ParamHelpers._();

  static int byte0(List<int> data, {int defaultValue = 0}) {
    if (data.isEmpty) {
      return defaultValue;
    }
    var value = data[0];
    if (value > 127) {
      value -= 256;
    }
    return value;
  }

  static int uint8(List<int> data, {int defaultValue = 0}) {
    return data.isEmpty ? defaultValue : data[0];
  }

  static int uint16(List<int> data, {int defaultValue = 0, int offset = 0}) {
    if (data.length < offset + 2) {
      return defaultValue;
    }
    return (data[offset] << 8) | data[offset + 1];
  }

  /// Big-endian integer from 1–4 byte param payloads (matches native MokoUtils.toInt).
  static int bytesToInt(List<int> data, {int defaultValue = 0}) {
    if (data.isEmpty) {
      return defaultValue;
    }
    var value = 0;
    for (final byte in data) {
      value = (value << 8) | (byte & 0xFF);
    }
    return value;
  }

  /// Big-endian 32-bit value from device payloads (matches native MokoUtils.toInt).
  static int int32(List<int> data, {int defaultValue = 0}) {
    return bytesToInt(data, defaultValue: defaultValue);
  }

  static List<int> single(int value) => [value & 0xFF];

  static List<int> uint16Bytes(int value) => [(value >> 8) & 0xFF, value & 0xFF];

  static List<int> int32Bytes(int value) => [
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ];

  static String bytesToString(List<int> data) {
    if (data.isEmpty) {
      return '';
    }
    return utf8.decode(data, allowMalformed: true).trim();
  }

  static String formatMac(List<int> data) {
    if (data.isEmpty) {
      return '';
    }
    final hex = data
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
    final buffer = StringBuffer();
    for (var i = 0; i < hex.length; i += 2) {
      if (buffer.isNotEmpty) {
        buffer.write(':');
      }
      buffer.write(hex.substring(i, i + 2));
    }
    return buffer.toString();
  }

  static int timeZoneIndexFromBytes(List<int> data) {
    return byte0(data) + 24;
  }

  static List<int> timeZoneBytesFromIndex(int pickerIndex) {
    return single(pickerIndex - 24);
  }

  static String bytesToHex(List<int> data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
  }

  static List<int> hexToBytes(String hex) {
    final cleaned = hex.replaceAll(':', '').replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return const [];
    }
    final bytes = <int>[];
    for (var i = 0; i < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}

extension Lw006ProtocolApiBatch on Lw006ProtocolApi {
  /// Writes UTC epoch seconds (param 0x13), aligned with native `setTime()`.
  Future<bool> syncTime() async {
    final now = DateTime.now().toUtc();
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    final bytes = ByteData(4);
    bytes.setInt32(0, seconds, Endian.big);
    return writeParam(Lw006ParamKey.timeUtc, bytes.buffer.asUint8List());
  }
}
