import 'package:flutter/material.dart';

import '../../../../../../ble/lw006_device_session.dart';
import '../../../../../../ble/lw006_option_lists.dart';
import '../../../../../../ble/lw006_param_helpers.dart';
import '../../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class PeriodicModePage extends StatefulWidget {
  const PeriodicModePage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<PeriodicModePage> createState() => _PeriodicModePageState();
}

class _PeriodicModePageState extends State<PeriodicModePage> {
  int _strategyIndex = 0;
  final _interval = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final results = await Future.wait([
        widget.session.protocol.readPeriodicModePosStrategy(),
        widget.session.protocol.readPeriodicModeReportInterval(),
      ]);
      if (!mounted) return;
      _strategyIndex = Lw006ParamHelpers.uint8(results[0].data).clamp(0, 7);
      _interval.text = Lw006ParamHelpers.uint16(results[1].data).toString();
      setState(() {});
    });
  }

  Future<void> _pickStrategy() async {
    final index = await showBottomPicker(context: context, options: Lw006OptionLists.posStrategy8, selectedIndex: _strategyIndex);
    if (index != null) setState(() => _strategyIndex = index);
  }

  Future<void> _save() async {
    final value = int.tryParse(_interval.text.trim());
    if (value == null || value < 1 || value > 14400) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Para error!')));
      return;
    }
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writePeriodicModePosStrategy([_strategyIndex]),
        api.writePeriodicModeReportInterval(Lw006ParamHelpers.uint16Bytes(value)),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Periodic Mode',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Position Strategy',
              child: BlueValueButton(text: Lw006OptionLists.posStrategy8[_strategyIndex], onTap: _pickStrategy),
            ),
          ),
          SettingsCard(child: SettingsLabelRow(label: 'Report Interval', child: SettingsTextField(controller: _interval, hint: '1~14400', suffix: 'Mins'))),
        ],
      ),
    );
  }
}
