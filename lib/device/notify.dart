import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for the "a new merchant needs a category" prompt (doc 05). No content from the
/// SMS body is ever shown beyond the merchant name the parser already extracted — privacy-safe.
class Notify {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'category_prompts',
    'Category prompts',
    description: 'Asks you to categorise a newly-seen merchant',
    importance: Importance.high,
  );

  static Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission(); // Android 13+
  }

  /// Fire one notification per newly-seen uncategorised merchant.
  static Future<void> newMerchant(String merchant) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      merchant.hashCode & 0x7fffffff,
      'Categorise a new merchant',
      'Open Finman to set a category for "$merchant"',
      details,
    );
  }
}
