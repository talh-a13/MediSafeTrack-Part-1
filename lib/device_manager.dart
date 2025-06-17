import 'dart:async';
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:temperaturemonitor/retry_logic.dart';
// Import your cloud service
// import 'cloud_service.dart';

class DeviceData {
  final BluetoothDevice device;
  double temperature = 0.0;
  double humidity = 0.0;
  bool isConnected = false;
  bool isReady = false;
  bool isConnecting = false;
  String? errorMessage;
  StreamSubscription<List<int>>? subscription;
  StreamSubscription<BluetoothDeviceState>? deviceStateSubscription;
  DateTime? lastDataReceived;
  int reconnectAttempts = 0;
  static const int maxReconnectAttempts = 3;

  DeviceData(this.device);

  bool get isStale =>
      lastDataReceived != null &&
      DateTime.now().difference(lastDataReceived!).inMinutes > 5;
}

class DeviceManager extends ChangeNotifier {
  final Map<String, DeviceData> _devices = {};
  final String service_uuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristic_uuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Cloud service integration
  late CloudSyncService _cloudService;
  Timer? _healthCheckTimer;

  Map<String, DeviceData> get devices => _devices;
  CloudSyncService get cloudService => _cloudService;

  List<DeviceData> get connectedDevices => _devices.values
      .where((data) => data.isConnected && data.isReady)
      .toList();

  List<DeviceData> get connectingDevices =>
      _devices.values.where((data) => data.isConnecting).toList();

