import 'dart:async';
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class DeviceData {
  final BluetoothDevice device;
  double temperature = 0.0;
  double humidity = 0.0;
  bool isConnected = false;
  bool isReady = false;
  StreamSubscription<List<int>>? subscription;

  DeviceData(this.device);
}

class DeviceManager extends ChangeNotifier {
  
  final Map<String, DeviceData> _devices = {};
  final String service_uuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristic_uuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  Map<String, DeviceData> get devices => _devices;

  List<DeviceData> get connectedDevices =>
      _devices.values.where((data) => data.isConnected).toList();

  void addOrUpdateDevice(BluetoothDevice device) {
    if (!_devices.containsKey(device.id.id)) {
      _devices[device.id.id] = DeviceData(device);
      _setupDevice(_devices[device.id.id]!);
    }
    notifyListeners();
  }

  void _setupDevice(DeviceData deviceData) async {
    try {
      // Connect to the device
      await deviceData.device.connect();
      deviceData.isConnected = true;
      notifyListeners();

      // Discover services
      List<BluetoothService> services =
          await deviceData.device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString() == service_uuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == characteristic_uuid) {
              await characteristic.setNotifyValue(true);

              // Subscribe to data updates
              deviceData.subscription = characteristic.value.listen((data) {
                _processData(deviceData, data);
              });

              deviceData.isReady = true;
              notifyListeners();
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Error setting up device ${deviceData.device.name}: $e');
      removeDevice(deviceData.device.id.id);
    }
  }

  void _processData(DeviceData deviceData, List<int> data) {
    try {
      String currentValue = utf8.decode(data);
      List<String> tempHumiData = currentValue.split(",");

      if (tempHumiData.isNotEmpty && tempHumiData.length >= 2) {
        String tempRaw = tempHumiData[0].replaceAll(RegExp(r'[^0-9.]'), '');
        String humidityRaw = tempHumiData[1].replaceAll(RegExp(r'[^0-9.]'), '');

        deviceData.temperature = double.tryParse(tempRaw) ?? 0.0;
        deviceData.humidity = double.tryParse(humidityRaw) ?? 0.0;
        notifyListeners();
      }
    } catch (e) {
      print('Error processing data from ${deviceData.device.name}: $e');
    }
  }

  void removeDevice(String deviceId) {
    if (_devices.containsKey(deviceId)) {
      // Cancel the subscription
      _devices[deviceId]?.subscription?.cancel();

      // Disconnect the device
      if (_devices[deviceId]?.isConnected == true) {
        _devices[deviceId]?.device.disconnect();
      }

      _devices.remove(deviceId);
      notifyListeners();
    }
  }

  void disconnectAll() {
    for (var deviceId in List.from(_devices.keys)) {
      removeDevice(deviceId);
    }
  }

  @override
  void dispose() {
    disconnectAll();
    super.dispose();
  }
}
