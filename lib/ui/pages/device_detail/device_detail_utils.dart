import 'package:flutter/material.dart';

import '../../../ble/lw006_ble_client.dart';

Future<void> pushDetailPage(BuildContext context, Widget page) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

void showProtocolResultToast(BuildContext context, {required bool ok}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Save Successfully！'
            : 'Opps！Save failed. Please check the input characters and try again.',
      ),
    ),
  );
}

void showProtocolTimeoutToast(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(Lw006ProtocolTimeoutException.userMessage)),
  );
}

Future<bool> saveWithToast(
  BuildContext context,
  Future<bool> Function() save,
) async {
  final ok = await save();
  if (!context.mounted) {
    return ok;
  }
  showProtocolResultToast(context, ok: ok);
  return ok;
}
