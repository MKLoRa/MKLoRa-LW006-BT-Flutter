import 'package:flutter/material.dart';

import '../../../../../ble/lw006.dart';
import '../../../../../ble/lw006_device_session.dart';
import '../../../../../ble/lw006_param_helpers.dart';
import '../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../lora/lora_app_setting_page.dart';
import '../lora/lora_conn_setting_page.dart';
import '../pos/pos_ble_and_gps_page.dart';
import '../pos/pos_ble_fix_page.dart';
import '../pos/pos_gps_l76c_fix_page.dart';
import '../pos/pos_gps_lr1110_fix_page.dart';
import '../pos/pos_wifi_fix_page.dart';

class LoRaTab extends StatefulWidget {
  const LoRaTab({super.key, required this.session});

  final Lw006DeviceSession session;

  @override
  State<LoRaTab> createState() => LoRaTabState();
}

class LoRaTabState extends State<LoRaTab> {
  String _status = '-';
  String _summary = '-';

  Future<void> load({bool showOverlay = true}) async {
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final region = await api.readLoraRegion();
        final mode = await api.readLoraMode();
        final status = await api.readLoraNetworkStatus();
        if (!mounted) return;
        setState(() {
          _status = Lw006ParamHelpers.uint8(status.data) == 1 ? 'Connected' : 'Connecting';
          final regionIndex =
              Lw006OptionLists.regionDeviceToPicker(Lw006ParamHelpers.uint8(region.data));
          final modeIndex = Lw006ParamHelpers.uint8(mode.data) - 1;
          final regionLabel = regionIndex >= 0 && regionIndex < Lw006OptionLists.loraRegions.length
              ? Lw006OptionLists.loraRegions[regionIndex]
              : 'EU868';
          final modeLabel = modeIndex >= 0 && modeIndex < Lw006OptionLists.loraUploadMode.length
              ? Lw006OptionLists.loraUploadMode[modeIndex]
              : 'OTAA';
          _summary = '$modeLabel/$regionLabel/ClassA';
        });
      },
      showOverlay: showOverlay,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          margin: EdgeInsets.zero,
          child: SettingsLabelRow(
            label: 'LoRaWAN Status',
            child: Text(
              _status,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DeviceDetailTheme.textPrimary,
              ),
            ),
          ),
        ),
        const SettingsDivider(),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Connection Setting',
            trailing: _summary,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoRaConnSettingPage(session: widget.session),
                ),
              );
              if (mounted) await load();
            },
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Application Setting',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LoRaAppSettingPage(session: widget.session),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PositionTab extends StatefulWidget {
  const PositionTab({super.key, required this.session});

  final Lw006DeviceSession session;

  @override
  State<PositionTab> createState() => PositionTabState();
}

class PositionTabState extends State<PositionTab> {
  bool _offlineFix = false;
  bool _gpsExtremeMode = false;

  Future<void> load({bool showOverlay = true}) async {
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final offline = await api.readOfflineLocationEnable();
        final extreme = await api.readGpsExtremeModeL76C();
        if (!mounted) return;
        setState(() {
          _offlineFix = Lw006ParamHelpers.uint8(offline.data) == 1;
          _gpsExtremeMode = Lw006ParamHelpers.uint8(extreme.data) == 1;
        });
      },
      showOverlay: showOverlay,
    );
  }

  Future<void> _toggleOfflineFix(bool value) async {
    await runWithBleLoading(context, () async {
      await widget.session.protocol.writeOfflineLocationEnable([value ? 1 : 0]);
      await load(showOverlay: false);
    });
  }

  Future<void> _toggleExtreme(bool value) async {
    await runWithBleLoading(context, () async {
      await widget.session.protocol.writeGpsExtremeModeL76C([value ? 1 : 0]);
      await load(showOverlay: false);
    });
  }

  Widget _gpsFixPage() {
    final deviceType = widget.session.deviceInfo.deviceType;
    if (deviceType == 0x01) {
      return PosGpsLR1110FixPage(session: widget.session);
    }
    return PosGpsL76CFixPage(session: widget.session);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          child: SettingsNavRow(
            title: 'WiFi Fix',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PosWifiFixPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Bluetooth Fix',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PosBleFixPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'GPS Fix',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _gpsFixPage()),
            ),
          ),
        ),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSwitchRow(
                label: 'Offline Fix',
                value: _offlineFix,
                onChanged: _toggleOfflineFix,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '* Whether to enable positioning when the device fails to connect to the Lorawan network',
                  style: TextStyle(
                    fontSize: 12,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'BLE&GPS',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PosBleAndGpsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsSwitchRow(
            label: 'GPS Extreme Mode',
            value: _gpsExtremeMode,
            onChanged: _toggleExtreme,
          ),
        ),
      ],
    );
  }
}
