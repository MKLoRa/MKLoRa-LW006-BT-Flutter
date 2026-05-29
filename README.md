# MKLoRa LW006 Flutter

Flutter client for LW006 devices. Supports BLE scanning, connection, parameter read/write, disconnect notifications, local storage data sync, and Nordic DFU firmware updates on Android and iOS physical devices.

Native Android reference project: `LW006-BT_Android`.

## Requirements

- Flutter SDK `^3.12.0`
- Android / iOS **physical device** (simulators do not support BLE)
- iOS: grant Bluetooth permission on first launch; run `pod install` in `ios/` when using CocoaPods

## Quick Start

```bash
flutter pub get
flutter run
```

The app opens on the scan page. Tap **CONNECT** on a device to connect and open the detail page.

---

## Project Structure

```
lib/
├── ble/                    # BLE connection and LW006 protocol layer
│   ├── lw006_ble_client.dart       # Connect, read/write frames, Notify handling
│   ├── lw006_protocol_api.dart     # Generic readParam / writeParam
│   ├── lw006_protocol_named_api.dart  # Named helpers (readLoraMode, etc.)
│   ├── lw006_device_session.dart   # Session wrapper (connection + API entry)
│   ├── lw006_protocol_logger.dart  # Debug protocol logging
│   ├── lw006_data_codec.dart       # Payload encode/decode (filters, storage notify)
│   ├── lw006_export_data_store.dart # In-memory tracked log cache
│   └── lw006_tracked_file.dart     # tracked.txt persistence (Local Data Sync)
├── dfu/                    # Nordic DFU upgrade
├── models/                 # Scan result models
├── viewmodels/             # Scan page ViewModel
└── ui/                     # Pages and widgets
```

---

## 1. Scanning for Devices

Scanning is handled by `BleScanViewModel` via `flutter_blue_plus`, filtering LW006 advertisements by:

- Service Data UUID: `0000aa0d-0000-1000-8000-00805f9b34fb`
- Parsed fields (aligned with native `BleDeviceInfo`):
  - `deviceType` at byte 0
  - `lowPowerState` at bit 4 of byte 1
  - `passwordEnabled` at bit 5 of byte 1
  - `batteryVoltageMv` at bytes 2–3
  - Scan interval derived from successive advertisement timestamps

### Usage in UI Code

```dart
final vm = BleScanViewModel();
await vm.init(context);                    // Start scanning
await vm.startScan(context: context, clearDevices: true);
vm.stopScan();

final devices = vm.filteredDevices;        // Sorted by RSSI
await vm.applyFilter(context: context, keyword: 'LW006', rssiDbm: -80);
```

### Scan Result Model

```dart
for (final device in vm.filteredDevices) {
  print(device.name);
  print(device.macAddress);       // From advertisement Service Data
  print('${device.rssi}dBm');
  print(device.scanIntervalLabel);  // "<->N/A" or "<->1234ms"
  print(device.passwordEnabled);    // Whether a password is required
}
```

---

## 2. Connecting to a Device

Scanning stops before connecting. A GATT connection is established and the password is verified when required. Returns a `Lw006DeviceSession`.

```dart
import 'package:lw006_flutter/ble/lw006.dart';

// Pick a device from the scan list
final device = vm.filteredDevices.first;

// If device.passwordEnabled == true, prompt the user for a password first
final session = await vm.connectDevice(
  context: context,
  device: device,
  password: device.passwordEnabled ? '123456' : null,
);

// Or use the lower-level API directly
final session = await Lw006DeviceSession.connect(
  deviceInfo: device,
  password: '123456',
);
```

After a successful connection:

- `session.protocol` — parameter read/write API
- `session.deviceInfoApi` — standard Device Information characteristics (model, SN, firmware version, etc.)
- `session.client.disconnectEvents` — device-initiated disconnect notifications
- `session.client.storageNotifyEvents` — local storage data sync (AA05 notify)
- `session.exportData` — in-memory cache for Local Data Sync UI

Connection details (`Lw006BleClient.connectWithRetry`):

