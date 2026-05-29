class Lw006DisconnectEvent {
  const Lw006DisconnectEvent({
    required this.type,
    required this.message,
    this.fromNotification = true,
  });

  final int type;
  final String message;
  final bool fromNotification;

  static Lw006DisconnectEvent? fromNotificationBytes(List<int> value) {
    if (value.length < 5) {
      return null;
    }
    final header = value[0];
    final flag = value[1];
    final cmd = value[2] & 0xFF;
    final length = value[3];
    final type = value[4];
    if (header != 0xED || flag != 0x02 || cmd != 0x01 || length != 0x01) {
      return null;
    }
    return Lw006DisconnectEvent(
      type: type,
      message: messageForType(type),
      fromNotification: true,
    );
  }

  static String messageForType(int type) {
    switch (type) {
      case 1:
        return 'The device is disconnected!';
      case 2:
        return 'Password changed successfully! Please reconnect the device.';
      case 3:
        return 'No data communication for 3 minutes, the device is disconnected.';
      case 4:
        return 'Reboot successfully!\nPlease reconnect the device.';
      case 5:
        return 'Factory reset successfully!\nPlease reconnect the device.';
      default:
        return 'The device disconnected!';
    }
  }

  static const generic = Lw006DisconnectEvent(
    type: 0,
    message: 'The device disconnected!',
    fromNotification: false,
  );
}