  DeviceManager({
    required String cloudEndpoint,
    Map<String, String>? cloudHeaders,
  }) {
    _cloudService = CloudSyncService(
      cloudEndpoint: cloudEndpoint,
      headers: cloudHeaders,
    );
    _startHealthCheck();
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _performHealthCheck();
    });
  }

  void _performHealthCheck() {
    for (var deviceData in _devices.values) {
      if (deviceData.isConnected && deviceData.isStale) {
        print(
            'Device ${deviceData.device.name} appears stale, attempting reconnection');
        _handleDeviceDisconnection(deviceData);
      }
    }
  }

  Future<bool> addOrUpdateDevice(BluetoothDevice device) async {
    if (!_devices.containsKey(device.id.id)) {
      _devices[device.id.id] = DeviceData(device);
    }

    return await _setupDevice(_devices[device.id.id]!);
  }

  Future<bool> _setupDevice(DeviceData deviceData) async {
    try {
      deviceData.isConnecting = true;
      deviceData.errorMessage = null;
      notifyListeners();

      // Check if already connected
      if (deviceData.isConnected && deviceData.isReady) {
        deviceData.isConnecting = false;
        notifyListeners();
        return true;
      }

      // Cancel existing subscriptions
      await deviceData.subscription?.cancel();
      await deviceData.deviceStateSubscription?.cancel();

      // Connect to the device with timeout
      await deviceData.device.connect().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timeout', Duration(seconds: 15));
        },
      );

      deviceData.isConnected = true;
      deviceData.reconnectAttempts = 0;
      notifyListeners();

      // Listen for device state changes
      deviceData.deviceStateSubscription = deviceData.device.state.listen(
        (BluetoothDeviceState state) {
          if (state == BluetoothDeviceState.disconnected) {
            print('Device ${deviceData.device.name} disconnected');
            _handleDeviceDisconnection(deviceData);
          }
        },
        onError: (error) {
          print('Device state error for ${deviceData.device.name}: $error');
        },
      );

      // Discover services with retry logic
      List<BluetoothService> services =
          await _discoverServicesWithRetry(deviceData.device);

      bool serviceFound = false;
      for (var service in services) {
        if (service.uuid.toString() == service_uuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == characteristic_uuid) {
              await characteristic.setNotifyValue(true);

              // Subscribe to data updates
              deviceData.subscription = characteristic.value.listen(
                (data) {
                  _processData(deviceData, data);
                },
                onError: (error) {
                  print(
                      'Data stream error for ${deviceData.device.name}: $error');
                  deviceData.errorMessage = 'Data stream error: $error';
                  notifyListeners();
                  _scheduleReconnection(deviceData);
                },
                onDone: () {
                  print('Data stream closed for ${deviceData.device.name}');
                  _handleDeviceDisconnection(deviceData);
                },
              );

              deviceData.isReady = true;
              serviceFound = true;
              break;
            }
          }
          if (serviceFound) break;
        }
      }

      if (!serviceFound) {
        throw Exception('Required service or characteristic not found');
      }

      deviceData.isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error setting up device ${deviceData.device.name}: $e');
      deviceData.isConnecting = false;
      deviceData.isConnected = false;
      deviceData.isReady = false;
      deviceData.errorMessage = e.toString();
      deviceData.reconnectAttempts++;
      notifyListeners();

      if (deviceData.reconnectAttempts < DeviceData.maxReconnectAttempts) {
        _scheduleReconnection(deviceData);
      }

      return false;
    }
  }

  Future<List<BluetoothService>> _discoverServicesWithRetry(
      BluetoothDevice device,
      {int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await device.discoverServices().timeout(
          Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException(
                'Service discovery timeout', Duration(seconds: 15));
          },
        );
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        print('Service discovery attempt ${attempt + 1} failed: $e');
        await Future.delayed(Duration(seconds: 2));
      }
    }
    throw Exception('Failed to discover services after $maxRetries attempts');
  }

  void _handleDeviceDisconnection(DeviceData deviceData) {
    deviceData.isConnected = false;
    deviceData.isReady = false;
    deviceData.subscription?.cancel();
    deviceData.deviceStateSubscription?.cancel();
    notifyListeners();

    if (deviceData.reconnectAttempts < DeviceData.maxReconnectAttempts) {
      _scheduleReconnection(deviceData);
    }
  }

  void _scheduleReconnection(DeviceData deviceData) {
    int delaySeconds = (2 << deviceData.reconnectAttempts).clamp(2, 30);

    print(
        'Scheduling reconnection for ${deviceData.device.name} in ${delaySeconds}s (attempt ${deviceData.reconnectAttempts + 1})');

    Timer(Duration(seconds: delaySeconds), () {
      if (_devices.containsKey(deviceData.device.id.id) &&
          !deviceData.isConnected &&
          !deviceData.isConnecting) {
        print(
            'Attempting automatic reconnection for ${deviceData.device.name}');
        _setupDevice(deviceData);
      }
    });
  }

  void _processData(DeviceData deviceData, List<int> data) {
    try {
      String currentValue = utf8.decode(data);
      List<String> tempHumiData = currentValue.split(",");

      if (tempHumiData.isNotEmpty && tempHumiData.length >= 2) {
        String tempRaw = tempHumiData[0].replaceAll(RegExp(r'[^0-9.]'), '');
        String humidityRaw = tempHumiData[1].replaceAll(RegExp(r'[^0-9.]'), '');

        double newTemp = double.tryParse(tempRaw) ?? 0.0;
        double newHumidity = double.tryParse(humidityRaw) ?? 0.0;

        // Validate data ranges
        if (newTemp >= -40 &&
            newTemp <= 80 &&
            newHumidity >= 0 &&
            newHumidity <= 100) {
          deviceData.temperature = newTemp;
          deviceData.humidity = newHumidity;
          deviceData.lastDataReceived = DateTime.now();
          deviceData.errorMessage = null;

          // Send data to cloud service
          _sendDataToCloud(deviceData);

          notifyListeners();
        } else {
          print(
              'Invalid sensor data received: temp=$newTemp, humidity=$newHumidity');
        }
      }
    } catch (e) {
      print('Error processing data from ${deviceData.device.name}: $e');
      deviceData.errorMessage = 'Data processing error: $e';
      notifyListeners();
    }
  }

  Future<void> _sendDataToCloud(DeviceData deviceData) async {
    try {
      String deviceName = deviceData.device.name.isEmpty
          ? "Unknown Device"
          : deviceData.device.name;

      SensorData sensorData = SensorData(
        deviceName: deviceName,
        deviceId: deviceData.device.id.id,
        temperature: deviceData.temperature,
        humidity: deviceData.humidity,
        timestamp: DateTime.now(),
      );

      await _cloudService.addSensorData(sensorData);

      print(
          'Queued data for cloud sync: $deviceName - T:${deviceData.temperature}°C H:${deviceData.humidity}%');
    } catch (e) {
      print('Error queuing data for cloud sync: $e');
    }
  }

  Future<void> retryConnection(String deviceId) async {
    if (_devices.containsKey(deviceId)) {
      var deviceData = _devices[deviceId]!;
      deviceData.reconnectAttempts = 0;
      await _setupDevice(deviceData);
    }
  }

  void removeDevice(String deviceId) {
    if (_devices.containsKey(deviceId)) {
      var deviceData = _devices[deviceId]!;

      deviceData.subscription?.cancel();
      deviceData.deviceStateSubscription?.cancel();

      if (deviceData.isConnected) {
        deviceData.device.disconnect().catchError((e) {
          print('Error disconnecting device: $e');
        });
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

  DeviceData? getDevice(String deviceId) {
    return _devices[deviceId];
  }

  // Cloud service methods
  Map<String, dynamic> getCloudStatus() {
    return _cloudService.getStatus();
  }

  void clearCloudQueue() {
    _cloudService.clearQueue();
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _cloudService.dispose();
    disconnectAll();
    super.dispose();
  }
}