- Up to 5 retries, 50s total timeout
- Android requests MTU 247; iOS negotiates MTU automatically
- Waits 500ms after connect before sending protocol frames

---

## 3. Reading and Writing Protocol Parameters

Frame format: `ED [flag] [cmd] [subCmd] [len] [data...]`

- `flag=0x00` read, `flag=0x01` write, `flag=0x02` notify
- Responses arrive asynchronously via Notify characteristics
- Multi-packet responses use head `0xEE` and are reassembled automatically

Parameter keys follow native `ParamsKeyEnum` in `LW006_CT_Android` (`lib/ble/lw006_param_key.dart`).

### 3.1 Named API (Recommended)

`Lw006ProtocolNamedReadApi` / `Lw006ProtocolNamedWriteApi` provide semantic methods for each parameter:

```dart
final api = session.protocol;

// Read LoRa mode (OTAA=2, ABP=1)
final mode = await api.readLoraMode();
print(Lw006ParamHelpers.uint8(mode.data));   // Payload bytes
print(mode.raw);                             // Full response frame

// Read LoRa region
final region = await api.readLoraRegion();

// Read advertisement name
final advName = await api.readAdvName();
print(Lw006ParamHelpers.bytesToString(advName.data));

// Write time zone (picker index → device byte, see timeZoneBytesFromIndex)
final ok = await api.writeTimeZone(Lw006ParamHelpers.timeZoneBytesFromIndex(32));
if (ok) print('write success');

// Write LoRa OTAA mode
await api.writeLoraMode([2]);

// Sync UTC time (called automatically when entering the detail page)
await api.syncTime();

// Trigger reboot (some writes require reboot to take effect)
await api.writeRebootEmpty();
```

Integer payloads use **big-endian** byte order (`Lw006ParamHelpers.int32Bytes`, `uint16Bytes`, `bytesToInt`), matching native `MokoUtils.toInt` / `toByteArray`.

### 3.2 Generic API

Read and write any parameter via `Lw006ParamKey`:

```dart
// Read
final result = await api.readParam(Lw006ParamKey.advTxPower);
final txPower = Lw006ParamHelpers.byte0(result.data);

// Write heartbeat interval (4 bytes, native setHeartBeatInterval)
await api.writeHeartbeatInterval(Lw006ParamHelpers.int32Bytes(300));
```

### 3.3 GATT Device Information

```dart
final info = session.deviceInfoApi;
final model = await info.readModelNumber();
final firmware = await info.readFirmwareRevision();
final serial = await info.readSerialNumber();
```

### 3.4 Return Values

| Type | Field | Description |
|------|-------|-------------|
| `Lw006ParamResult` | `data` | Parsed payload bytes |
| | `raw` | Full frame returned by the device |
| | `cmd` / `subCmd` | Parameter command bytes |
| `writeParam` | returns `bool` | `true` when write ACK byte is `0x01` |

Common parsing helpers are in `Lw006ParamHelpers`: `uint8`, `uint16`, `int32`, `bytesToInt`, `bytesToString`, `hexToBytes`, etc.

---

## 4. Receiving Data (Notify)

Device responses and push data are delivered via BLE Notify. `Lw006BleClient` matches incoming frames to pending requests and completes the corresponding `Future`.

### 4.1 Protocol Responses (AA02 params)

Each `readParam` / `writeParam` call:

1. Writes a request frame to the params characteristic (TX)
2. Waits for a Notify response with the same `cmd/subCmd` (RX)
3. Reassembles multi-packet responses when `head=0xEE`

You do not need to subscribe to the params characteristic manually — use the API directly.

### 4.2 Disconnect Notifications (AA01)

Listen for device-initiated disconnects via `session.client.disconnectEvents`:

```dart
session.client.disconnectEvents.listen((event) {
  print('type=${event.type}');
  print(event.message);
  // type: 1=password timeout 2=password changed 3=3-min idle 4=reboot 5=factory reset
});
```

Example raw Notify frame:

```
ED 02 00 01 01 04   → type=4, device rebooted
```

The detail page handles this globally: on any sub-page, a dialog is shown and the user is returned to the scan page to rescan after confirming.

