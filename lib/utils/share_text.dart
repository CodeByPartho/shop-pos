import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Share [text] through the system share sheet (WhatsApp, SMS, and so
/// on). On web, or anywhere the share sheet is unavailable, the text is
/// copied to the clipboard instead and the caller is told so.
/// Returns true when the share sheet opened, false when it fell back
/// to copying.
Future<bool> shareOrCopyText(BuildContext context, String text) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(text: text),
    );
    return result.status == ShareResultStatus.success ||
        result.status == ShareResultStatus.dismissed;
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing is not available here, text copied.'),
        ),
      );
    }
    return false;
  }
}
