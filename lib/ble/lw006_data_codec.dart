import 'lw006_param_helpers.dart';

class Lw006PayloadConfig {
  const Lw006PayloadConfig({required this.confirmed, required this.retransIndex});

  final bool confirmed;
  final int retransIndex;

  static Lw006PayloadConfig fromBytes(List<int> data) {
    if (data.length < 2) {
      return const Lw006PayloadConfig(confirmed: false, retransIndex: 0);
    }
    return Lw006PayloadConfig(
      confirmed: data[0] == 1,
      retransIndex: (data[1] - 1).clamp(0, 3),
    );
  }

  List<int> toBytes() => [confirmed ? 1 : 0, retransIndex + 1];
}

class Lw006TimePoint {
  Lw006TimePoint({required this.hour, required this.minute});

  int hour;
  int minute;

  int toMinutes() => hour * 60 + minute;

  static Lw006TimePoint fromMinutes(int value) {
    if (value == 0) {
      return Lw006TimePoint(hour: 0, minute: 0);
    }
    final hour = value ~/ 60;
    final minute = value % 60;
    return Lw006TimePoint(hour: hour == 24 ? 0 : hour, minute: minute);
  }
}

class Lw006TimeSegment {
  Lw006TimeSegment({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.reportInterval,
  });

  int startHour;
  int startMinute;
  int endHour;
  int endMinute;
  int reportInterval;

  List<int> encode() {
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    return [
      ...Lw006ParamHelpers.uint16Bytes(start),
      ...Lw006ParamHelpers.uint16Bytes(end),
      ...Lw006ParamHelpers.int32Bytes(reportInterval),
    ];
  }
}

class Lw006ExportRecord {
  Lw006ExportRecord({required this.rawData, DateTime? time}) : time = time ?? DateTime.now();

  final DateTime time;
  final String rawData;
}

class Lw006StorageNotifyParseResult {
  const Lw006StorageNotifyParseResult({this.records, this.totalSum});

  final List<Lw006ExportRecord>? records;
  final int? totalSum;
}

class Lw006DataCodec {
  Lw006DataCodec._();

  static List<int> encodeTimePoints(List<Lw006TimePoint> points) {
    final bytes = <int>[];
    for (final point in points) {
      bytes.addAll(Lw006ParamHelpers.uint16Bytes(point.toMinutes()));
    }
    return bytes;
  }

  static List<Lw006TimePoint> decodeTimePoints(List<int> data) {
    final points = <Lw006TimePoint>[];
    for (var i = 0; i + 1 < data.length; i += 2) {
      final minutes = Lw006ParamHelpers.uint16(data.sublist(i, i + 2));
      points.add(Lw006TimePoint.fromMinutes(minutes));
    }
    return points;
  }

  static List<int> encodeTimeSegments(List<Lw006TimeSegment> segments) {
    final bytes = <int>[];
    for (final segment in segments) {
      bytes.addAll(segment.encode());
    }
    return bytes;
  }

  static List<Lw006TimeSegment> decodeTimeSegments(List<int> data) {
    final segments = <Lw006TimeSegment>[];
    for (var i = 0; i + 7 < data.length; i += 8) {
      final start = Lw006ParamHelpers.uint16(data.sublist(i, i + 2));
      final end = Lw006ParamHelpers.uint16(data.sublist(i + 2, i + 4));
      final interval = Lw006ParamHelpers.int32(data.sublist(i + 4, i + 8));
      final startPoint = Lw006TimePoint.fromMinutes(start);
      final endPoint = Lw006TimePoint.fromMinutes(end);
      segments.add(
        Lw006TimeSegment(
          startHour: startPoint.hour,
          startMinute: startPoint.minute,
          endHour: endPoint.hour,
          endMinute: endPoint.minute,
          reportInterval: interval,
        ),
      );
    }
    return segments;
  }