### 4.3 Local Data Sync (AA05 storage)

Storage notify frames are parsed by `Lw006DataCodec.parseStorageNotify` and exposed on `session.client.storageNotifyEvents`:

```dart
session.client.storageNotifyEvents.listen((event) {
  if (event.records != null) {
    session.exportData.appendRecords(event.records!, insertAtHead: false);
  }
  if (event.totalSum != null) {
    session.exportData.totalSum = event.totalSum;
  }
});
```

UI flow (Device tab → **Local Data Sync**, aligned with native `ExportDataActivity`):

1. **Start** — `readStorageData(days)`; list shows parsed `Time` / `Raw Data`; **Sync** becomes **Stop**; **Start** disabled
2. **Stop** — `setStorageSyncEnabled(false)`; **Start** enabled again; user may change **Time** and restart
3. **Export** — writes cache to `{appDocuments}/LW006/tracked.txt`, then opens the system share sheet (email with attachment)

---

## 5. Disconnecting

### Manual Disconnect

```dart
await session.disconnect();
// or
await vm.disconnectDevice();
await vm.onReturnedFromDetail(context);  // Disconnect + clear list and rescan
```

### Unexpected Disconnect

When the device sends a disconnect Notify or the BLE link drops, `disconnectEvents` emits an event. The detail page flow:

1. Show a dialog (OK only)
2. Call `session.disconnect()`
3. `popUntil` back to the scan page
4. Scan page `onReturnedFromDetail` restarts scanning

Disconnect events are ignored during DFU to avoid false dialogs.

---

## 6. DFU Firmware Update

UI entry: **Device tab → System Information → DFU**

Flow (`Lw006DfuService` + `nordic_dfu`):

1. User selects a `.zip` firmware package
2. MAC address is saved; current GATT connection is closed
3. DFU progress dialog is shown
4. Nordic DFU starts using the MAC address
5. Success: shows *Update firmware successfully! Please reconnect the device.* and returns to the scan page
6. Failure: error shown via SnackBar

### Code Example

```dart
import 'package:lw006_flutter/dfu/lw006_dfu_coordinator.dart';
import 'package:lw006_flutter/dfu/lw006_dfu_service.dart';

Lw006DfuCoordinator.begin(mac: device.macAddress);
await session.disconnect();

await Lw006DfuService.start(
  address: device.macAddress,
  filePath: '/path/to/firmware.zip',
  onStatus: (status) => print(status),    // Connecting..., Progress:45%
  onProgress: (percent) => print('$percent%'),
);

Lw006DfuCoordinator.end();
// Rescan and reconnect after the update completes
```

Notes:

- Firmware package must be a **ZIP** file
- Do not rely on the original GATT session during DFU; the device reboots when done
- On iOS, disable Swift Package Manager in `pubspec.yaml` to use the CocoaPods NordicDFU build

---

## 7. Debug Protocol Logging

In debug builds, the console prints all TX/RX frames for protocol inspection:

```
[LW006 TX] params | READ loraMode (0x0502) | frame=ED 00 05 02 00
[LW006 RX] params | loraMode (0x0502) | frame=ED 00 05 02 01 02 | data=02
```

Disable logging:

```dart
Lw006ProtocolLogger.enabled = false;
```

---

## 8. Permissions

| Platform | Permissions |
|----------|-------------|
| Android | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, location (required for scanning) |
| iOS | `NSBluetoothAlwaysUsageDescription` (configured in Info.plist) |

---

## 9. Typical Flow

```
Scan page
  └─ startScan → device list (Service Data AA17)
  └─ connectDevice → Lw006DeviceSession
       └─ Detail page (General / LoRa / Position / Device tabs)
            ├─ protocol.readXxx / writeXxx
            ├─ storageNotifyEvents → Local Data Sync list
            ├─ disconnectEvents → dialog → back to scan page
            └─ DFU → pick zip → upgrade → back to scan page and reconnect
```

---

## Repository

- GitHub: [MKLoRa/MKLoRa-LW006-Flutter](https://github.com/MKLoRa/MKLoRa-LW006-Flutter)
