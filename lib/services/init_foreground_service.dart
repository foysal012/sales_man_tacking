import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class InitForeGroundService{

  static Future<void> initForegroundTask() async {
    try {

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        debugPrint("Already Initialize...");
        return;
      }

      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'location_channel_id',
          channelName: 'Location Tracking',
          channelDescription: 'Track location in foreground/background/terminated',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          showBadge: true,
          playSound: false,

        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: true,
          autoRunOnMyPackageReplaced: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    } catch (e, stack) {
      debugPrint("ForegroundTask init failed: $e\n$stack");
    }
  }

}