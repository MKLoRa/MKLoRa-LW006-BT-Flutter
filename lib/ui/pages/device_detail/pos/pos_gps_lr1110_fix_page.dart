import 'package:flutter/material.dart';

import '../../../../../ble/lw006.dart';
import '../../../../../ble/lw006_device_session.dart';
import '../../../../../ble/lw006_option_lists.dart';
import '../../../../../ble/lw006_param_helpers.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';

class PosGpsLR1110FixPage extends StatefulWidget {
  const PosGpsLR1110FixPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<PosGpsLR1110FixPage> createState() => _PosGpsLR1110FixPageState();
}

class _PosGpsLR1110FixPageState extends State<PosGpsLR1110FixPage> {
  final _timeout = TextEditingController();
  final _satelliteThreshold = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  int _dataTypeIndex = 0;
  int _posSystemIndex = 0;
  bool _autonomousAiding = false;
  bool _ephemerisNotify = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readGpsPosTimeout(),
        api.readGpsPosSatelliteThreshold(),
        api.readGpsPosDataType(),
        api.readGpsPosSystem(),
        api.readGpsPosAutonomousAidingEnable(),
        api.readGpsPosAuxiliaryLatLon(),
        api.readGpsPosEphemerisNotifyEnable(),
      ]);
      if (!mounted) return;
      _timeout.text = Lw006ParamHelpers.uint16(results[0].data).toString();
      _satelliteThreshold.text = Lw006ParamHelpers.uint8(results[1].data).toString();
      _dataTypeIndex = Lw006ParamHelpers.uint8(results[2].data).clamp(0, 1);
      _posSystemIndex = Lw006ParamHelpers.uint8(results[3].data).clamp(0, 2);
      _autonomousAiding = Lw006ParamHelpers.uint8(results[4].data) == 1;
      final latLon = results[5].data;
      if (latLon.length >= 8) {
        _lat.text = Lw006ParamHelpers.int32(latLon.sublist(0, 4)).toString();
        _lon.text = Lw006ParamHelpers.int32(latLon.sublist(4, 8)).toString();
      }
      _ephemerisNotify = Lw006ParamHelpers.uint8(results[6].data) == 1;
      setState(() {});
    });
  }

  Future<void> _save() async {
    final timeout = int.tryParse(_timeout.text.trim());
    final threshold = int.tryParse(_satelliteThreshold.text.trim());
    if (timeout == null || timeout < 30 || timeout > 600 || threshold == null || threshold < 1 || threshold > 20) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final lat = int.tryParse(_lat.text.trim()) ?? 0;
      final lon = int.tryParse(_lon.text.trim()) ?? 0;
      final ok = (await Future.wait([
        api.writeGpsPosTimeout(Lw006ParamHelpers.uint16Bytes(timeout)),
        api.writeGpsPosSatelliteThreshold([threshold]),
        api.writeGpsPosDataType([_dataTypeIndex]),
        api.writeGpsPosSystem([_posSystemIndex]),
        api.writeGpsPosAutonomousAidingEnable([_autonomousAiding ? 1 : 0]),
        api.writeGpsPosAuxiliaryLatLon([
          ...Lw006ParamHelpers.int32Bytes(lat),
          ...Lw006ParamHelpers.int32Bytes(lon),
        ]),
        api.writeGpsPosEphemerisNotifyEnable([_ephemerisNotify ? 1 : 0]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _timeout.dispose();
    _satelliteThreshold.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'GPS Fix (LR1110)',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Position Timeout',
              child: SettingsTextField(controller: _timeout, hint: '30~600', suffix: 's'),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Satellite Threshold',
              child: SettingsTextField(controller: _satelliteThreshold, hint: '1~20'),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'GPS Data Type',
              child: BlueValueButton(
                text: Lw006OptionLists.gpsDataTypes[_dataTypeIndex],
                onTap: () async {
                  final index = await showBottomPicker(
                    context: context,
                    options: Lw006OptionLists.gpsDataTypes,
                    selectedIndex: _dataTypeIndex,
                  );
                  if (index != null) setState(() => _dataTypeIndex = index);
                },
              ),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'GPS Position System',
              child: BlueValueButton(
                text: Lw006OptionLists.gpsPosSystems[_posSystemIndex],
                onTap: () async {
                  final index = await showBottomPicker(
                    context: context,
                    options: Lw006OptionLists.gpsPosSystems,
                    selectedIndex: _posSystemIndex,
                  );
                  if (index != null) setState(() => _posSystemIndex = index);
                },
              ),
            ),
          ),
          SettingsCard(
            child: SettingsSwitchRow(
              label: 'Autonomous Aiding',
              value: _autonomousAiding,
              onChanged: (v) => setState(() => _autonomousAiding = v),
            ),
          ),
          if (_autonomousAiding) ...[
            SettingsCard(
              child: SettingsLabelRow(
                label: 'Auxiliary Latitude',
                child: SettingsTextField(controller: _lat, hint: 'Latitude'),
              ),
            ),
            SettingsCard(
              child: SettingsLabelRow(
                label: 'Auxiliary Longitude',
                child: SettingsTextField(controller: _lon, hint: 'Longitude'),
              ),
            ),
          ],
          SettingsCard(
            child: SettingsSwitchRow(
              label: 'Ephemeris Notify',
              value: _ephemerisNotify,
              onChanged: (v) => setState(() => _ephemerisNotify = v),
            ),
          ),
        ],
      ),
    );
  }
}
