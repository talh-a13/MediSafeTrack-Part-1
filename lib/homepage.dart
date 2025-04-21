import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

class HomeUI extends StatelessWidget {
  final double temperature;
  final double humidity;

  const HomeUI({Key? key, required this.temperature, required this.humidity})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCircularSlider(
              value: temperature,
              min: 0,
              max: 100,
              label: 'Temperature',
              unit: '°C',
              trackColor: Colors.orange,
              progressBarColor: Colors.deepOrange,
            ),
            SizedBox(height: 50),
            buildCircularSlider(
              value: humidity,
              min: 0,
              max: 100,
              label: 'Humidity',
              unit: '%',
              trackColor: Colors.blue,
              progressBarColor: Colors.lightBlueAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCircularSlider({
    required double value,
    required double min,
    required double max,
    required String label,
    required String unit,
    required Color trackColor,
    required Color progressBarColor,
  }) {
    return SleekCircularSlider(
      appearance: CircularSliderAppearance(
        customWidths: CustomSliderWidths(progressBarWidth: 10),
        customColors: CustomSliderColors(
          trackColor: trackColor,
          progressBarColor: progressBarColor,
        ),
        infoProperties: InfoProperties(
          modifier: (double val) => '${val.toStringAsFixed(1)} $unit',
          bottomLabelText: label,
        ),
      ),
      min: min,
      max: max,
      initialValue: value,
    );
  }
}
