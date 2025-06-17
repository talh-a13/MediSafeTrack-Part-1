import 'package:flutter/material.dart';
import 'package:temperaturemonitor/device_manager.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

class MultiDeviceDashboard extends StatefulWidget {
  final DeviceManager deviceManager;

  const MultiDeviceDashboard({Key? key, required this.deviceManager})
      : super(key: key);

  @override
  _MultiDeviceDashboardState createState() => _MultiDeviceDashboardState();
}

class _MultiDeviceDashboardState extends State<MultiDeviceDashboard> {
  @override
  void initState() {
    super.initState();
    // Listen to both device manager and cloud service changes
    widget.deviceManager.addListener(_onDeviceManagerChanged);
    widget.deviceManager.cloudService.addListener(_onCloudServiceChanged);
  }

  @override
  void dispose() {
    widget.deviceManager.removeListener(_onDeviceManagerChanged);
    widget.deviceManager.cloudService.removeListener(_onCloudServiceChanged);
    super.dispose();
  }

  void _onDeviceManagerChanged() {
    if (mounted) setState(() {});
  }

  void _onCloudServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multi-Device Dashboard'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_getCloudStatusIcon()),
            onPressed: _showCloudStatusDialog,
            tooltip: 'Cloud Status',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Cloud Status Bar
          _buildCloudStatusBar(),

          // Device Statistics
          _buildDeviceStats(),

