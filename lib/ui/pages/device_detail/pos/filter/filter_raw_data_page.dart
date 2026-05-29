import 'package:flutter/material.dart';

import '../../../../../../ble/lw006_device_session.dart';
import '../../../../../../ble/lw006_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';
import 'filter_bxp_button_page.dart';
import 'filter_bxp_ibeacon_page.dart';
import 'filter_bxp_tag_page.dart';
import 'filter_ibeacon_page.dart';
import 'filter_mk_pir_page.dart';
import 'filter_other_page.dart';
import 'filter_tlm_page.dart';
import 'filter_uid_page.dart';
import 'filter_url_page.dart';

/// Filter by Raw Data — layout/order aligned with native FilterRawDataSwitchActivity.
class FilterRawDataPage extends StatefulWidget {
  const FilterRawDataPage({super.key, required this.session});
  final Lw006DeviceSession session;

  @override
  State<FilterRawDataPage> createState() => _FilterRawDataPageState();
}

class _FilterRawDataPageState extends State<FilterRawDataPage> {
  bool _other = false;
  bool _ibeacon = false;
  bool _uid = false;
  bool _url = false;
  bool _tlm = false;
  bool _bxpAcc = false;
  bool _bxpTh = false;
  bool _bxpTag = false;
  bool _bxpDevice = false;
  bool _bxpButton = false;
  bool _pir = false;
  bool _bxpIbeacon = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final data = (await widget.session.protocol.readFilterRawData()).data;
      if (!mounted || data.length < 12) return;
      setState(() {
        _other = data[0] == 1;
        _ibeacon = data[1] == 1;
        _uid = data[2] == 1;
        _url = data[3] == 1;
        _tlm = data[4] == 1;
        _bxpAcc = data[5] == 1;
        _bxpTh = data[6] == 1;
        _bxpTag = data[7] == 1;
        _bxpDevice = data[8] == 1;
        _bxpButton = data[9] == 1;
        _pir = data[10] == 1;
        _bxpIbeacon = data[11] == 1;
      });
    });
  }

  Future<void> _openSubPage(Widget page) async {
    await pushDetailPage(context, page);
    if (mounted) await _load();
  }

  Future<void> _toggleBxp({
    required bool current,
    required Future<bool> Function(int value) write,
    required void Function(bool value) setLocal,
  }) async {
    final next = !current;
    setState(() => setLocal(next));
    await runWithBleLoading(context, () async {
      final ok = await write(next ? 1 : 0);
      if (!mounted) return;
      if (!ok) {
        setState(() => setLocal(current));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Opps！Save failed. Please check the input characters and try again.',
            ),
          ),
        );
        return;
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save Successfully！')),
        );
      }
    });
  }

  String _onOff(bool value) => value ? 'ON' : 'OFF';

  Widget _navRow({
    required String title,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SettingsNavRow(
      title: title,
      trailing: _onOff(enabled),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return DetailScaffold(
      title: 'Filter by Raw Data',
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _navRow(
                  title: 'iBeacon',
                  enabled: _ibeacon,
                  onTap: () => _openSubPage(FilterIbeaconPage(session: session)),
                ),
                const SettingsDivider(),
                _navRow(
                  title: 'Eddystone-UID',
                  enabled: _uid,
                  onTap: () => _openSubPage(FilterUidPage(session: session)),
                ),
                const SettingsDivider(),
                _navRow(
                  title: 'Eddystone-URL',
                  enabled: _url,
                  onTap: () => _openSubPage(FilterUrlPage(session: session)),
                ),
                const SettingsDivider(),
                _navRow(
                  title: 'Eddystone-TLM',
                  enabled: _tlm,
                  onTap: () => _openSubPage(FilterTlmPage(session: session)),
                ),
                const SettingsDivider(),
                _navRow(
                  title: 'BXP - iBeacon',
                  enabled: _bxpIbeacon,
                  onTap: () => _openSubPage(FilterBxpIbeaconPage(session: session)),
                ),
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'BXP - Device Info',
                  value: _bxpDevice,
                  onChanged: (_) => _toggleBxp(
                    current: _bxpDevice,
                    write: (v) => session.protocol.writeFilterBxpDevice([v]),
                    setLocal: (v) => _bxpDevice = v,
                  ),
                ),
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'BXP – ACC',
                  value: _bxpAcc,
                  onChanged: (_) => _toggleBxp(
                    current: _bxpAcc,
                    write: (v) => session.protocol.writeFilterBxpAcc([v]),
                    setLocal: (v) => _bxpAcc = v,
                  ),
                ),
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'BXP - T&H',
                  value: _bxpTh,
                  onChanged: (_) => _toggleBxp(
                    current: _bxpTh,
                    write: (v) => session.protocol.writeFilterBxpTh([v]),
                    setLocal: (v) => _bxpTh = v,
                  ),
                ),
                const SettingsDivider(),
                _navRow(
                  title: 'BXP - Button',
                  enabled: _bxpButton,
                  onTap: () => _openSubPage(FilterBxpButtonPage(session: session)),
                ),
                const SettingsDivider(),
                _navRow(
                  title: 'BXP - T&S',
                  enabled: _bxpTag,
                  onTap: () => _openSubPage(FilterBxpTagPage(session: session)),
                ),
                const SettingsDivider(),
                _navRow(
                  title: 'MK-PIR',
                  enabled: _pir,
                  onTap: () => _openSubPage(FilterMkPirPage(session: session)),
                ),
                const SettingsDivider(),
                _navRow(
                  title: 'Other',
                  enabled: _other,
                  onTap: () => _openSubPage(FilterOtherPage(session: session)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
