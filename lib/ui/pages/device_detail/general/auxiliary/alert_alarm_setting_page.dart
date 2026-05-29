import 'package:flutter/material.dart';

import '../../../../../../ble/lw006_device_session.dart';
import '../../../../../../ble/lw006_option_lists.dart';
import '../../../../../../ble/lw006_param_helpers.dart';
import '../../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class AlertAlarmSettingPage extends StatefulWidget {
  const AlertAlarmSettingPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<AlertAlarmSettingPage> createState() => _AlertAlarmSettingPageState();
}

class _AlertAlarmSettingPageState extends State<AlertAlarmSettingPage> {
  int _triggerIndex = 0;
  int _strategyIndex = 0;
  bool _notifyStart = false;
  bool _notifyEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readAlarmAlertTriggerType(),
        api.readAlarmAlertPosStrategy(),
        api.readAlarmAlertNotifyEnable(),
      ]);
      if (!mounted) return;
      _triggerIndex =
          Lw006ParamHelpers.uint8(results[0].data).clamp(0, Lw006OptionLists.alertTriggerModes.length - 1);
      _strategyIndex =
          Lw006ParamHelpers.uint8(results[1].data).clamp(0, Lw006OptionLists.posStrategy7.length - 1);
      final notify = Lw006ParamHelpers.uint8(results[2].data);
      _notifyStart = (notify & 0x01) == 1;
      _notifyEnd = (notify & 0x02) == 2;
      setState(() {});
    });
  }

  Future<void> _save() async {
    final notify = (_notifyStart ? 1 : 0) | (_notifyEnd ? 2 : 0);
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeAlarmAlertTriggerType([_triggerIndex]),
        api.writeAlarmAlertPosStrategy([_strategyIndex]),
        api.writeAlarmAlertNotifyEnable([notify]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Alert Alarm Settings',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Trigger Mode',
              child: BlueValueButton(
                text: Lw006OptionLists.alertTriggerModes[_triggerIndex],
                onTap: () async {
                  final index = await showBottomPicker(
                    context: context,
                    options: Lw006OptionLists.alertTriggerModes,
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
            child: Column(
              children: [
                SettingsSwitchRow(
                  label: 'Notify Event On Alert Start',
                  value: _notifyStart,
                  onChanged: (v) => setState(() => _notifyStart = v),
                ),
                SettingsSwitchRow(
                  label: 'Notify Event On Alert End',
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
