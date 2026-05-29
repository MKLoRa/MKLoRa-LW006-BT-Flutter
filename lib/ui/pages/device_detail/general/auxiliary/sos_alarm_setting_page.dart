import 'package:flutter/material.dart';

import '../../../../../../ble/lw006_device_session.dart';
import '../../../../../../ble/lw006_option_lists.dart';
import '../../../../../../ble/lw006_param_helpers.dart';
import '../../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class SosAlarmSettingPage extends StatefulWidget {
  const SosAlarmSettingPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<SosAlarmSettingPage> createState() => _SosAlarmSettingPageState();
}

class _SosAlarmSettingPageState extends State<SosAlarmSettingPage> {
  int _triggerIndex = 0;
  int _strategyIndex = 0;
  bool _notifyStart = false;
  bool _notifyEnd = false;
  final _reportInterval = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readAlarmSosTriggerType(),
        api.readAlarmSosPosStrategy(),
        api.readAlarmSosReportInterval(),
        api.readAlarmSosNotifyEnable(),
      ]);
      if (!mounted) return;
      _triggerIndex =
          Lw006ParamHelpers.uint8(results[0].data).clamp(0, Lw006OptionLists.sosTriggerModes.length - 1);
      _strategyIndex =
          Lw006ParamHelpers.uint8(results[1].data).clamp(0, Lw006OptionLists.posStrategy7.length - 1);
      _reportInterval.text = Lw006ParamHelpers.uint16(results[2].data).toString();
      final notify = Lw006ParamHelpers.uint8(results[3].data);
      _notifyStart = (notify & 0x01) == 1;
      _notifyEnd = (notify & 0x02) == 2;
      setState(() {});
    });
  }

  bool _validate() {
    final interval = int.tryParse(_reportInterval.text.trim());
    return interval != null && interval >= 10 && interval <= 600;
  }

  Future<void> _save() async {
    if (!_validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    final notify = (_notifyStart ? 1 : 0) | (_notifyEnd ? 2 : 0);
    final interval = int.parse(_reportInterval.text.trim());
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeAlarmSosTriggerType([_triggerIndex]),
        api.writeAlarmSosPosStrategy([_strategyIndex]),
        api.writeAlarmSosReportInterval(Lw006ParamHelpers.uint16Bytes(interval)),
        api.writeAlarmSosNotifyEnable([notify]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _reportInterval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'SOS Alarm Settings',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Trigger Mode',
              child: BlueValueButton(
                text: Lw006OptionLists.sosTriggerModes[_triggerIndex],
                onTap: () async {
                  final index = await showBottomPicker(
                    context: context,
                    options: Lw006OptionLists.sosTriggerModes,
                    selectedIndex: _triggerIndex,
                  );
                  if (index != null) setState(() => _triggerIndex = index);
                },
              ),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Positioning Strategy',
              child: BlueValueButton(
                text: Lw006OptionLists.posStrategy7[_strategyIndex],
                onTap: () async {
                  final index = await showBottomPicker(
                    context: context,
                    options: Lw006OptionLists.posStrategy7,
                    selectedIndex: _strategyIndex,
                  );
                  if (index != null) setState(() => _strategyIndex = index);
                },
              ),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Report Interval',
              child: SettingsTextField(
                controller: _reportInterval,
                hint: '10~600',
                suffix: 's',
              ),
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                SettingsSwitchRow(
                  label: 'Notify Event On SOS Start',
                  value: _notifyStart,
                  onChanged: (v) => setState(() => _notifyStart = v),
                ),
                SettingsSwitchRow(
                  label: 'Notify Event On SOS End',
                  value: _notifyEnd,
                  onChanged: (v) => setState(() => _notifyEnd = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
