class Lw006OptionLists {
  Lw006OptionLists._();

  static const posStrategy3 = ['WIFI', 'BLE', 'GPS'];
  static const posStrategy4 = ['WIFI', 'BLE', 'GPS', 'WIFI+GPS'];
  static const posStrategy5 = ['WIFI', 'BLE', 'GPS', 'WIFI+GPS', 'BLE+GPS'];
  static const posStrategy7 = [
    'WIFI',
    'BLE',
    'GPS',
    'WIFI+GPS',
    'BLE+GPS',
    'WIFI+BLE',
    'WIFI+BLE+GPS',
  ];
  static const posStrategy8 = [...posStrategy7, 'BLE&GPS'];

  static const loraUploadMode = ['ABP', 'OTAA'];
  static const loraRegions = [
    'AS923',
    'AU915',
    'EU868',
    'KR920',
    'IN865',
    'US915',
    'RU864',
    'AS923-1',
    'AS923-2',
    'AS923-3',
    'AS923-4',
  ];

  static const deviceModes = [
    'Standby Mode',
    'Timing Mode',
    'Periodic Mode',
    'Motion Mode',
  ];

  static const buzzerSounds = ['No', 'Alarm', 'Normal'];
  static const lowPowerPercents = ['10%', '20%', '30%', '40%', '50%', '60%'];
  static const wifiDataTypes = ['DAS', 'Customer'];
  static const gpsDataTypes = ['DAS', 'Customer'];
  static const gpsPosSystems = ['GPS', 'Beidou', 'GPS&Beidou'];

  static const alarmTypes = ['NO', 'Alert', 'SOS'];
  static const payloadTypes = ['Unconfirmed', 'Confirmed'];
  static const retransmissionTimes = ['0', '1', '2', '3'];

  static const bleFixMechanism = ['Time Priority', 'RSSI Priority'];
  static const wifiFixMechanism = ['RSSI Priority', 'Time Priority'];
  static const filterRelationship = [
    'Null',
    'Only MAC',
    'Only ADV Name',
    'Only Raw Data',
    'ADV Name&Raw Data',
    'MAC&ADV Name&Raw Data',
    'ADV Name | Raw Data',
  ];

  static const alertTriggerModes = [
    'Single Click',
    'Double Click',
    'Long Press 1s',
    'Long Press 2s',
    'Long Press 3s',
  ];

  static const sosTriggerModes = [
    'Double Click',
    'Triple Click',
    'Long Press 1s',
    'Long Press 2s',
    'Long Press 3s',
  ];

  static const txPowerLevels = [-40, -20, -16, -12, -8, -4, 0, 3, 4];

  static List<String> timeZones() {
    final zones = <String>[];
    for (var i = -24; i <= 28; i++) {
      if (i < 0) {
        if (i % 2 == 0) {
          zones.add('UTC${i ~/ 2}');
        } else {
          zones.add(i < -1 ? 'UTC${(i + 1) ~/ 2}:30' : 'UTC-0:30');
        }
      } else if (i == 0) {
        zones.add('UTC');
      } else if (i % 2 == 0) {
        zones.add('UTC+${i ~/ 2}');
      } else {
        zones.add('UTC+${(i - 1) ~/ 2}:30');
      }
    }
    return zones;
  }

  static int regionPickerToDevice(int index) {
    return index > 1 ? index + 3 : index;
  }

  static int regionDeviceToPicker(int value) {
    return value > 2 ? value - 3 : value;
  }
}
