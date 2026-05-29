import 'package:flutter/material.dart';

import '../../../../../ble/lw006_device_session.dart';
import '../../../../../ble/lw006_param_helpers.dart';
import '../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';
import '../device_detail_utils.dart';

class OnOffSettingsPage extends StatefulWidget {
  const OnOffSettingsPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<OnOffSettingsPage> createState() => _OnOffSettingsPageState();
}

class _OnOffSettingsPageState extends State<OnOffSettingsPage> {
  bool _shutdownPayload = false;
  bool _offByButton = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final shutdown = await api.readShutdownPayloadEnable();
      final offByButton = await api.readOffByButton();
      if (!mounted) return;
      setState(() {
        _shutdownPayload = Lw006ParamHelpers.uint8(shutdown.data) == 1;
        _offByButton = Lw006ParamHelpers.uint8(offByButton.data) == 1;
      });
    });
  }

  Future<void> _toggle({
    required bool current,
    required Future<bool> Function(int value) write,
    required void Function(bool value) setLocal,
  }) async {
    final next = !current;
    setState(() => setLocal(next));
    await runWithBleLoading(context, () async {
      final ok = await write(next ? 1 : 0);
      if (!mounted) return;
      if (!ok) {
        setState(() => setLocal(current));
        showProtocolResultToast(context, ok: false);
        return;
      }
      await _load();
      if (mounted) {
        showProtocolResultToast(context, ok: true);
      }
    });
  }

  Future<void> _powerOff() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning!',
      message:
          'Are you sure to turn off the device? Please make sure the device has a button to turn on!',
      confirmText: 'OK',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(
      context,
      () => widget.session.protocol.writeCloseEmpty(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.session.protocol;
    return DetailScaffold(
      title: 'ON/OFF Settings',
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSwitchRow(
                  label: 'Shut-Down Payload',
                  value: _shutdownPayload,
                  onChanged: (_) => _toggle(
                    current: _shutdownPayload,
                    write: (v) => api.writeShutdownPayloadEnable([v]),
                    setLocal: (v) => _shutdownPayload = v,
                  ),
                ),
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'OFF by Button',
                  value: _offByButton,
                  onChanged: (_) => _toggle(
                    current: _offByButton,
                    write: (v) => api.writeOffByButton([v]),
                    setLocal: (v) => _offByButton = v,
                  ),
                ),
                const SettingsDivider(),
                SettingsNavRow(
                  title: 'Power Off',
                  onTap: _powerOff,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
