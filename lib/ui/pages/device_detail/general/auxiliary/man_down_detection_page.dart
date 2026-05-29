import 'package:flutter/material.dart';

import '../../../../../../ble/lw006_device_session.dart';
import '../../../../../../ble/lw006_option_lists.dart';
import '../../../../../../ble/lw006_param_helpers.dart';
import '../../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class ManDownDetectionPage extends StatefulWidget {
  const ManDownDetectionPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<ManDownDetectionPage> createState() => _ManDownDetectionPageState();
}

class _ManDownDetectionPageState extends State<ManDownDetectionPage> {
  bool _detection = false;
  bool _notifyStart = false;
  bool _notifyEnd = false;
  int _strategyIndex = 0;
  final _timeout = TextEditingController();
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
        api.readManDownDetectionEnable(),
        api.readManDownDetectionTimeout(),
        api.readManDownPosStrategy(),
        api.readManDownDetectionReportInterval(),
      ]);
      if (!mounted) return;
      final enable = Lw006ParamHelpers.uint8(results[0].data);
      _detection = (enable & 0x01) == 1;
      _notifyStart = (enable & 0x02) == 2;
      _notifyEnd = (enable & 0x04) == 4;
      _timeout.text = Lw006ParamHelpers.uint8(results[1].data).toString();
      _strategyIndex =
          Lw006ParamHelpers.uint8(results[2].data).clamp(0, Lw006OptionLists.posStrategy7.length - 1);
      _reportInterval.text = Lw006ParamHelpers.uint16(results[3].data).toString();
      setState(() {});
    });
  }

  bool _validate() {
    final timeout = int.tryParse(_timeout.text.trim());
    if (timeout == null || timeout < 1 || timeout > 120) return false;
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
    final enable = (_detection ? 1 : 0) | (_notifyStart ? 2 : 0) | (_notifyEnd ? 4 : 0);
    final timeout = int.parse(_timeout.text.trim());
    final interval = int.parse(_reportInterval.text.trim());
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeManDownDetectionEnable([enable]),
        api.writeManDownDetectionTimeout([timeout]),
        api.writeManDownPosStrategy([_strategyIndex]),
        api.writeManDownDetectionReportInterval(Lw006ParamHelpers.uint16Bytes(interval)),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Future<void> _pickStrategy() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw006OptionLists.posStrategy7,
      selectedIndex: _strategyIndex,
    );
    if (index != null) setState(() => _strategyIndex = index);
  }

  @override
  void dispose() {
    _timeout.dispose();
    _reportInterval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Man Down Detection',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              children: [
                SettingsSwitchRow(
                  label: 'Man Down Detection',
                  value: _detection,
                  onChanged: (v) => setState(() => _detection = v),
                ),
                SettingsLabelRow(
                  label: 'Detection Timeout',
                  child: SettingsTextField(
                    controller: _timeout,
                    hint: '1~120',
                    suffix: 'Mins',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Positioning Strategy',
                  child: BlueValueButton(
                    text: Lw006OptionLists.posStrategy7[_strategyIndex],
                    onTap: _pickStrategy,
                  ),
                ),
                SettingsLabelRow(
                  label: 'Report Interval',
                  child: SettingsTextField(
                    controller: _reportInterval,
                    hint: '10~600',
                    suffix: 's',
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                SettingsSwitchRow(
                  label: 'Notify Event On Man Down Start',
                  value: _notifyStart,
                  onChanged: (v) => setState(() => _notifyStart = v),
                ),
                SettingsSwitchRow(
                  label: 'Notify Event On Man Down End',
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
