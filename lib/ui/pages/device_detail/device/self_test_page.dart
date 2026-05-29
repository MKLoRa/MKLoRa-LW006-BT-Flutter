import 'package:flutter/material.dart';

import '../../../../../ble/lw006_data_codec.dart';
import '../../../../../ble/lw006_device_session.dart';
import '../../../../../ble/lw006_option_lists.dart';
import '../../../../../ble/lw006_param_helpers.dart';
import '../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';

class SelfTestPage extends StatefulWidget {
  const SelfTestPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<SelfTestPage> createState() => _SelfTestPageState();
}

class _SelfTestPageState extends State<SelfTestPage> {
  bool _selftestOk = true;
  bool _gpsFail = false;
  bool _axisFail = false;
  bool _flashFail = false;
  int _pcbaStatus = 0;
  int _gpsModuleIndex = 0;
  String _motorState = '-';
  String _hwVersion = '-';
  Map<String, int>? _batteryInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readSelftestStatus(),
        api.readPcbaStatus(),
        api.readGpsModule(),
        api.readBatteryInfo(),
        api.readMotorState(),
        api.readHardwareVersion(),
      ]);
      if (!mounted) return;
      final selftest = Lw006DataCodec.decodeSelftestStatus(
        Lw006ParamHelpers.uint8(results[0].data),
      );
      final motor = Lw006ParamHelpers.uint8(results[4].data);
      final hw = Lw006ParamHelpers.uint8(results[5].data);
      setState(() {
        _selftestOk = selftest['ok']!;
        _gpsFail = selftest['gpsFail']!;
        _axisFail = selftest['axisFail']!;
        _flashFail = selftest['flashFail']!;
        _pcbaStatus = Lw006ParamHelpers.uint8(results[1].data);
        _gpsModuleIndex = Lw006ParamHelpers.uint8(results[2].data)
            .clamp(0, Lw006OptionLists.gpsModuleTypes.length - 1);
        _batteryInfo = Lw006DataCodec.decodeBatteryInfo(results[3].data);
        _motorState = motor == 0 ? 'Normal' : 'Fault';
        _hwVersion = hw == 0 ? 'No' : 'Traditional GPS module Supported';
      });
    });
  }

  Future<void> _showResetSuccess() {
    return showCommonConfirmDialog(
      context: context,
      message: 'Reset Successfully！',
      confirmText: 'OK',
      actionColor: BleScanViewModel.titleBarColor,
      barrierDismissible: false,
      showCancel: false,
    );
  }

  Future<void> _pickGpsModule() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw006OptionLists.gpsModuleTypes,
      selectedIndex: _gpsModuleIndex,
    );
    if (index == null || !mounted) return;
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = await api.writeGpsModule([index]);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opps！Save failed. Please check the input characters and try again.',
              ),
            ),
          );
        }
        return;
      }
      final result = await api.readGpsModule();
      if (!mounted) return;
      setState(() {
        _gpsModuleIndex = Lw006ParamHelpers.uint8(result.data)
            .clamp(0, Lw006OptionLists.gpsModuleTypes.length - 1);
      });
    });
  }

  Future<void> _batteryReset() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning！',
      message: 'Are you sure to reset battery?',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final writeOk = await api.writeBatteryResetEmpty();
      if (!writeOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opps！Save failed. Please check the input characters and try again.',
              ),
            ),
          );
        }
        return;
      }
      final result = await api.readBatteryInfo();
      if (!mounted) return;
      setState(() => _batteryInfo = Lw006DataCodec.decodeBatteryInfo(result.data));
      await _showResetSuccess();
    });
  }

  Future<void> _resetMotorState() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning!',
      message: 'Are you sure to reset motor state?',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final writeOk = await api.writeResetMotorStateEmpty();
      if (!writeOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opps！Save failed. Please check the input characters and try again.',
              ),
            ),
          );
        }
        return;
      }
      final result = await api.readMotorState();
      if (!mounted) return;
      final value = Lw006ParamHelpers.uint8(result.data);
      setState(() => _motorState = value == 0 ? 'Normal' : 'Fault');
      await _showResetSuccess();
    });
  }

  Widget _batteryLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: DeviceDetailTheme.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final battery = _batteryInfo;
    return DetailScaffold(
      title: 'Selftest Interface',
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Selftest Status:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DeviceDetailTheme.textPrimary,
                      ),
                    ),
                    if (_selftestOk) ...[
                      const SizedBox(width: 20),
                      const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (!_selftestOk) ...[
                  if (_gpsFail)
                    const Padding(
                      padding: EdgeInsets.only(left: 20, top: 4),
                      child: Text(
                        '1',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                  if (_axisFail)
                    const Padding(
                      padding: EdgeInsets.only(left: 20, top: 4),
                      child: Text(
                        '2',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                  if (_flashFail)
                    const Padding(
                      padding: EdgeInsets.only(left: 20, top: 4),
                      child: Text(
                        '3',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          SettingsCard(
            child: Row(
              children: [
                const Text(
                  'PCBA Status:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  '$_pcbaStatus',
                  style: const TextStyle(
                    fontSize: 15,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'GPS Positioning',
              child: BlueValueButton(
                text: Lw006OptionLists.gpsModuleTypes[_gpsModuleIndex],
                onTap: _pickGpsModule,
              ),
            ),
          ),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Battery information:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
                if (battery != null) ...[
                  _batteryLine('${battery['runtime']} s'),
                  _batteryLine('${battery['advTimes']} times'),
                  _batteryLine('${battery['flashTimes']} times'),
                  _batteryLine('${battery['axisDuration']} ms'),
                  _batteryLine('${battery['bleFixDuration']} ms'),
                  _batteryLine('${battery['wifiFixDuration']} ms'),
                  _batteryLine('${battery['gpsFixDuration']} s'),
                  _batteryLine('${battery['loraTransmissionTimes']} times'),
                  _batteryLine('${battery['loraPower']} mAS'),
                ],
              ],
            ),
          ),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsLabelRow(
                  label: 'Battery Reset',
                  child: BlueValueButton(
                    text: 'Reset',
                    minWidth: 70,
                    onTap: _batteryReset,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '*After replace with the new battery, need to click "Reset", otherwise the low power prompt will be unnormal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                SettingsLabelRow(
                  label: 'Motor State',
                  child: Text(
                    _motorState,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Reset Motor State',
                  child: BlueValueButton(
                    text: 'Reset',
                    minWidth: 70,
                    onTap: _resetMotorState,
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'HW Version',
              child: Text(
                _hwVersion,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
