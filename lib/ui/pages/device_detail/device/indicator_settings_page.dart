import 'package:flutter/material.dart';

import '../../../../../ble/lw006_data_codec.dart';
import '../../../../../ble/lw006_device_session.dart';
import '../../../../../ble/lw006_param_helpers.dart';
import '../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';

class IndicatorSettingsPage extends StatefulWidget {
  const IndicatorSettingsPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<IndicatorSettingsPage> createState() => _IndicatorSettingsPageState();
}

class _IndicatorSettingsPageState extends State<IndicatorSettingsPage> {
  bool _deviceState = false;
  bool _lowPower = false;
  bool _bleAdvCheck = false;
  bool _networkCheck = false;
  bool _fix = false;
  bool _fixSuccess = false;
  bool _fixFail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final result = await widget.session.protocol.readIndicatorStatus();
      if (!mounted || result.data.isEmpty) return;
      final value = result.data.length >= 2
          ? Lw006ParamHelpers.uint16(result.data)
          : Lw006ParamHelpers.uint8(result.data);
      final decoded = Lw006DataCodec.decodeIndicator(value);
      setState(() {
        _deviceState = decoded['deviceState']!;
        _lowPower = decoded['lowPower']!;
        _bleAdvCheck = decoded['bleAdvCheck']!;
        _networkCheck = decoded['networkCheck']!;
        _fix = decoded['fix']!;
        _fixSuccess = decoded['fixSuccess']!;
        _fixFail = decoded['fixFail']!;
      });
    });
  }

  Future<void> _save() async {
    await runWithBleLoading(context, () async {
      final value = Lw006DataCodec.encodeIndicator(
        deviceState: _deviceState,
        fix: _fix,
        fixSuccess: _fixSuccess,
        fixFail: _fixFail,
        networkCheck: _networkCheck,
        lowPower: _lowPower,
        bleAdvCheck: _bleAdvCheck,
      );
      final ok = await widget.session.protocol
          .writeIndicatorStatus(Lw006ParamHelpers.single(value));
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Widget _groupCard(List<Widget> children) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Indicator Settings',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _groupCard([
            SettingsSwitchRow(
              label: 'Device State',
              value: _deviceState,
              onChanged: (v) => setState(() => _deviceState = v),
            ),
            const SettingsDivider(),
            SettingsSwitchRow(
              label: 'Low-power',
              value: _lowPower,
              onChanged: (v) => setState(() => _lowPower = v),
            ),
          ]),
          _groupCard([
            SettingsSwitchRow(
              label: 'Bluetooth Broadcast',
              value: _bleAdvCheck,
              onChanged: (v) => setState(() => _bleAdvCheck = v),
            ),
            const SettingsDivider(),
            SettingsSwitchRow(
              label: 'Network Check',
              value: _networkCheck,
              onChanged: (v) => setState(() => _networkCheck = v),
            ),
          ]),
          _groupCard([
            SettingsSwitchRow(
              label: 'In Fix',
              value: _fix,
              onChanged: (v) => setState(() => _fix = v),
            ),
            const SettingsDivider(),
            SettingsSwitchRow(
              label: 'Fix Successful',
              value: _fixSuccess,
              onChanged: (v) => setState(() => _fixSuccess = v),
            ),
            const SettingsDivider(),
            SettingsSwitchRow(
              label: 'Fail To Fix',
              value: _fixFail,
              onChanged: (v) => setState(() => _fixFail = v),
            ),
          ]),
        ],
      ),
    );
  }
}
