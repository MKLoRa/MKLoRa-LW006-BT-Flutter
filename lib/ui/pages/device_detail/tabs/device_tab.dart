import 'package:flutter/material.dart';

import '../../../../../ble/lw006.dart';
import '../../../../../ble/lw006_device_session.dart';
import '../../../../../ble/lw006_param_helpers.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';
import '../device/export_data_page.dart';
import '../device/indicator_settings_page.dart';
import '../device/on_off_settings_page.dart';
import '../device/system_info_page.dart';
import '../device_detail_utils.dart';

class DeviceTab extends StatefulWidget {
  const DeviceTab({super.key, required this.session, required this.onSaveReady});

  final Lw006DeviceSession session;
  final void Function(Future<bool> Function() save) onSaveReady;

  @override
  State<DeviceTab> createState() => DeviceTabState();
}

class DeviceTabState extends State<DeviceTab> {
  int _timeZoneIndex = 40;
  bool _lowPowerPayload = true;
  int _lowPowerPercentIndex = 0;
  int _buzzerIndex = 0;
  int _vibrationIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.onSaveReady(_save);
  }

  Future<void> reload({bool showOverlay = true}) async {
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final timeZone = await api.readTimeZone();
        final payload = await api.readLowPowerPayloadEnable();
        final lowPowerPercent = await api.readLowPowerPercent();
        final buzzer = await api.readBuzzerSoundChoose();
        final vibration = await api.readVibrationIntensity();
        if (!mounted) return;
        setState(() {
          _timeZoneIndex = Lw006ParamHelpers.timeZoneIndexFromBytes(timeZone.data);
          _lowPowerPayload = Lw006ParamHelpers.uint8(payload.data) == 1;
          _lowPowerPercentIndex =
              Lw006ParamHelpers.uint8(lowPowerPercent.data).clamp(0, 5);
          _buzzerIndex = Lw006ParamHelpers.uint8(buzzer.data).clamp(0, 2);
          _vibrationIndex = Lw006OptionLists.vibrationPickerIndex(
            Lw006ParamHelpers.uint8(vibration.data),
          );
        });
      },
      showOverlay: showOverlay,
    );
  }

  Future<bool> _save() async {
    final api = widget.session.protocol;
    final results = await Future.wait([
      api.writeTimeZone(Lw006ParamHelpers.timeZoneBytesFromIndex(_timeZoneIndex)),
      api.writeLowPowerPayloadEnable([_lowPowerPayload ? 1 : 0]),
      api.writeLowPowerPercent([_lowPowerPercentIndex]),
    ]);
    return results.every((r) => r);
  }

  Future<void> _pickLowPowerPercent() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw006OptionLists.lowPowerPercents,
      selectedIndex: _lowPowerPercentIndex,
    );
    if (index != null) setState(() => _lowPowerPercentIndex = index);
  }

  Future<void> _pickTimeZone() async {
    final zones = Lw006OptionLists.timeZones();
    final index = await showBottomPicker(
      context: context,
      options: zones,
      selectedIndex: _timeZoneIndex,
    );
    if (index != null) setState(() => _timeZoneIndex = index);
  }

  Future<void> _pickBuzzer() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw006OptionLists.buzzerSounds,
      selectedIndex: _buzzerIndex,
    );
    if (index == null || !mounted) return;
    setState(() => _buzzerIndex = index);
    await runWithBleLoading(context, () async {
      final ok = await widget.session.protocol.writeBuzzerSoundChoose([index]);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Future<void> _pickVibration() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw006OptionLists.vibrationIntensities,
      selectedIndex: _vibrationIndex,
    );
    if (index == null || !mounted) return;
    setState(() => _vibrationIndex = index);
    await runWithBleLoading(context, () async {
      final value = Lw006OptionLists.vibrationDeviceValue(index);
      final ok = await widget.session.protocol.writeVibrationIntensity([value]);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Future<void> _factoryReset() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      message: 'Are you sure you want to factory reset?',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () => widget.session.protocol.writeResetEmpty());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zones = Lw006OptionLists.timeZones();
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          child: SettingsNavRow(
            title: 'Local Data Sync',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExportDataPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Indicator Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IndicatorSettingsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsLabelRow(
            label: 'Buzzer',
            child: BlueValueButton(
              text: Lw006OptionLists.buzzerSounds[_buzzerIndex],
              onTap: _pickBuzzer,
            ),
          ),
        ),
        SettingsCard(
          child: SettingsLabelRow(
            label: 'Vibration Intensity',
            child: BlueValueButton(
              text: Lw006OptionLists.vibrationIntensities[_vibrationIndex],
              onTap: _pickVibration,
            ),
          ),
        ),
        SettingsCard(
          child: SettingsLabelRow(
            label: 'Current Time Zone',
            child: BlueValueButton(
              text: zones[_timeZoneIndex.clamp(0, zones.length - 1)],
              onTap: _pickTimeZone,
            ),
          ),
        ),
        SettingsCard(
          child: Column(
            children: [
              SettingsSwitchRow(
                label: 'Low-power Payload',
                value: _lowPowerPayload,
                onChanged: (v) => setState(() => _lowPowerPayload = v),
              ),
              const SizedBox(height: 16),
              SettingsLabelRow(
                label: 'Low-power Percent',
                child: BlueValueButton(
                  text: Lw006OptionLists.lowPowerPercents[_lowPowerPercentIndex],
                  onTap: _pickLowPowerPercent,
                ),
              ),
            ],
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'On/Off Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OnOffSettingsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Device Information',
            onTap: () async {
              final result = await Navigator.of(context).push<SystemInfoDfuResult>(
                MaterialPageRoute(
                  builder: (_) => SystemInfoPage(session: widget.session),
                ),
              );
              if (!context.mounted) return;
              if (result == SystemInfoDfuResult.success ||
                  result == SystemInfoDfuResult.failed) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Factory Reset',
            onTap: _factoryReset,
          ),
        ),
      ],
    );
  }
}
