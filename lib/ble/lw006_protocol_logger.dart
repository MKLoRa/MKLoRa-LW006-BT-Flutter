import 'package:flutter/foundation.dart';

import 'lw006_constants.dart';
import 'lw006_param_key.dart';
import 'lw006_protocol_codec.dart';

class Lw006ProtocolLogger {
  Lw006ProtocolLogger._();

  static bool enabled = true;

  static final Map<int, String> _paramNames = {
    for (final key in Lw006ParamKey.values) key.key: key.name,
  };

  static void logTx({
    required String channel,
    required int key,
    required List<int> payload,
  }) {
    if (!_shouldLog) return;

    final param = _paramLabel(key);
    final operation = _operationFromPayload(payload, key);
    final writeData = _writeDataFromPayload(payload);
    debugPrint(
      '[LW006 TX] $channel | $operation $param | frame=${_formatHex(payload)}'
      '${writeData == null ? '' : ' | writeData=${_formatHex(writeData)}'}',
    );
  }

  static void logRx({
    required String channel,
    required List<int> payload,
    bool partialPacket = false,
  }) {
    if (!_shouldLog) return;

    final parsed = Lw006ProtocolCodec.parseReadResponse(payload);
    final key = parsed?.key ?? (payload.length > 2 ? payload[2] & 0xFF : null);
    final param = key == null ? 'unknown' : _paramLabel(key);
    final suffix = partialPacket ? ' (packet chunk)' : '';
    final parsedData = parsed?.data;
    final writeOk = key != null && Lw006ProtocolCodec.isWriteSuccess(payload, key);

    debugPrint(
      '[LW006 RX] $channel | $param$suffix | frame=${_formatHex(payload)}'
      '${parsedData == null ? '' : ' | data=${_formatHex(parsedData)}'}'
      '${writeOk ? ' | result=OK' : ''}',
    );
  }

  static void logGattRead({
    required String name,
    required List<int> value,
  }) {
    if (!_shouldLog) return;
    final text = String.fromCharCodes(value.where((b) => b != 0)).trim();
    debugPrint(
      '[LW006 GATT READ] $name | raw=${_formatHex(value)} | text="$text"',
    );
  }

  static void logDisconnectNotify(List<int> value) {
    if (!_shouldLog) return;
    debugPrint('[LW006 NOTIFY] disconnect | raw=${_formatHex(value)}');
  }

  static void logError(String message) {
    if (!_shouldLog) return;
    debugPrint('[LW006 ERROR] $message');
  }

  static bool get _shouldLog => kDebugMode && enabled;

  static String _paramLabel(int key) {
    final name = _paramNames[key];
    return name == null
        ? '0x${key.toRadixString(16).padLeft(2, '0')}'
        : '$name (0x${key.toRadixString(16).padLeft(2, '0')})';
  }

  static String _operationFromPayload(List<int> payload, int key) {
    if (payload.length < 2) {
      return 'UNKNOWN';
    }
    if (key == Lw006ProtocolConstants.passwordCmd) {
      return 'PASSWORD';
    }
    return payload[1] == Lw006ProtocolConstants.flagRead ? 'READ' : 'WRITE';
  }

  static List<int>? _writeDataFromPayload(List<int> payload) {
    if (payload.length < 4) {
      return null;
    }
    if (payload[1] != Lw006ProtocolConstants.flagWrite) {
      return null;
    }
    if (payload[0] == Lw006ProtocolConstants.headPacket) {
      if (payload.length < 6) {
        return null;
      }
      final length = payload[5];
      if (payload.length < 6 + length) {
        return null;
      }
      return payload.sublist(6, 6 + length);
    }
    final length = payload[3];
    if (payload.length < 4 + length) {
      return null;
    }
    final data = payload.sublist(4, 4 + length);
    if (payload[2] == Lw006ProtocolConstants.passwordCmd) {
      return List<int>.filled(data.length, 0x2A);
    }
    return data;
  }

  static String _formatHex(List<int> bytes) {
    if (bytes.isEmpty) {
      return '(empty)';
    }
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}
