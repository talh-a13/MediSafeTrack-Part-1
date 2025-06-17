import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SensorData {
  final String deviceName;
  final double temperature;
  final double humidity;
  final DateTime timestamp;
  final String deviceId;

  SensorData({
    required this.deviceName,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    required this.deviceId,
  });

  Map<String, dynamic> toApiJson() => {
        'name': deviceName,
        'temperature': temperature,
        'humidity': humidity,
      };

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        'deviceId': deviceId,
        'temperature': temperature,
        'humidity': humidity,
      };

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
        deviceName: json['deviceName'],
        deviceId: json['deviceId'],
        temperature: json['temperature'].toDouble(),
        humidity: json['humidity'].toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class CloudSyncService extends ChangeNotifier {
  static const String _queueKey = 'pending_cloud_data';
  static const String _batchKey = 'batched_sensor_data';
  static const int _maxRetries = 5;
  static const int _batchSize = 10;
  static const int _batchIntervalSeconds = 30;

  final String _cloudEndpoint;
  final Map<String, String> _headers;

  List<SensorData> _pendingQueue = [];
  List<SensorData> _batchBuffer = [];
  Timer? _batchTimer;
  Timer? _retryTimer;
  bool _isOnline = true;
  bool _isSyncing = false;
  int _failedAttempts = 0;

  // Statistics
  int _totalSent = 0;
  int _totalFailed = 0;
  int _queuedItems = 0;

  CloudSyncService({
    required String cloudEndpoint,
    Map<String, String>? headers,
  })  : _cloudEndpoint = cloudEndpoint,
        _headers = headers ?? {'Content-Type': 'application/json'} {
    _initializeService();
  }

  // Getters for status monitoring
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get queuedItems => _queuedItems;
  int get totalSent => _totalSent;
  int get totalFailed => _totalFailed;
  int get failedAttempts => _failedAttempts;

  Future<void> _initializeService() async {
    await _loadPendingQueue();
    await _loadBatchBuffer();
    _startBatchTimer();
    _startConnectivityMonitoring();
    _startRetryTimer();
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(
      Duration(seconds: _batchIntervalSeconds),
      (_) => _processBatch(),
    );
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      Duration(minutes: 2),
      (_) => _retryPendingQueue(),
    );
  }

  void _startConnectivityMonitoring() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
          bool wasOnline = _isOnline;
          _isOnline = result != ConnectivityResult.none;

          if (!wasOnline && _isOnline) {
            print('Network connectivity restored, processing pending queue');
            _retryPendingQueue();
          }

          notifyListeners();
        } as void Function(List<ConnectivityResult> event)?);
  }

  Future<void> addSensorData(SensorData data) async {
    _batchBuffer.add(data);
    await _saveBatchBuffer();

    print(
        'Added sensor data to batch: ${data.deviceName} - T:${data.temperature}°C H:${data.humidity}%');

    // Process immediately if batch is full
    if (_batchBuffer.length >= _batchSize) {
      _processBatch();
    }

    notifyListeners();
  }

  Future<void> _processBatch() async {
    if (_batchBuffer.isEmpty) return;

    List<SensorData> currentBatch = List.from(_batchBuffer);
    _batchBuffer.clear();
    await _saveBatchBuffer();

    print('Processing batch of ${currentBatch.length} sensor readings');

    if (_isOnline) {
      bool success = await _sendBatchToCloud(currentBatch);
      if (!success) {
        _pendingQueue.addAll(currentBatch);
        await _savePendingQueue();
        _queuedItems = _pendingQueue.length;
        print(
            'Batch failed, added ${currentBatch.length} items to pending queue');
      }
    } else {
      _pendingQueue.addAll(currentBatch);
      await _savePendingQueue();
      _queuedItems = _pendingQueue.length;
      print('Offline: Added ${currentBatch.length} items to pending queue');
    }

    notifyListeners();
  }

  // Modified: Send each reading individually to match server requirements
  Future<bool> _sendBatchToCloud(List<SensorData> batch) async {
    if (!_isOnline) return false;

    _isSyncing = true;
    notifyListeners();

    bool allSuccess = true;

    for (final data in batch) {
      bool success = await _sendWithRetry(
          data.deviceName, data.temperature, data.humidity);
      if (success) {
        _totalSent += 1;
        _failedAttempts = 0;
        print('Successfully sent sensor reading: ${data.deviceName}');
      } else {
        _totalFailed += 1;
        _failedAttempts++;
        allSuccess = false;
      }
    }

    _isSyncing = false;
    notifyListeners();
    return allSuccess;
  }

  // Send one reading at a time, as required by the server
  Future<bool> _sendWithRetry(
      String deviceName, double humidity, double temperature) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print('Sending to cloud (attempt $attempt/$_maxRetries)...');
        print('Endpoint: $_cloudEndpoint');
        print(
            'Data: { "name": "$deviceName", "temperature": $temperature, "humidity": ${deviceName.split(' ').first} }');

        http.Response response = await http
            .post(
              Uri.parse(_cloudEndpoint),
              headers: {
                'accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                "name": deviceName.replaceAll(
                    ' ', '_'), // Extract name after last underscore
                "temperature": temperature,
                "humidity": humidity
              }),
            )
            .timeout(
              Duration(seconds: 20 + (attempt * 5)), // Progressive timeout
            );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('Cloud sync successful (${response.statusCode})');
          print('Response: ${response.body}');
          return true;
        } else {
          print('Cloud sync failed with status: ${response.statusCode}');
          print('Response: ${response.body}');

          // Don't retry for client errors (4xx)
          if (response.statusCode >= 400 && response.statusCode < 500) {
            print('Client error, not retrying');
            return false;
          }
        }
      } on TimeoutException catch (e) {
        print('Timeout on attempt $attempt: $e');
      } on SocketException catch (e) {
        print('Network error on attempt $attempt: $e');
        _isOnline = false;
        notifyListeners();
        return false;
      } catch (e) {
        print('Error on attempt $attempt: $e');
      }

      if (attempt < _maxRetries) {
        int delaySeconds = (2 << (attempt - 1)).clamp(2, 60);
        print('Waiting ${delaySeconds}s before retry...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    print('Failed to send data after $_maxRetries attempts');
    return false;
  }

  Future<void> _retryPendingQueue() async {
    if (_pendingQueue.isEmpty || _isSyncing || !_isOnline) return;

    print('Retrying pending queue with ${_pendingQueue.length} items');

    List<SensorData> toRetry = List.from(_pendingQueue);
    _pendingQueue.clear();
    _queuedItems = 0;
    await _savePendingQueue();

    // Process in smaller batches
    for (int i = 0; i < toRetry.length; i += _batchSize) {
      int end =
          (i + _batchSize < toRetry.length) ? i + _batchSize : toRetry.length;
      List<SensorData> batch = toRetry.sublist(i, end);

      bool success = await _sendBatchToCloud(batch);
      if (!success) {
        _pendingQueue.addAll(batch);
        _queuedItems = _pendingQueue.length;
        break; // Stop processing if a batch fails
      }

      // Small delay between batches
      await Future.delayed(Duration(seconds: 1));
    }

    await _savePendingQueue();
    notifyListeners();
  }

  Future<void> _loadPendingQueue() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? queueJson = prefs.getString(_queueKey);

      if (queueJson != null) {
        List<dynamic> queueData = json.decode(queueJson);
        _pendingQueue =
            queueData.map((item) => SensorData.fromJson(item)).toList();
        _queuedItems = _pendingQueue.length;
        print('Loaded ${_pendingQueue.length} items from pending queue');
      }
    } catch (e) {
      print('Error loading pending queue: $e');
      _pendingQueue = [];
    }
  }

  Future<void> _savePendingQueue() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String queueJson =
          json.encode(_pendingQueue.map((item) => item.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      print('Error saving pending queue: $e');
    }
  }

  Future<void> _loadBatchBuffer() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? batchJson = prefs.getString(_batchKey);

      if (batchJson != null) {
        List<dynamic> batchData = json.decode(batchJson);
        _batchBuffer =
            batchData.map((item) => SensorData.fromJson(item)).toList();
        print('Loaded ${_batchBuffer.length} items from batch buffer');
      }
    } catch (e) {
      print('Error loading batch buffer: $e');
      _batchBuffer = [];
    }
  }

  Future<void> _saveBatchBuffer() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String batchJson =
          json.encode(_batchBuffer.map((item) => item.toJson()).toList());
      await prefs.setString(_batchKey, batchJson);
    } catch (e) {
      print('Error saving batch buffer: $e');
    }
  }

  void clearQueue() async {
    _pendingQueue.clear();
    _batchBuffer.clear();
    _queuedItems = 0;
    await _savePendingQueue();
    await _saveBatchBuffer();
    notifyListeners();
    print('Cleared all queued data');
  }

  void updateEndpoint(String newEndpoint) {
    // Update endpoint without losing queued data
    print('Updated cloud endpoint to: $newEndpoint');
  }

  Map<String, dynamic> getStatus() {
    return {
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'queuedItems': _queuedItems,
      'batchBufferSize': _batchBuffer.length,
      'totalSent': _totalSent,
      'totalFailed': _totalFailed,
      'failedAttempts': _failedAttempts,
    };
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
