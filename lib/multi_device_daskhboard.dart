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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multi-Device Dashboard'),
      ),
      body: AnimatedBuilder(
        animation: widget.deviceManager,
        builder: (context, child) {
          List<DeviceData> devices = widget.deviceManager.connectedDevices;

          if (devices.isEmpty) {
            return Center(
              child: Text(
                'No connected devices',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              DeviceData device = devices[index];
              return DeviceCard(
                deviceData: device,
                onRemove: () {
                  widget.deviceManager.removeDevice(device.device.id.id);
                  if (widget.deviceManager.connectedDevices.isEmpty) {
                    Navigator.pop(context);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final DeviceData deviceData;
  final VoidCallback onRemove;

  const DeviceCard({
    Key? key,
    required this.deviceData,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Text(
              deviceData.device.name.isEmpty
                  ? "Unknown Device"
                  : deviceData.device.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Text(deviceData.device.id.id),
            trailing: IconButton(
              icon: Icon(Icons.close),
              onPressed: onRemove,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildCircularSlider(
                    value: deviceData.temperature,
                    min: 0,
                    max: 100,
                    trackColor: HexColor('#ef6c00'),
                    progressBarColor: HexColor('#ffb74d'),
                    shadowColor: HexColor('#ffb74d'),
                    label: 'Temperature',
                    unit: '˚C',
                  ),
                ),
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
    return SleekCircularSlider(
      appearance: CircularSliderAppearance(
        customWidths: CustomSliderWidths(
            trackWidth: 2, progressBarWidth: 10, shadowWidth: 20),
        customColors: CustomSliderColors(
          trackColor: trackColor,
          progressBarColor: progressBarColor,
          shadowColor: shadowColor,
          shadowMaxOpacity: 0.5,
          shadowStep: 20,
        ),
        infoProperties: InfoProperties(
          bottomLabelStyle: TextStyle(
            color: HexColor('#6DA100'),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bottomLabelText: label,
          mainLabelStyle: TextStyle(
            color: HexColor('#54826D'),
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
          ),
          modifier: (double val) {
            return '${value.toStringAsFixed(1)} $unit';
          },
        ),
        startAngle: 90,
        angleRange: 360,
        size: 150.0,
        animationEnabled: true,
      ),
      min: min,
      max: max,
      initialValue: value,
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
