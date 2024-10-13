import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';

// Define a Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_beacon
  await flutterBeacon.initializeScanning;

  // Run the app
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<RangingResult> _streamRanging;
  List<Beacon> _beacons = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Start the permission request and scanning process after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    _startScanning();
  }

  Future<void> _requestPermissions() async {
    // Request location permissions
    var locationStatus = await Permission.locationAlways.status;
    if (!locationStatus.isGranted) {
      print('Requesting Location Always permission...');
      locationStatus = await Permission.locationAlways.request();
      if (!locationStatus.isGranted) {
        print('Location permission not granted.');
        await _showPermissionDeniedDialog('Location');
        return;
      }
      print('Location permission granted.');
    } else {
      print('Location permission already granted.');
    }

    // For Android 12 and above, request additional Bluetooth permissions
    if (Platform.isAndroid) {
      // Bluetooth Scan
      if (await Permission.bluetoothScan.status.isDenied) {
        print('Requesting Bluetooth Scan permission...');
        var bluetoothScanStatus = await Permission.bluetoothScan.request();
        if (!bluetoothScanStatus.isGranted) {
          print('Bluetooth Scan permission not granted.');
          await _showPermissionDeniedDialog('Bluetooth Scan');
          return;
        }
        print('Bluetooth Scan permission granted.');
      } else {
        print('Bluetooth Scan permission already granted.');
      }

      // Bluetooth Connect
      if (await Permission.bluetoothConnect.status.isDenied) {
        print('Requesting Bluetooth Connect permission...');
        var bluetoothConnectStatus =
            await Permission.bluetoothConnect.request();
        if (!bluetoothConnectStatus.isGranted) {
          print('Bluetooth Connect permission not granted.');
          await _showPermissionDeniedDialog('Bluetooth Connect');
          return;
        }
        print('Bluetooth Connect permission granted.');
      } else {
        print('Bluetooth Connect permission already granted.');
      }

      // Bluetooth Advertise
      if (await Permission.bluetoothAdvertise.status.isDenied) {
        print('Requesting Bluetooth Advertise permission...');
        var bluetoothAdvertiseStatus =
            await Permission.bluetoothAdvertise.request();
        if (!bluetoothAdvertiseStatus.isGranted) {
          print('Bluetooth Advertise permission not granted.');
          await _showPermissionDeniedDialog('Bluetooth Advertise');
          return;
        }
        print('Bluetooth Advertise permission granted.');
      } else {
        print('Bluetooth Advertise permission already granted.');
      }
    }
  }

  Future<void> _showPermissionDeniedDialog(String permissionName) async {
    // Ensure the context is available
    if (navigatorKey.currentContext == null) {
      print(
          '$permissionName permission not granted, but no context available.');
      return;
    }

    await showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission'),
        content: Text(
            'This app requires $permissionName permission to function correctly. Please grant the permission in settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _startScanning() async {
    print('Starting Bluetooth scanning...');
    // Check if Bluetooth is enabled
    final bluetoothState = await flutterBeacon.bluetoothState;
    print('Bluetooth State: $bluetoothState');

    if (bluetoothState == BluetoothState.stateOff) {
      print('Bluetooth is turned off.');
      _showBluetoothOffDialog();
      return;
    }

    // Define regions to scan for
    final regions = <Region>[
      Region(
        identifier: 'com.example.beacon',
        // Optionally specify UUID, major, and minor
        // proximityUUID: 'YOUR_PROXIMITY_UUID',
      ),
    ];

    try {
      // Start ranging
      _streamRanging =
          flutterBeacon.ranging(regions).listen((RangingResult result) {
        print('Ranging Result: ${result.beacons.length} beacons found.');
        setState(() {
          _beacons = result.beacons..sort((a, b) => b.rssi.compareTo(a.rssi));
        });
      }, onError: (e) {
        print('Error during ranging: $e');
        // Optionally, show an error dialog to the user
      });

      setState(() {
        _isScanning = true;
      });
      print('Bluetooth scanning started.');
    } catch (e) {
      print('Exception while starting scanning: $e');
      // Handle exceptions, possibly showing a dialog to the user
    }
  }

  void _stopScanning() {
    print('Stopping Bluetooth scanning...');
    _streamRanging.cancel();
    setState(() {
      _isScanning = false;
      _beacons.clear();
    });
    print('Bluetooth scanning stopped.');
  }

  void _showBluetoothOffDialog() {
    // Ensure the context is available
    if (navigatorKey.currentContext == null) {
      print('Bluetooth is off, but no context available to show dialog.');
      return;
    }

    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: Text('Bluetooth is Off'),
        content: Text('Please turn on Bluetooth to detect beacons.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isScanning) {
      _streamRanging.cancel();
      print('Stream subscription canceled.');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Assign the navigatorKey
      title: 'Bluetooth Beacon Detector',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Bluetooth Beacon Detector'),
          actions: [
            IconButton(
              icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
              onPressed: () {
                if (_isScanning) {
                  _stopScanning();
                } else {
                  _startScanning();
                }
              },
            ),
          ],
        ),
        body: _beacons.isEmpty
            ? Center(child: Text('No beacons found'))
            : ListView.builder(
                itemCount: _beacons.length,
                itemBuilder: (context, index) {
                  final beacon = _beacons[index];
                  return ListTile(
                    leading: Icon(Icons.bluetooth),
                    title: Text(beacon.proximityUUID),
                    subtitle: Text(
                        'Major: ${beacon.major}, Minor: ${beacon.minor}\nRSSI: ${beacon.rssi}'),
                    trailing: Text(_proximityText(beacon.proximity)),
                  );
                },
              ),
      ),
    );
  }

  String _proximityText(Proximity proximity) {
    switch (proximity) {
      case Proximity.immediate:
        return 'Immediate';
      case Proximity.near:
        return 'Near';
      case Proximity.far:
        return 'Far';
      default:
        return 'Unknown';
    }
  }
}
