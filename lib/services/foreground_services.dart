import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sales_man_tracking/services/task_handler.dart';

class ForegroundServices{

  static Future<void> startForegroundTask() async {
    await FlutterForegroundTask.startService(
        notificationTitle: 'Location Tracking',
        notificationText: 'Tracking location every 5 seconds...',
        callback: startCallback
    );
  }

  static Future<void> stopForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    } else{
      debugPrint('Service is not running.');
    }
  }
}