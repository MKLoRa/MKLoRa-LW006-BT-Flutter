import 'dart:async';

import 'package:flutter/material.dart';

import '../../ble/lw006.dart';
import '../../ble/lw006_device_session.dart';
import '../../dfu/lw006_dfu_coordinator.dart';
import '../../ui/theme/device_detail_theme.dart';
import '../../ui/widgets/ble_loading_overlay.dart';
import '../../ui/widgets/common_confirm_dialog.dart';
import '../../viewmodels/ble_scan_view_model.dart';
import 'device_detail/tabs/device_tab.dart';
import 'device_detail/tabs/general_tab.dart';
import 'device_detail/tabs/lora_tab.dart';

class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({
    super.key,
    required this.session,
    this.onInitialLoadComplete,
  });

  final Lw006DeviceSession session;
  final VoidCallback? onInitialLoadComplete;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  int _tabIndex = 0;
  StreamSubscription<Lw006DisconnectEvent>? _disconnectSub;
  var _disconnectDialogShown = false;
  var _manualBackInProgress = false;
  Future<bool> Function()? _generalSave;
  Future<bool> Function()? _deviceSave;
  final _loraTabKey = GlobalKey<LoRaTabState>();
  final _positionTabKey = GlobalKey<PositionTabState>();
  final _generalTabKey = GlobalKey<GeneralTabState>();
  final _deviceTabKey = GlobalKey<DeviceTabState>();

  @override
  void initState() {
    super.initState();
    _disconnectSub = widget.session.client.disconnectEvents.listen(_onDisconnect);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialSync());
  }

  Future<void> _initialSync() async {
    try {
      if (widget.onInitialLoadComplete == null) {
        await runWithBleLoading(context, _performInitialSync);
      } else {
        await _performInitialSync();
      }
    } finally {
      widget.onInitialLoadComplete?.call();
    }
  }

  Future<void> _performInitialSync() async {
    if (!mounted) return;
    await widget.session.protocol.syncTime();
    if (!mounted) return;
    await _loadTabData(_tabIndex, showOverlay: false);
  }

  Future<void> _loadTabData(int index, {bool showOverlay = true}) async {
    switch (index) {
      case 0:
        await _loraTabKey.currentState?.load(showOverlay: showOverlay);
      case 1:
        await _positionTabKey.currentState?.load(showOverlay: showOverlay);
      case 2:
        await _generalTabKey.currentState?.load(showOverlay: showOverlay);
      case 3:
        await _deviceTabKey.currentState?.reload(showOverlay: showOverlay);
    }
  }

  Future<void> _onDisconnect(Lw006DisconnectEvent event) async {
    if (_manualBackInProgress ||
        Lw006DfuCoordinator.isUpgrading ||
        _disconnectDialogShown ||
        !mounted) {
      return;
    }
    _disconnectDialogShown = true;
    forceHideBleLoading();
    await showCommonConfirmDialog(
      context: context,
      message: event.message,
      confirmText: 'OK',
      actionColor: BleScanViewModel.titleBarColor,
      barrierDismissible: false,
      showCancel: false,
      useRootNavigator: true,
    );
    if (!mounted) return;
    _disconnectSub?.cancel();
    await widget.session.disconnect();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _onBack() async {
    if (_manualBackInProgress) {
      return;
    }
    _manualBackInProgress = true;
    _disconnectSub?.cancel();
    await widget.session.disconnect();
    if (!mounted) {
      return;
    }
    await showCommonConfirmDialog(
      context: context,
      message: 'The device is disconnected!',
      confirmText: 'OK',
      actionColor: BleScanViewModel.titleBarColor,
      barrierDismissible: false,
      showCancel: false,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _onSave() async {
    final save = _tabIndex == 2 ? _generalSave : _tabIndex == 3 ? _deviceSave : null;
    if (save == null) return;
    await runWithBleLoading(context, () async {
      final ok = await save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Save Successfully！'
                : 'Opps！Save failed. Please check the input characters and try again.',
          ),
        ),
      );
    });
  }

  void _onTabChanged(int index) {
    setState(() => _tabIndex = index);
    _loadTabData(index);
  }

  String get _title {
    switch (_tabIndex) {
      case 0:
        return 'LoRa';
      case 1:
        return 'Positioning Strategy';
      case 2:
        return 'General Settings';
      case 3:
        return 'Device Settings';
      default:
        return 'Device';
    }
  }

  bool get _showSave => _tabIndex == 2 || _tabIndex == 3;

  @override
  void dispose() {
    widget.onInitialLoadComplete?.call();
    _disconnectSub?.cancel();
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
        backgroundColor: DeviceDetailTheme.primary,
        appBar: AppBar(
          backgroundColor: DeviceDetailTheme.primary,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: _onBack,
          ),
          title: Text(
            _title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          actions: [
            if (_showSave)
              IconButton(
                icon: const Icon(Icons.save, color: Colors.white),
                onPressed: _onSave,
              ),
          ],
        ),
        body: ColoredBox(
          color: DeviceDetailTheme.background,
          child: IndexedStack(
          index: _tabIndex,
          children: [
            LoRaTab(key: _loraTabKey, session: widget.session),
            PositionTab(key: _positionTabKey, session: widget.session),
            GeneralTab(
              key: _generalTabKey,
              session: widget.session,
              onSaveReady: (save) => _generalSave = save,
            ),
            DeviceTab(
              key: _deviceTabKey,
              session: widget.session,
              onSaveReady: (save) => _deviceSave = save,
            ),
          ],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1, color: DeviceDetailTheme.divider),
            BottomNavigationBar(
              currentIndex: _tabIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: DeviceDetailTheme.primary,
              unselectedItemColor: DeviceDetailTheme.textSecondary,
              onTap: _onTabChanged,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.wifi), label: 'LoRa'),
                BottomNavigationBarItem(icon: Icon(Icons.place), label: 'Position'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'General'),
                BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Device'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
