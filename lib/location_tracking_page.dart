import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sales_man_tracking/services/database_services.dart';
import 'package:sales_man_tracking/services/foreground_services.dart';
import 'package:sales_man_tracking/services/init_foreground_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'location_history_page.dart';
import 'model/location_data_model.dart';

class LocationTrackingPage extends StatefulWidget {
  const LocationTrackingPage({super.key});

  @override
  State<LocationTrackingPage> createState() => _LocationTrackingPageState();
}

class _LocationTrackingPageState extends State<LocationTrackingPage> {

  List<LocationModel> _locations = [];
  Timer? _timer;
  final _channel = WebSocketChannel.connect(Uri.parse('wss://echo.websocket.events'));

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await requestPermissions();
    await InitForeGroundService.initForegroundTask();
    _loadLocations();
    // // Rebuild every 5 seconds
    // _timer = Timer.periodic(Duration(seconds: 5), (timer) {
    //   setState(() {
    //     _loadLocations();
    //   });
    // });
  }


  Future<void> _loadLocations() async {
    List locations = await DatabaseServices.instance.getAllLocations();
    setState(() {
      _locations = locations.map<LocationModel>((loc) => LocationModel.fromMap(loc)).toList();
    });
  }

  bool isLocationOn = false;
  bool isLocationAlwaysOn = false;
  bool isBatteryOptimization = true;
  bool isNotificationOn = false;

  Future<void> requestPermissions() async {
    try {
      // Step 1: Request Location permission
      var locationStatus = await Permission.location.request();
      setState(() {
        isLocationOn = locationStatus.isGranted;
      });
      if (locationStatus.isGranted) {
        debugPrint('Location permission granted');
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Location permission granted')),
        // );
      } else if (locationStatus.isDenied) {
        await Permission.location.request();
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Location permission denied')),
        // );
        debugPrint('Location permission denied');
        return; // Stop if denied
      } else if (locationStatus.isPermanentlyDenied) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Location permission permanently denied. Please enable it in settings.'),
        //   ),
        // );
        debugPrint('Location permission permanently denied. Please enable it in settings.');
        await openAppSettings(); // Open settings if permanently denied
        return;
      }

      // Step 2: Request Location Always permission (for background location)
      var locationAlwaysStatus = await Permission.locationAlways.request();
      setState(() {
        isLocationAlwaysOn = locationAlwaysStatus.isGranted;
      });
      if (locationAlwaysStatus.isGranted) {
        debugPrint('Location Always permission granted');
      } else if (locationAlwaysStatus.isDenied) {
        await Permission.locationAlways.request();
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Location Always permission denied')),
        // );
        debugPrint('Location Always permission denied');
        return; // Stop if denied
      } else if (locationAlwaysStatus.isPermanentlyDenied) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Location Always permission permanently denied. Please enable it in settings.'),
        //   ),
        // );
        debugPrint('Location Always permission permanently denied. Please enable it in settings.');
        await openAppSettings();
        return;
      }

      // Step 3: Request Ignore Battery Optimizations permission
      var batteryStatus = await Permission.ignoreBatteryOptimizations.request();
      setState(() {
        isBatteryOptimization = batteryStatus.isGranted;
      });
      if (batteryStatus.isGranted) {
        debugPrint('Battery optimization disabled');
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Battery optimization disabled')),
        // );
      } else if (batteryStatus.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Battery optimization permission denied')),
        // );
        debugPrint('Battery optimization permission denied');
      } else if (batteryStatus.isPermanentlyDenied) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Battery optimization permission permanently denied. Please enable it in settings.'),
        //   ),
        // );
        debugPrint('Battery optimization permission permanently denied. Please enable it in settings.');
        await openAppSettings();
        return;
      }

      // Step 4: Request notification permission
      var notificationStatus = await Permission.notification.request();
      setState(() {
        isNotificationOn = notificationStatus.isGranted;
      });
      if (notificationStatus.isGranted) {
        debugPrint('Notification permission granted');
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Notification permission granted')),
        // );
      } else if (notificationStatus.isDenied) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Notification permission denied')),
        // );
        debugPrint('Notification permission denied');
        await Permission.notification.request();
        return; // Stop if denied
      } else if (notificationStatus.isPermanentlyDenied) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Notification permission permanently denied. Please enable it in settings.'),
        //   ),
        // );
        debugPrint('Notification permission permanently denied. Please enable it in settings.');
        await openAppSettings(); // Open settings if permanently denied
        return;
      }

    } catch(e){
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => LocationHistoryPage())),
              icon: Icon(Icons.history))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ForegroundServices.startForegroundTask();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                ElevatedButton(
                  onPressed: () {
                    ForegroundServices.stopForegroundTask();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Stop',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
                child: _locations.isEmpty? Text("Loading..."):
                Text("Loaded...")
              // ListView.builder(
              //   itemCount: _locations.length,
              //   itemBuilder: (context, index) {
              //     final location = _locations[index];
              //     return Card(
              //       elevation: 2,
              //       margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
              //       child: ListTile(
              //         contentPadding: const EdgeInsets.all(10),
              //         title: Text(
              //             'Lat: ${location.latitude}, Long: ${location.longitude}',
              //             style: const TextStyle(
              //                 fontSize: 16,
              //                 fontWeight: FontWeight.w500
              //             )
              //         ),
              //         subtitle: Column(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             Text(
              //               'Accuracy: ${location.accuracy} m',
              //               style: const TextStyle(
              //                   fontSize: 14,
              //                   color: Colors.black54
              //               ),
              //             ),
              //             Text(
              //               'Timestamp: ${location.timestamp
              //                   .toString()
              //                   .substring(0, 19)}',
              //               style: const TextStyle(
              //                   fontSize: 14,
              //                   color: Colors.black54
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     );
              //   },
              // )
            ),
            Expanded(
                child: StreamBuilder(
                  stream: _channel.stream,
                  builder: (context, snapshot) {
                    return Text(snapshot.hasData ? '${snapshot.data}' : '');
                  },
                )
            ),
          ],
        ),
      ),
    );
  }
}