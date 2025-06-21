import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocationDatabase {
  static final LocationDatabase instance = LocationDatabase._init();
  static Database? _database;

  LocationDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('locations.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            accuracy REAL,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertLocation(Map<String, dynamic> location) async {
    final db = await database;
    await db.insert('locations', {
      'latitude': location['latitude'],
      'longitude': location['longitude'],
      'accuracy': location['accuracy'],
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllLocations() async {
    final db = await database;
    return await db.query('locations', orderBy: 'timestamp DESC');
  }

  Future<void> clearLocations() async {
    final db = await database;
    await db.delete('locations');
  }
}

class LocationTrackingPage extends StatefulWidget {
  const LocationTrackingPage({super.key});

  @override
  State<LocationTrackingPage> createState() => _LocationTrackingPageState();
}

class _LocationTrackingPageState extends State<LocationTrackingPage> {

  List<Map<String, dynamic>> _locations = [];
  bool _isTracking = false;
  bool _isPaused = false;
  ReceivePort? _receivePort;
  StreamSubscription? _portSubscription;
  final LocationDatabase _db = LocationDatabase.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initializePage();
    });
  }

  Future<void> _initializePage() async {
    await _checkAndRequestPermissions();
    await _loadLocations();
    _setupReceivePort();
    await _initForegroundTask();
  }


  Future<void> _loadLocations() async {
    final locations = await _db.getAllLocations();
    setState(() {
      _locations = locations;
    });
  }


  Future<void> _checkAndRequestPermissions() async {
    try {
      // Step 1: Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled.');
        await Geolocator.openLocationSettings();
        return;
      }

      // Step 2: Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission is denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission is permanently denied.');


        await Geolocator.openAppSettings();
        return;
      }

      // ✅ Permission granted
      debugPrint('✅ Location permission granted: $permission');

      // Remove this line - it shouldn't be here as it opens settings unnecessarily
      // await Geolocator.openAppSettings();

      // Now you can proceed with getting the location
      // await _getCurrentLocation();

    } catch (e) {
      debugPrint('⚠️ Error checking permissions: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Error accessing location: ${e.toString()}'),
      //   ),
      // );
    }
  }

  Future<void> _initForegroundTask() async {
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

  Future<void> _setupReceivePort() async{
    _receivePort = FlutterForegroundTask.receivePort;
    _portSubscription = _receivePort?.listen((data) async {
      if (data is Map<String, dynamic>) {
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          await _db.insertLocation(data);
          final locations = await _db.getAllLocations();
          setState(() {
            _locations = locations;
          });
          debugPrint("UI updated: ${data['latitude']}, ${data['longitude']}");
        } else if (data.containsKey('isPaused')) {
          setState(() {
            _isPaused = data['isPaused'] as bool;
          });
        }
      }
    });
  }

  Future<void> _startForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
        notificationTitle: 'Location Tracking',
        notificationText: 'Tracking location every 5 seconds...',
        callback: startCallback
    );

    setState(() {
      _isTracking = true;
      _isPaused = false;
    });

    FlutterForegroundTask.sendDataToTask({'isPaused': _isPaused});
  }

  Future<void> _pauseForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      setState(() {
        _isPaused = true;
      });
      FlutterForegroundTask.sendDataToTask({'isPaused': _isPaused});
      await FlutterForegroundTask.updateService(
          notificationTitle: 'Location Tracking Paused',
          notificationText: 'Location tracking is paused'
      );
    }
  }

  Future<void> _resumeForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      setState(() {
        _isPaused = false;
      });
      FlutterForegroundTask.sendDataToTask({'isPaused': _isPaused});
      await FlutterForegroundTask.updateService(
          notificationTitle: 'Location Tracking',
          notificationText: 'Tracking location every 5 seconds...'
      );
    }
  }

  Future<void> _stopForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      await _db.clearLocations();
      setState(() {
        _isTracking = false;
        _isPaused = false;
        // _locations = [];
      });
    }
  }

  @override
  void dispose() {
    _portSubscription?.cancel();
    _receivePort?.close();
    _stopForegroundTask();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker', style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22
        ),),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

// Status Indicator
            Text(
                _isTracking
                    ? (_isPaused ? 'Tracking Paused' : 'Tracking Active')
                    : 'Tracking Stopped',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isTracking
                        ? (_isPaused ? Colors.orange : Colors.green)
                        : Colors.red
                )
            ),
            const SizedBox(height: 20),

// Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isTracking ? null : _startForegroundTask,
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
                if (_isTracking)
                  ElevatedButton(
                    onPressed: _isPaused
                        ? _resumeForegroundTask
                        : _pauseForegroundTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPaused ? Colors.blue : Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _isPaused ? 'Resume' : 'Pause',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _stopForegroundTask,
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

// Location List
            Expanded(
                child: _locations.isEmpty
                    ? const Center(
                    child: Text(
                        'No location data available',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54
                        )
                    )
                )
                    : FutureBuilder(
                  future: _loadLocations(),
                  builder: (context, snapshot) {
                    if(snapshot.error == true){
                      return Text("Something Went Wrong");
                    } else {
                      final location = snapshot.data;
                      return ListView.builder(
                        itemCount: _locations.length,
                        itemBuilder: (context, index) {
                          final location = _locations[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(10),
                              title: Text(
                                  'Lat: ${location['latitude'].toStringAsFixed(
                                      6)}, Long: ${location['longitude'].toStringAsFixed(
                                      6)}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500
                                  )
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Accuracy: ${location['accuracy'].toStringAsFixed(
                                        1)} m',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54
                                    ),
                                  ),
                                  Text(
                                    'Timestamp: ${location['timestamp']
                                        .toString()
                                        .substring(0, 19)}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                )
            ),
          ],
        ),
      ),
    );
  }
}

// The callback function should always be a top-level or static function.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  bool _isPaused = false;
  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('onStart(starter: ${starter.name})');
  }

  // Called based on the eventAction set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) async{
    if (_isPaused) {
      debugPrint('Location tracking is paused');
      return;
    }

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

      await LocationDatabase.instance.insertLocation(locationData);
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
    print('onDestroy(isTimeout: $isTimeout)');
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    print('onReceiveData: $data');
    if (data is Map<String, dynamic> && data.containsKey('isPaused')) {
      _isPaused = data['isPaused'] as bool;
      debugPrint('Received data: isPaused=$_isPaused');
    }
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed: $id');
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    print('onNotificationPressed');
    FlutterForegroundTask.launchApp();
  }

  // Called when the notification itself is dismissed.
  @override
  void onNotificationDismissed() {
    print('onNotificationDismissed');
  }
}