          // Device List
          Expanded(
            child: _buildDeviceList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshDevices,
        child: Icon(Icons.refresh),
        tooltip: 'Refresh Devices',
      ),
    );
  }

  IconData _getCloudStatusIcon() {
    final status = widget.deviceManager.getCloudStatus();
    final isOnline = status['isOnline'] as bool;
    final isSyncing = status['isSyncing'] as bool;
    final queuedItems = status['queuedItems'] as int;

    if (isSyncing) return Icons.cloud_sync;
    if (!isOnline) return Icons.cloud_off;
    if (queuedItems > 0) return Icons.cloud_queue;
    return Icons.cloud_done;
  }

  Widget _buildCloudStatusBar() {
    final status = widget.deviceManager.getCloudStatus();
    final isOnline = status['isOnline'] as bool;
    final isSyncing = status['isSyncing'] as bool;
    final queuedItems = status['queuedItems'] as int;

    Color statusColor = isOnline ? Colors.green : Colors.red;
    String statusText = isOnline ? 'Online' : 'Offline';

    if (isSyncing) {
      statusColor = Colors.blue;
      statusText = 'Syncing...';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: statusColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(_getCloudStatusIcon(), color: statusColor, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cloud Status: $statusText',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (queuedItems > 0)
                  Text(
                    '$queuedItems items queued for sync',
                    style: TextStyle(
                      color: statusColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (queuedItems > 0)
            TextButton(
              onPressed: () {
                widget.deviceManager.clearCloudQueue();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cloud queue cleared')),
                );
              },
              child: Text('Clear Queue'),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceStats() {
    final connectedDevices = widget.deviceManager.connectedDevices;
    final connectingDevices = widget.deviceManager.connectingDevices;
    final totalDevices = widget.deviceManager.devices.length;

    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(
            'Connected',
            connectedDevices.length.toString(),
            Icons.check_circle,
            Colors.green,
          ),
          _buildStatCard(
            'Connecting',
            connectingDevices.length.toString(),
            Icons.sync,
            Colors.orange,
          ),
          _buildStatCard(
            'Total',
            totalDevices.toString(),
            Icons.devices,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    final devices = widget.deviceManager.devices.values.toList();

    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Connect some devices to see them here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        DeviceData device = devices[index];
        return DeviceCard(
          deviceData: device,
          deviceManager: widget.deviceManager,
          onRemove: () => _removeDevice(device),
          onRetry: () => _retryConnection(device),
        );
      },
    );
  }

  void _removeDevice(DeviceData device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Device'),
        content: Text(
            'Are you sure you want to remove ${device.device.name.isEmpty ? 'this device' : device.device.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.deviceManager.removeDevice(device.device.id.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Device removed')),
              );
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _retryConnection(DeviceData device) {
    widget.deviceManager.retryConnection(device.device.id.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Retrying connection...')),
    );
  }

  void _refreshDevices() {
    // Trigger a refresh of device connections
    for (var device in widget.deviceManager.devices.values) {
      if (!device.isConnected && !device.isConnecting) {
        widget.deviceManager.retryConnection(device.device.id.id);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Refreshing device connections...')),
    );
  }

  void _showCloudStatusDialog() {
    final status = widget.deviceManager.getCloudStatus();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cloud Sync Status'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusRow(
                  'Status', status['isOnline'] ? 'Online' : 'Offline'),
              _buildStatusRow(
                  'Currently Syncing', status['isSyncing'] ? 'Yes' : 'No'),
              _buildStatusRow('Queued Items', status['queuedItems'].toString()),
              _buildStatusRow(
                  'Batch Buffer', status['batchBufferSize'].toString()),
              _buildStatusRow('Total Sent', status['totalSent'].toString()),
              _buildStatusRow('Total Failed', status['totalFailed'].toString()),
              _buildStatusRow(
                  'Failed Attempts', status['failedAttempts'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dashboard Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.cloud_queue),
              title: Text('Clear Cloud Queue'),
              subtitle: Text('Remove all pending sync data'),
              onTap: () {
                Navigator.pop(context);
                widget.deviceManager.clearCloudQueue();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cloud queue cleared')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.refresh),
              title: Text('Refresh All Devices'),
              subtitle: Text('Attempt to reconnect all devices'),
              onTap: () {
                Navigator.pop(context);
                _refreshDevices();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final DeviceData deviceData;
  final DeviceManager deviceManager;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const DeviceCard({
    Key? key,
    required this.deviceData,
    required this.deviceManager,
    required this.onRemove,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: deviceData.isConnected ? 4 : 2,
      child: Column(
        children: [
          ListTile(
            leading: _buildDeviceStatusIcon(),
            title: Text(
              deviceData.device.name.isEmpty
                  ? "Unknown Device"
                  : deviceData.device.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceData.device.id.id,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                _buildStatusChip(),
                if (deviceData.lastDataReceived != null)
                  Text(
                    'Last data: ${_formatTime(deviceData.lastDataReceived!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (deviceData.errorMessage != null)
                  Text(
                    'Error: ${deviceData.errorMessage}',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
              ],
            ),
            trailing: _buildActionMenu(context),
          ),
          if (deviceData.isConnected && deviceData.isReady)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCircularSlider(
                      value: deviceData.temperature,
                      min: -40,
                      max: 80,
                      trackColor: HexColor('#ef6c00'),
                      progressBarColor: HexColor('#ffb74d'),
                      shadowColor: HexColor('#ffb74d'),
                      label: 'Temperature',
                      unit: '°C',
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildCircularSlider(
                      value: deviceData.humidity,
                      min: 0,
                      max: 100,
                      trackColor: HexColor('#0277bd'),
                      progressBarColor: HexColor('#4FC3F7'),
                      shadowColor: HexColor('#B2EBF2'),
                      label: 'Humidity',
                      unit: '%',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusIcon() {
    if (deviceData.isConnecting) {
      return CircularProgressIndicator(strokeWidth: 2);
    } else if (deviceData.isConnected && deviceData.isReady) {
      return Icon(Icons.check_circle, color: Colors.green);
    } else if (deviceData.errorMessage != null) {
      return Icon(Icons.error, color: Colors.red);
    } else {
      return Icon(Icons.bluetooth_disabled, color: Colors.grey);
    }
  }

  Widget _buildStatusChip() {
    String statusText;
    Color statusColor;

    if (deviceData.isConnecting) {
      statusText = 'Connecting...';
      statusColor = Colors.orange;
    } else if (deviceData.isConnected && deviceData.isReady) {
      statusText = 'Connected';
      statusColor = Colors.green;
    } else if (deviceData.errorMessage != null) {
      statusText = 'Error';
      statusColor = Colors.red;
    } else {
      statusText = 'Disconnected';
      statusColor = Colors.grey;
    }

    return Chip(
      label: Text(
        statusText,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: statusColor,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert),
      itemBuilder: (context) => [
        if (!deviceData.isConnected)
          PopupMenuItem(
            value: 'retry',
            child: Row(
              children: [
                Icon(Icons.refresh, color: Colors.blue),
                SizedBox(width: 8),
                Text('Retry Connection'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Remove Device'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'retry':
            onRetry();
            break;
          case 'remove':
            onRemove();
            break;
        }
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildCircularSlider({
    required double value,
    required double min,
    required double max,
    required Color trackColor,
    required Color progressBarColor,
    required Color shadowColor,
    required String label,
    required String unit,
  }) {
    // Ensure value is within range
    double clampedValue = value.clamp(min, max);

    return SleekCircularSlider(
      appearance: CircularSliderAppearance(
        customWidths: CustomSliderWidths(
          trackWidth: 3,
          progressBarWidth: 8,
          shadowWidth: 15,
        ),
        customColors: CustomSliderColors(
          trackColor: trackColor.withOpacity(0.3),
          progressBarColor: progressBarColor,
          shadowColor: shadowColor.withOpacity(0.2),
          shadowMaxOpacity: 0.3,
          shadowStep: 20,
        ),
        infoProperties: InfoProperties(
          bottomLabelStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          bottomLabelText: label,
          mainLabelStyle: TextStyle(
            color: Colors.grey[800],
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          modifier: (double val) {
            return '${clampedValue.toStringAsFixed(1)}$unit';
          },
        ),
        startAngle: 90,
        angleRange: 270,
        size: 120,
        animationEnabled: true,
      ),
      min: min,
      max: max,
      initialValue: clampedValue,
      onChangeStart: null,
      onChangeEnd: null,
    );
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}
