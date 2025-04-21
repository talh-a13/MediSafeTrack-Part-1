import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:temperaturemonitor/device_manager.dart';
import 'package:temperaturemonitor/sensor.dart';

import 'multi_device_daskhboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(FlutterBlueApp());
}

Future<void> _requestPermissions() async {
  List<Permission> permissions = [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.locationWhenInUse,
  ];

  Map<Permission, PermissionStatus> statuses = await permissions.request();

  bool allGranted = true;
  for (var entry in statuses.entries) {
    print('Permission: ${entry.key}, Status: ${entry.value}');

    if (entry.value.isDenied) {
      print('Permission denied: ${entry.key}');
      allGranted = false;
    } else if (entry.value.isPermanentlyDenied) {
      print('Permission permanently denied: ${entry.key}');
      allGranted = false;
      // Open app settings for manually granting permissions
      await openAppSettings();
    }
  }

  if (!allGranted) {
    print('Not all permissions granted. Some features may not work properly.');
  }
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
        stream: FlutterBlue.instance.state,
        initialData: BluetoothState.unknown,
        builder: (c, snapshot) {
          final state = snapshot.data;
          if (state == BluetoothState.on) {
            return FindDevicesScreen();
          }
          return BluetoothOffScreen(state: state, key: Key('bluetooth_off'));
        },
      ),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({required Key key, this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state.toString().substring(15)}.',
              style: Theme.of(context)
                      .primaryTextTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white) ??
                  TextStyle(),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatefulWidget {
  @override
  _FindDevicesScreenState createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  DeviceManager deviceManager = DeviceManager();

  @override
  void initState() {
    super.initState();
    // Start scanning when the screen is loaded
    FlutterBlue.instance.startScan(timeout: Duration(seconds: 4));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
        actions: [
          IconButton(
            icon: Icon(Icons.dashboard),
            onPressed: () {
              if (deviceManager.connectedDevices.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MultiDeviceDashboard(
                      deviceManager: deviceManager,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Connect to at least one device first'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 10)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 2))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }

                  List<Widget> tiles = [];

                  if (snapshot.data!.isNotEmpty) {
                    tiles.add(
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Connected Devices',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }

                  tiles.addAll(
                    snapshot.data!.map(
                      (d) => ListTile(
                        title: Text(d.name.isEmpty ? "Unknown Device" : d.name),
                        subtitle: Text(d.id.toString()),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  );
                                }
                                return Text(
                                    snapshot.data.toString().split('.')[1]);
                              },
                            ),
                            SizedBox(width: 10),
                            IconButton(
                              icon: Icon(Icons.info),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return SensorPage(
                                        device: d,
                                        key: Key('sensor_page_${d.id}'),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          deviceManager.addOrUpdateDevice(d);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${d.name} is being monitored'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  );

                  return Column(children: tiles);
                },
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }

                  List<Widget> tiles = [];

                  if (snapshot.data!.isNotEmpty) {
                    tiles.add(
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Available Devices',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }

                  tiles.addAll(
                    snapshot.data!
                        .where((r) => r.device.name.isNotEmpty)
                        .map(
                          (r) => ListTile(
                            title: Text(r.device.name),
                            subtitle: Text(r.device.id.toString()),
                            trailing: ElevatedButton(
                              child: Text('CONNECT'),
                              onPressed: r.advertisementData.connectable
                                  ? () async {
                                      try {
                                        await r.device.connect();
                                        deviceManager
                                            .addOrUpdateDevice(r.device);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Connected to ${r.device.name}'),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Error connecting: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  );

                  return Column(children: tiles);
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
              child: Icon(Icons.search),
              onPressed: () =>
                  FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
            );
          }
        },
      ),
    );
  }
}
