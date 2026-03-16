// lib/Tracker/trac.dart
import 'dart:async' show Future, Timer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ViewModels/location_view_model.dart';

final locationViewModel = Get.put(LocationViewModel());
String gpxString = "";

// Function to start a timer
Future<void> startTimer() async {
  startTimerFromSavedTime();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // Periodically update the timer every second
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    await prefs.reload();
    locationViewModel.secondsPassed.value++; // ✅ This is correct
    await prefs.setInt('secondsPassed', locationViewModel.secondsPassed.value);
  });
}

// Function to start the timer from saved time in SharedPreferences
void startTimerFromSavedTime() {
  SharedPreferences.getInstance().then((prefs) async {
    await prefs.reload();
    // Retrieve saved time and calculate the total saved seconds
    String savedTime = prefs.getString('savedTime') ?? '00:00:00';
    List<String> timeComponents = savedTime.split(':');
    int hours = int.parse(timeComponents[0]);
    int minutes = int.parse(timeComponents[1]);
    int seconds = int.parse(timeComponents[2]);
    int totalSavedSeconds = hours * 3600 + minutes * 60 + seconds;

    // Calculate the current time in seconds
    final now = DateTime.now();
    int totalCurrentSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    locationViewModel.secondsPassed.value = totalCurrentSeconds - totalSavedSeconds;

    // Ensure secondsPassed is not negative
    if (locationViewModel.secondsPassed.value < 0) {
      locationViewModel.secondsPassed.value = 0;
    }
    await prefs.reload();
    await prefs.setInt('secondsPassed', locationViewModel.secondsPassed.value);
    if (kDebugMode) {
      print("Loaded Saved Time");
    }
  });
}