import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../ble/lw006_debug_log_file.dart';
import '../../../../../ble/lw006_device_session.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';

class LogDataPage extends StatefulWidget {
  const LogDataPage({super.key, required this.session, required this.deviceMac});

  final Lw006DeviceSession session;
  final String deviceMac;

  @override
  State<LogDataPage> createState() => _LogDataPageState();
}

class _LogDataPageState extends State<LogDataPage> {
  final _buffer = StringBuffer();
  StreamSubscription<String>? _logSub;
  var _syncing = false;
  var _selectedCount = 0;
  String? _syncTime;
  List<Lw006DebugLogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLogs());
  }

  Future<void> _loadLogs() async {
    final logs = await Lw006DebugLogFile.listLogs(widget.deviceMac);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _selectedCount = 0;
    });
  }

  Future<void> _toggleSync() async {
    if (!_syncing) {
      if (_logs.length >= Lw006DebugLogFile.maxFiles) {
        if (!mounted) return;
        await showCommonConfirmDialog(
          context: context,
          title: 'Tips',
          message: 'Up to 10 log files can be stored, please delete the useless logs first！',
          confirmText: 'OK',
          actionColor: BleScanViewModel.titleBarColor,
          showCancel: false,
        );
        return;
      }
      _buffer.clear();
      _syncTime = Lw006DebugLogFile.syncTimestamp(DateTime.now());
      await widget.session.client.enableLogNotify();
      _logSub = widget.session.client.logNotifyEvents.listen((chunk) {
        _buffer.write(chunk);
      });
      if (!mounted) return;
      setState(() => _syncing = true);
      return;
    }

    await widget.session.client.disableLogNotify();
    await _logSub?.cancel();
    _logSub = null;
    if (!mounted) return;
    setState(() => _syncing = false);

    if (_buffer.isEmpty) {
      await showCommonConfirmDialog(
        context: context,
        title: 'Tips',
        message: 'No debug logs are sent during this process！',
        confirmText: 'OK',
        actionColor: BleScanViewModel.titleBarColor,
        showCancel: false,
      );
      return;
    }

    final syncTime = _syncTime;
    if (syncTime == null) return;
    await Lw006DebugLogFile.writeLog(widget.deviceMac, syncTime, _buffer.toString());
    await _loadLogs();
  }

  Future<void> _deleteSelected() async {
    if (_selectedCount == 0) return;
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning!',
      message: 'Are you sure to empty the saved debugger log?',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok) return;
    await Lw006DebugLogFile.deleteLogs(_logs);
    await _loadLogs();
  }

  Future<void> _exportSelected() async {
    final files = _logs.where((entry) => entry.selected).map((entry) => XFile(entry.path)).toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(
      files,
      subject: 'Debugger Log',
      text: 'Debugger Log',
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      final entry = _logs[index];
      entry.selected = !entry.selected;
      _selectedCount += entry.selected ? 1 : -1;
    });
  }

  Future<void> _onBack() async {
    if (_syncing) {
      await _toggleSync();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _logSub?.cancel();
    if (widget.session.client.isLogNotifyEnabled) {
      widget.session.client.disableLogNotify();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAction = _selectedCount > 0 && !_syncing;
    return DetailScaffold(
      title: 'Debugger Mode',
      onBack: _onBack,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _toggleSync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DeviceDetailTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text(_syncing ? 'Stop' : 'Start'),
                ),
                if (_syncing) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: canAction ? _deleteSelected : null,
                  child: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: canAction ? _exportSelected : null,
                  child: const Text('Export'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final entry = _logs[index];
                return Material(
                  color: Colors.white,
                  child: CheckboxListTile(
                    value: entry.selected,
                    activeColor: DeviceDetailTheme.primary,
                    title: Text(entry.name),
                    onChanged: _syncing ? null : (_) => _toggleSelection(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
