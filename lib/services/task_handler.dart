import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'database_services.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  // Called when the task is started.
  final _channel = WebSocketChannel.connect(Uri.parse('wss://echo.websocket.events'),);
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    if (kDebugMode) {
      print('onStart(starter: ${starter.name})');
    }
  }

  // Called based on the eventAction set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) async{
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10
        ),
      );

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'speedAccuracy': position.speedAccuracy,
        'altitudeAccuracy': position.altitudeAccuracy,
        'headingAccuracy': position.headingAccuracy,
      };

      await DatabaseServices.instance.insertLocation(locationData);
      _channel.sink.add(jsonEncode(locationData));
      debugPrint('Data sent Successfully');
      FlutterForegroundTask.sendDataToMain(locationData);
      debugPrint("Sent location: ${position.latitude}, ${position.longitude}");
      debugPrint("Time is: ${DateTime.timestamp()}");
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  // Called when the task is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (kDebugMode) {
      print('onDestroy(isTimeout: $isTimeout)');
    }
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    if (kDebugMode) {
      print('onReceiveData: $data');
    }
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    if (kDebugMode) {
      print('onNotificationButtonPressed: $id');
    }
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    if (kDebugMode) {
      print('onNotificationPressed');
    }
    FlutterForegroundTask.launchApp();
  }

  // Called when the notification itself is dismissed.
  @override
  void onNotificationDismissed() {
    if (kDebugMode) {
      print('onNotificationDismissed');
    }
  }
}
