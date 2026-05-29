import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nordic_dfu/nordic_dfu.dart';

class Lw006DfuException implements Exception {
  Lw006DfuException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Lw006DfuService {
  Lw006DfuService._();

  static Future<void> start({
    required String address,
    required String filePath,
    void Function(String status)? onStatus,
    void Function(int percent)? onProgress,
  }) async {
    final completer = Completer<void>();
    var connectAttempts = 0;
    var finished = false;

    void finishError(Object error) {
      if (finished) return;
      finished = true;
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    void finishSuccess() {
      if (finished) return;
      finished = true;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    onStatus?.call('Waiting...');
    debugPrint('[LW006 DFU] start address=$address file=$filePath');

    NordicDfu()
        .startDfu(
          address,
          filePath,
          darwinParameters: Platform.isIOS
              ? const DarwinParameters(
                  forceScanningForNewAddressInLegacyDfu: true,
                  alternativeAdvertisingNameEnabled: true,
                )
              : const DarwinParameters(),
          androidParameters: const AndroidParameters(
            keepBond: false,
            disableNotification: true,
            startAsForegroundService: false,
          ),
          dfuEventHandler: DfuEventHandler(
            onDeviceConnecting: (_) {
              connectAttempts++;
              onStatus?.call('Connecting...');
              if (connectAttempts > 3) {
                onStatus?.call('Error:DFU Failed');
                NordicDfu().abortDfu();
                finishError(Lw006DfuException('Error:DFU Failed'));
              }
            },
            onDfuProcessStarting: (_) => onStatus?.call('DfuProcessStarting...'),
            onEnablingDfuMode: (_) => onStatus?.call('EnablingDfuMode...'),
            onFirmwareValidating: (_) => onStatus?.call('FirmwareValidating...'),
            onProgressChanged: (_, percent, __, ___, ____, _____) {
              onProgress?.call(percent);
              onStatus?.call('Progress:$percent%');
            },
            onDfuAborted: (_) {
              onStatus?.call('DfuAborted...');
              finishError(Lw006DfuException('DfuAborted'));
            },
            onError: (_, __, ___, message) {
              debugPrint('[LW006 DFU] error: $message');
              finishError(
                Lw006DfuException(
                  message.isEmpty ? 'Opps!DFU Failed. Please try again!' : message,
                ),
              );
            },
            onDfuCompleted: (_) => finishSuccess(),
          ),
        )
        .then((_) => finishSuccess())
        .catchError((Object error) {
      debugPrint('[LW006 DFU] startDfu failed: $error');
      if (error is Lw006DfuException) {
        finishError(error);
      } else if (error is PlatformException) {
        finishError(Lw006DfuException(error.message ?? 'Opps!DFU Failed. Please try again!'));
      } else {
        finishError(Lw006DfuException('Opps!DFU Failed. Please try again!'));
      }
    });

    return completer.future;
  }
}
