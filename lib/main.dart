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
  DeviceManager deviceManager = DeviceManager(
    cloudEndpoint: "http://64.227.152.123:8000/data",
  );

  @override
  void initState() {
    super.initState();
    FlutterBlue.instance.startScan(timeout: Duration(seconds: 4));
    deviceManager.addListener(_onDeviceManagerUpdate);
  }

  @override
  void dispose() {
    deviceManager.removeListener(_onDeviceManagerUpdate);
    super.dispose();
  }

  void _onDeviceManagerUpdate() {
    setState(() {});
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                "Connecting to ${device.name}",
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        );
      },
    );

    try {
      bool success = await deviceManager.addOrUpdateDevice(device);
      Navigator.of(context).pop();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${device.name} connected successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        DeviceData? deviceData = deviceManager.getDevice(device.id.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to connect: ${deviceData?.errorMessage ?? "Unknown error"}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _connectToDevice(device),
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _navigateToSensorPage(BluetoothDevice device) {
    DeviceData? deviceData = deviceManager.getDevice(device.id.id);
    if (deviceData != null && deviceData.isReady) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SensorPage(
            device: device,
            key: Key('sensor_page_${device.id}'),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device is not ready yet. Please wait...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToDashboard() {
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
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.dashboard),
                onPressed: _navigateToDashboard,
              ),
              if (deviceManager.connectedDevices.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${deviceManager.connectedDevices.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 10)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              AnimatedBuilder(
                animation: deviceManager,
                builder: (context, child) {
                  List<DeviceData> connectedDevices =
                      deviceManager.connectedDevices;
                  List<DeviceData> connectingDevices =
                      deviceManager.connectingDevices;

                  List<Widget> tiles = [];

                  if (connectingDevices.isNotEmpty) {
                    tiles.add(
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Connecting Devices',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    );

                    tiles.addAll(
                      connectingDevices.map((deviceData) => ListTile(
                            title: Text(deviceData.device.name.isEmpty
                                ? "Unknown Device"
                                : deviceData.device.name),
                            subtitle: Text('Connecting...'),
                            leading: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.cancel),
                              onPressed: () => deviceManager
                                  .removeDevice(deviceData.device.id.id),
                            ),
                          )),
                    );
                  }

                  if (connectedDevices.isNotEmpty) {
                    tiles.add(
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Connected Devices',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );

                    tiles.addAll(
                      connectedDevices.map((deviceData) => ListTile(
                            title: Text(deviceData.device.name.isEmpty
                                ? "Unknown Device"
                                : deviceData.device.name),
                            subtitle: Text(
                                'Temperature: ${deviceData.temperature.toStringAsFixed(1)}°C, '
                                'Humidity: ${deviceData.humidity.toStringAsFixed(1)}%'),
                            leading:
                                Icon(Icons.check_circle, color: Colors.green),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.info),
                                  onPressed: () =>
                                      _navigateToSensorPage(deviceData.device),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.red),
                                  onPressed: () => deviceManager
                                      .removeDevice(deviceData.device.id.id),
                                ),
                              ],
                            ),
                          )),
                    );
                  }

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

                  var availableDevices = snapshot.data!
                      .where((r) => r.device.name.isNotEmpty)
                      .where((r) =>
                          !deviceManager.devices.containsKey(r.device.id.id))
                      .toList();

                  if (availableDevices.isNotEmpty) {
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
                    availableDevices.map(
                      (r) => Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.device.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                r.device.id.toString(),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 8),
                              Text('RSSI: ${r.rssi}'),
                              SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  child: Text('CONNECT'),
                                  onPressed: r.advertisementData.connectable
                                      ? () => _connectToDevice(r.device)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
