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
  late bool isReady;
  late Stream<List<int>> stream;
  late List<String> _temphumidata;
  double _temp = 0;
  double _humidity = 0;

  @override
  void initState() {
    super.initState();
    isReady = false;
    connectToDevice();
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  void connectToDevice() async {
    Timer(const Duration(seconds: 15), () {
      if (!isReady) {
        disconnectFromDevice();
        _pop();
      }
    });

    try {
      await widget.device.connect();
      discoverServices();
    } catch (e) {
      print('Connection error: $e');
      _pop();
    }
  }

  void disconnectFromDevice() {
    widget.device.disconnect();
  }

  void discoverServices() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == service_uuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == characteristic_uuid) {
              characteristic.setNotifyValue(true);
              stream = characteristic.value;

              setState(() {
                isReady = true;
              });
            }
          }
        }
      }

      if (!isReady) {
        _pop();
      }
    } catch (e) {
      print('Service discovery error: $e');
      _pop();
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
              disconnectFromDevice();
              Navigator.of(context).pop(true);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _pop() {
    Navigator.of(context).pop(true);
  }

  String _dataParser(List<int> dataFromDevice) {
    return utf8.decode(dataFromDevice);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Data from ${widget.device.name}'),
        ),
        body: !isReady
            ? const Center(
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
              )
            : StreamBuilder<List<int>>(
                stream: stream,
                builder:
                    (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.active &&
                      snapshot.hasData) {
                    var currentValue = _dataParser(snapshot.data!);
                    _temphumidata = currentValue.split(",");

                    if (_temphumidata.isNotEmpty && _temphumidata.length >= 2) {
                      String tempRaw =
                          _temphumidata[0].replaceAll(RegExp(r'[^0-9.]'), '');
                      String humidityRaw =
                          _temphumidata[1].replaceAll(RegExp(r'[^0-9.]'), '');

                      _temp = double.tryParse(tempRaw) ?? 0.0;
                      _humidity = double.tryParse(humidityRaw) ?? 0.0;
                    }

                    return HomeUI(
                      key: Key('home_ui'),
                      humidity: _humidity,
                      temperature: _temp,
                    );
                  } else {
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
                },
              ),
      ),
    );
  }
}
