import 'dart:io';

import 'package:path_provider/path_provider.dart';

class Lw006DebugLogEntry {
  Lw006DebugLogEntry({
    required this.name,
    required this.path,
    this.selected = false,
  });

  final String name;
  final String path;
  bool selected;
}

/// Persists debugger logs under `{appDocuments}/LW006/logs/{mac}/` (native LogDataActivity).
class Lw006DebugLogFile {
  Lw006DebugLogFile._();

  static const maxFiles = 10;
  static const _folderName = 'LW006';
  static const _logsFolder = 'logs';

  static String _macFolder(String mac) => mac.replaceAll(':', '').toUpperCase();

  static Future<Directory> logDirForMac(String mac) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}$_folderName'
      '${Platform.pathSeparator}$_logsFolder'
      '${Platform.pathSeparator}${_macFolder(mac)}',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<Lw006DebugLogEntry>> listLogs(String mac) async {
    final dir = await logDirForMac(mac);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    return files.map((file) {
      final name = file.uri.pathSegments.last.replaceAll('.txt', '');
      return Lw006DebugLogEntry(name: name, path: file.path);
    }).toList();
  }

  static Future<void> writeLog(String mac, String fileName, String content) async {
    final dir = await logDirForMac(mac);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName.txt');
    await file.writeAsString(content);
  }

  static Future<void> deleteLogs(List<Lw006DebugLogEntry> entries) async {
    for (final entry in entries) {
      if (!entry.selected) continue;
      final file = File(entry.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static String syncTimestamp(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h-$min-$s';
  }
}