  static List<String> decodeMacRules(List<int> data) {
    final rules = <String>[];
    var index = 0;
    while (index < data.length) {
      final length = data[index];
      index++;
      if (index + length > data.length) break;
      rules.add(Lw006ParamHelpers.bytesToHex(data.sublist(index, index + length)));
      index += length;
    }
    return rules;
  }

  static List<int> encodeMacRules(List<String> macs) {
    final bytes = <int>[];
    for (final mac in macs) {
      final macBytes = Lw006ParamHelpers.hexToBytes(mac);
      if (macBytes.isEmpty) continue;
      bytes.add(macBytes.length);
      bytes.addAll(macBytes);
    }
    return bytes;
  }

  static List<String> decodeNameRules(List<int> data) {
    final rules = <String>[];
    var index = 0;
    while (index < data.length) {
      final length = data[index];
      index++;
      if (index + length > data.length) break;
      rules.add(String.fromCharCodes(data.sublist(index, index + length)));
      index += length;
    }
    return rules;
  }

  static List<int> encodeNameRules(List<String> names) {
    final bytes = <int>[];
    for (final name in names) {
      final nameBytes = name.codeUnits;
      if (nameBytes.isEmpty) continue;
      bytes.add(nameBytes.length);
      bytes.addAll(nameBytes);
    }
    return bytes;
  }

  /// LW006 indicator bitmask (single byte), aligned with native IndicatorSettingsActivity.
  static int encodeIndicator({
    required bool deviceState,
    required bool fix,
    required bool fixSuccess,
    required bool fixFail,
    required bool networkCheck,
    required bool lowPower,
    required bool bleAdvCheck,
  }) {
    return (fix ? 1 : 0) |
        (fixSuccess ? 2 : 0) |
        (fixFail ? 4 : 0) |
        (networkCheck ? 8 : 0) |
        (lowPower ? 16 : 0) |
        (bleAdvCheck ? 32 : 0) |
        (deviceState ? 64 : 0);
  }

  static Map<String, bool> decodeIndicator(int value) {
    final v = value & 0xFF;
    return {
      'deviceState': (v & 64) == 64,
      'fix': (v & 1) == 1,
      'fixSuccess': (v & 2) == 2,
      'fixFail': (v & 4) == 4,
      'networkCheck': (v & 8) == 8,
      'lowPower': (v & 16) == 16,
      'bleAdvCheck': (v & 32) == 32,
    };
  }

  static Lw006StorageNotifyParseResult? parseStorageNotify(List<int> value) {
    if (value.length < 5 || value[0] != 0xED || value[1] != 0x02) {
      return null;
    }
    final cmd = value[2] & 0xFF;
    if (cmd != 0x01) {
      return null;
    }
    final dataCount = value[4] & 0xFF;
    if (dataCount > 0) {
      final notifyTime = DateTime.now();
      final records = <Lw006ExportRecord>[];
      var index = 5;
      while (index < value.length) {
        final dataLength = value[index] & 0xFF;
        index++;
        var rawData = '';
        if (dataLength > 0 && index + dataLength <= value.length) {
          rawData = Lw006ParamHelpers.bytesToHex(
            value.sublist(index, index + dataLength),
          );
          index += dataLength;
        }
        records.add(Lw006ExportRecord(rawData: rawData, time: notifyTime));
      }
      return Lw006StorageNotifyParseResult(records: records);
    }
    if (value.length > 5) {
      var sum = 0;
      for (var i = 5; i < value.length; i++) {
        sum = (sum << 8) | (value[i] & 0xFF);
      }
      return Lw006StorageNotifyParseResult(totalSum: sum);
    }
    return null;
  }

  static List<int> encodeLoraUplinkStrategy({
    required bool adr,
    required int dr1,
    required int dr2,
  }) =>
      [adr ? 1 : 0, 1, dr1, dr2];

  static List<int> encodeAccCondition(int threshold, int duration) => [threshold, duration];
}
