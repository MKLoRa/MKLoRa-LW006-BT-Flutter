import 'package:flutter/material.dart';

import '../../models/ble_device_info.dart';
import '../../viewmodels/ble_scan_view_model.dart';

class DeviceItem extends StatelessWidget {
  final BleDeviceInfo device;
  final VoidCallback onConnect;

  const DeviceItem({super.key, required this.device, required this.onConnect});

  bool get _isLowPower => device.batteryPercent > 0 && device.batteryPercent <= 20;

  @override
  Widget build(BuildContext context) {
    final name = device.name.isNotEmpty ? device.name : device.id.str;
    final voltageV = device.batteryVoltageMv > 0
        ? '${(device.batteryVoltageMv / 1000).toStringAsFixed(3)}V'
        : 'N/AV';
    final txPowerLabel = device.txPowerLevel == null
        ? 'Tx Power:N/AdBm'
        : 'Tx Power:${device.txPowerLevel}dBm';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.signal_cellular_alt,
                            color: BleScanViewModel.titleBarColor,
                            size: 20,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${device.rssi}dBm',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'MAC:${device.advMacAddress.isNotEmpty ? device.advMacAddress : 'N/A'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 35,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BleScanViewModel.titleBarColor,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 0,
                        ),
                        onPressed: onConnect,
                        child: const Text(
                          'CONNECT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Column(
                        children: [
                          Image.asset(
                            _isLowPower
                                ? 'assets/images/lw006_low_battery.png'
                                : 'assets/images/ic_battery.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _isLowPower ? 'Low' : 'Full',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        txPowerLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                    Text(
                      voltageV,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 72,
                      child: Text(
                        device.scanIntervalLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
