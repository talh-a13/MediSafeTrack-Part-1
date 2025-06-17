import 'dart:async';
import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'homepage.dart';

class SensorPage extends StatefulWidget {
  const SensorPage({required Key key, required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  _SensorPageState createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  String service_uuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  String characteristic_uuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  bool isReady = false;
  bool isConnecting = true;
  bool hasError = false;
  String? errorMessage;

  late Stream<List<int>> stream;
  double _temp = 0;
  double _humidity = 0;

  Timer? _connectionTimer;
  StreamSubscription<BluetoothDeviceState>? _deviceStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _deviceStateSubscription?.cancel();
    _disconnectFromDevice();
    super.dispose();
  }

  void _initializeConnection() {
    _deviceStateSubscription = widget.device.state.listen((state) {
      if (state == BluetoothDeviceState.disconnected && mounted) {
        setState(() {
          isReady = false;
          isConnecting = false;
          hasError = true;
          errorMessage = 'Device disconnected unexpectedly';
        });
      }
    });

    _connectToDevice();
  }

  void _connectToDevice() async {
    setState(() {
      isConnecting = true;
      hasError = false;
      errorMessage = null;
    });

    _connectionTimer = Timer(const Duration(seconds: 15), () {
      if (!isReady && mounted) {
        setState(() {
          isConnecting = false;
          hasError = true;
          errorMessage = 'Connection timeout';
        });
      }
    });

    try {
      var deviceState = await widget.device.state.first;
      if (deviceState != BluetoothDeviceState.connected) {
        await widget.device.connect();
      }

      await _discoverServices();
    } catch (e) {
      print('Connection error: $e');
      if (mounted) {
        setState(() {
          isConnecting = false;
          hasError = true;
          errorMessage = 'Connection failed: ${e.toString()}';
        });
      }
    }
  }

  void _disconnectFromDevice() {
    try {
      widget.device.disconnect();
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  Future<void> _discoverServices() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();

      bool serviceFound = false;
      for (var service in services) {
        if (service.uuid.toString() == service_uuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == characteristic_uuid) {
              await characteristic.setNotifyValue(true);
              stream = characteristic.value;

              stream.listen(
                (data) {
                  if (mounted) {
                    _processData(data);
                  }
                },
                onError: (error) {
                  print('Data stream error: $error');
                  if (mounted) {
                    setState(() {
                      hasError = true;
                      errorMessage = 'Data stream error: $error';
                    });
                  }
                },
              );

              serviceFound = true;
              break;
            }
          }
          if (serviceFound) break;
        }
      }

      if (serviceFound) {
        _connectionTimer?.cancel();
        if (mounted) {
          setState(() {
            isReady = true;
            isConnecting = false;
            hasError = false;
            errorMessage = null;
          });
        }
      } else {
        throw Exception('Required service or characteristic not found');
      }
    } catch (e) {
      print('Service discovery error: $e');
      if (mounted) {
        setState(() {
          isConnecting = false;
          hasError = true;
          errorMessage = 'Service discovery failed: ${e.toString()}';
        });
      }
    }
  }

  void _processData(List<int> data) {
    try {
      String currentValue = utf8.decode(data);
      List<String> tempHumiData = currentValue.split(",");

      if (tempHumiData.length >= 2) {
        String tempRaw = tempHumiData[0].replaceAll(RegExp(r'[^0-9.]'), '');
        String humidityRaw = tempHumiData[1].replaceAll(RegExp(r'[^0-9.]'), '');

        double newTemp = double.tryParse(tempRaw) ?? 0.0;
        double newHumidity = double.tryParse(humidityRaw) ?? 0.0;

        if (mounted) {
          setState(() {
            _temp = newTemp;
            _humidity = newHumidity;
          });
        }
      }
    } catch (e) {
      print('Data processing error: $e');
    }
  }

  Future<bool> _onWillPop() async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to disconnect device and go back?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              _disconnectFromDevice();
              Navigator.of(context).pop(true);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _retryConnection() {
    _connectToDevice();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Data from ${widget.device.name}'),
          actions: [
            if (hasError)
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _retryConnection,
                tooltip: 'Retry connection',
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Connecting...",
              style: TextStyle(fontSize: 24, color: Colors.blue),
            ),
          ],
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 20),
            Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                errorMessage ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _retryConnection,
              child: Text('Retry Connection'),
            ),
          ],
        ),
      );
    }

    if (!isReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Waiting for data...",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }

    return HomeUI(
      key: Key('home_ui'),
      humidity: _humidity,
      temperature: _temp,
    );
  }
}
