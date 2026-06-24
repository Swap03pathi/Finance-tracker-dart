import 'package:flutter/services.dart';

/// Dart side of the native SMS bridge (MethodChannel "finman/sms"). Raw bodies stay on-device.
class SmsMessage {
  final String messageId;
  final String sender;
  final String body;
  final int timeMs;
  const SmsMessage(this.messageId, this.sender, this.body, this.timeMs);
  factory SmsMessage.fromMap(Map m) =>
      SmsMessage(m['messageId'] as String, m['sender'] as String, m['body'] as String, (m['timeMs'] as num).toInt());
}

class SmsChannel {
  static const _ch = MethodChannel('finman/sms');
  void Function(SmsMessage)? onSms;

  SmsChannel() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onSms' && onSms != null) {
        onSms!(SmsMessage.fromMap(Map<String, dynamic>.from(call.arguments as Map)));
      }
    });
  }

  Future<bool> requestPermission() async => (await _ch.invokeMethod<bool>('requestPermission')) ?? false;

  /// Launch catch-up sweep: inbox messages newer than the last-processed checkpoint.
  Future<List<SmsMessage>> querySweep(int sinceMs) async {
    final list = await _ch.invokeMethod<List<dynamic>>('querySweep', {'sinceMs': sinceMs}) ?? [];
    return list.map((e) => SmsMessage.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }
}
