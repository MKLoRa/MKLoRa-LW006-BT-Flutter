import 'package:flutter/material.dart';

import '../../../../../../ble/lw006_device_session.dart';
import '../../../../../../ble/lw006_option_lists.dart';
import '../../../../../../ble/lw006_param_helpers.dart';
import '../../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class AlarmFunctionPage extends StatefulWidget {
  const AlarmFunctionPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<AlarmFunctionPage> createState() => _AlarmFunctionPageState();
}

class _AlarmFunctionPageState extends State<AlarmFunctionPage> {
  int _alarmTypeIndex = 0;
  final _exitTime = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readAlarmType(),
        api.readAlarmExitTime(),
      ]);
      if (!mounted) return;
      _alarmTypeIndex = Lw006ParamHelpers.uint8(results[0].data).clamp(0, 2);
      _exitTime.text = Lw006ParamHelpers.uint8(results[1].data).toString();
      setState(() {});
    });
  }

  Future<void> _save() async {
    final exitTime = int.tryParse(_exitTime.text.trim());
    if (exitTime == null || exitTime < 5 || exitTime > 15) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeAlarmType([_alarmTypeIndex]),
        api.writeAlarmExitTime([exitTime]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _exitTime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Alarm Function',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Alarm Type',
              child: BlueValueButton(
                text: Lw006OptionLists.alarmTypes[_alarmTypeIndex],
                onTap: () async {
                  final index = await showBottomPicker(
                    context: context,
                    options: Lw006OptionLists.alarmTypes,
                    selectedIndex: _alarmTypeIndex,
                  );
                  if (index != null) setState(() => _alarmTypeIndex = index);
                },
              ),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Exit Alarm Time',
              child: SettingsTextField(
                controller: _exitTime,
                hint: '5~15',
                suffix: 's',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
