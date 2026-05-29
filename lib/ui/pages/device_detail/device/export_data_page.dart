import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../ble/lw006.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';
import '../device_detail_utils.dart';

class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key, required this.session});

  final Lw006DeviceSession session;

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> {
  final _timeController = TextEditingController();
  StreamSubscription<Lw006StorageNotifyParseResult>? _storageSub;
  var _started = false;
  var _syncing = false;
  var _stoppingOnBack = false;

  Lw006ExportDataStore get _store => widget.session.exportData;

  @override
  void initState() {
    super.initState();
    _restoreFromStore();
    _storageSub = widget.session.client.storageNotifyEvents.listen(_onStorageNotify);
  }

  void _restoreFromStore() {
    if (_store.startTimeDays > 0) {
      _timeController.text = _store.startTimeDays.toString();
      _started = true;
      _syncing = false;
    }
  }

  void _onStorageNotify(Lw006StorageNotifyParseResult event) {
    if (!mounted) return;
    setState(() {
      if (event.records != null && event.records!.isNotEmpty) {
        _store.appendRecords(
          event.records!,
          insertAtHead: _store.startTimeDays == 65535,
        );
      }
      if (event.totalSum != null) {
        _store.totalSum = event.totalSum;
      }
    });
    if (_stoppingOnBack && !_syncing) {
      Navigator.of(context).pop();
    }
  }

  bool get _hasData => _store.records.isNotEmpty;

  bool get _canEditTime => !_syncing;

  bool get _canStart => !_syncing;

  bool get _canSync => _started;

  bool get _canEmptyOrExport => _hasData && !_syncing;

  String get _sumLabel =>
      _store.totalSum == null ? 'Sum:N/A' : 'Sum:${_store.totalSum}';

  String get _countLabel => 'Count:${_store.records.length}';

  Future<void> _start() async {
    final text = _timeController.text.trim();
    final days = int.tryParse(text);
    if (days == null || days < 1 || days > 65535) {
      if (mounted) {
        showProtocolResultToast(context, ok: false);
      }
      return;
    }
    await runWithBleLoading(context, () async {
      _store.clear();
      await Lw006TrackedFile.write('');
      _store.startTimeDays = days;
      final ok = await widget.session.protocol.startStorageDataRead(days);
      if (!ok) {
        throw Exception('start failed');
      }
      if (!mounted) return;
      setState(() {
        _started = true;
        _syncing = true;
      });
    });
  }

  Future<void> _toggleSync() async {
    if (!_started) return;
    await runWithBleLoading(context, () async {
      final enable = !_syncing;
      final ok = await widget.session.protocol.setStorageSyncEnabled(enable);
      if (!ok) {
        throw Exception('sync failed');
      }
      if (!mounted) return;
      setState(() => _syncing = enable);
    });
  }

  Future<void> _empty() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning!',
      message: 'Are you sure to empty the saved tracked datas?',
      confirmText: 'OK',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () async {
      final cleared = await widget.session.protocol.writeClearStorageDataEmpty();
      if (!cleared) {
        throw Exception('clear failed');
      }
      _store.clear();
      await Lw006TrackedFile.write('');
      if (!mounted) return;
      setState(() {
        _started = false;
        _syncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empty success!')),
      );
    });
  }

  Future<void> _export() async {
    if (!_canEmptyOrExport) return;
    final log = _store.exportText.toString();
    if (log.isEmpty) return;
    await runWithBleLoading(context, () async {
      await Lw006TrackedFile.write('');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await Lw006TrackedFile.write(log);
    });
    final file = await Lw006TrackedFile.trackedFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Tracked Log',
        text: 'Tracked Log',
      ),
    );
  }

  Future<void> _onBack() async {
    if (_syncing) {
      _stoppingOnBack = true;
      await runWithBleLoading(
        context,
        () => widget.session.protocol.setStorageSyncEnabled(false),
      );
      if (mounted) {
        setState(() => _syncing = false);
      }
      _stoppingOnBack = false;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _storageSub?.cancel();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onBack();
      },
      child: Scaffold(
        backgroundColor: DeviceDetailTheme.card,
        appBar: AppBar(
          backgroundColor: DeviceDetailTheme.primary,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: _onBack,
          ),
          title: const Text(
            'Local Data Sync',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Text('Time', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: TextField(
                      controller: _timeController,
                      enabled: _canEditTime,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: const InputDecoration(
                        hintText: '1~65535',
                        counterText: '',
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                  const Text('Days', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _canStart ? _start : null,
                    style: TextButton.styleFrom(
                      backgroundColor: DeviceDetailTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white70,
                      minimumSize: const Size(56, 40),
                    ),
                    child: const Text('Start'),
                  ),
                  IconButton(
                    onPressed: _canSync ? _toggleSync : null,
                    icon: Icon(
                      _syncing ? Icons.stop_circle_outlined : Icons.sync,
                      color: _canSync
                          ? DeviceDetailTheme.primary
                          : Colors.grey.shade400,
                    ),
                  ),
                  Text(
                    _syncing ? 'Stop' : 'Sync',
                    style: TextStyle(
                      fontSize: 13,
                      color: _canSync ? null : Colors.grey.shade400,
                    ),
                  ),
                  TextButton(
                    onPressed: _canEmptyOrExport ? _empty : null,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 22),
                        Text('Empty', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _canEmptyOrExport ? _export : null,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_outlined, size: 22),
                        Text('Export', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(_sumLabel, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: Text(_countLabel, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _store.records.length,
                itemBuilder: (context, index) {
                  final item = _store.records[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time:${_formatTime(item.time)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (item.rawData.isNotEmpty)
                          Text(
                            'Raw Data:${item.rawData}',
                            style: const TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }
}
