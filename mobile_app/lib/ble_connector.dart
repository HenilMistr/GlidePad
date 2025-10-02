import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Add to pubspec.yaml

class BLEConnector {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeChar;
  Function(Map<String, dynamic>)? onProfileReceived;

  Future<void> scanAndConnect() async {
    await flutterBlue.startScan(timeout: Duration(seconds: 4));

    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name?.startsWith('TrackPadHost_') == true) {
          _connectToDevice(r.device);
          flutterBlue.stopScan();
          break;
        }
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    connectedDevice = device;
    await device.connect();
    
    var services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString().contains('a5f2')) { // Your custom UUID
        for (var char in service.characteristics) {
          if (char.properties.write) writeChar = char;
          if (char.properties.notify) {
            char.value.listen((data) {
              _handleIncomingMessage(String.fromCharCodes(data));
            });
          }
        }
      }
    }

    // Request profile on connect
    await sendCommand({'cmd': 'request_profile'});
  }

  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (writeChar != null) {
      String json = jsonEncode(command);
      await writeChar!.write(utf8.encode(json));
    }
  }

  void _handleIncomingMessage(String message) {
    try {
      Map<String, dynamic> data = jsonDecode(message);
      if (data.containsKey('profile')) {
        onProfileReceived?.call(data['profile']);
      }
    } catch (e) {
      print("Parse error: $e");
    }
  }

  Future<void> sendTouchMove(int dx, int dy) async {
    await sendCommand({
      'cmd': 'move',
      'dx': dx,
      'dy': dy,
    });
  }

  Future<void> sendTap(int fingers) async {
    await sendCommand({
      'cmd': 'tap',
      'fingers': fingers,
    });
  }

  Future<void> sendScroll(int dy) async {
    await sendCommand({
      'cmd': 'scroll',
      'dy': dy,
    });
  }
}