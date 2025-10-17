/// Simple Heartbeat BLE Peripheral Example
///
/// This is a minimal Flutter app showing how to:
/// 1. Initialize BLE peripheral
/// 2. Add a service with notify characteristic
/// 3. Send periodic heartbeat messages
/// 4. Track connected devices

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral_slave/flutter_ble_peripheral_slave.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Peripheral Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BlePeripheralExample(),
    );
  }
}

class BlePeripheralExample extends StatefulWidget {
  const BlePeripheralExample({super.key});

  @override
  State<BlePeripheralExample> createState() => _BlePeripheralExampleState();
}

class _BlePeripheralExampleState extends State<BlePeripheralExample> {
  final heartbeatDevice = SimpleHeartbeatDevice();
  bool isInitialized = false;
  bool isAdvertising = false;
  String statusMessage = 'Not initialized';
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _initializeBle();
  }

  void _addLog(String message) {
    setState(() {
      logs.insert(
          0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (logs.length > 20) logs.removeLast();
    });
  }

  Future<void> _initializeBle() async {
    try {
      await heartbeatDevice.initialize();
      setState(() {
        isInitialized = true;
        statusMessage = 'Initialized successfully';
      });
      _addLog('BLE Peripheral initialized');
    } catch (e) {
      setState(() {
        statusMessage = 'Failed to initialize: $e';
      });
      _addLog('Error: $e');
    }
  }

  Future<void> _startAdvertising() async {
    if (!isInitialized) {
      _addLog('Please initialize first');
      return;
    }

    try {
      await heartbeatDevice.startAdvertising();
      setState(() {
        isAdvertising = true;
        statusMessage = 'Advertising started';
      });
      _addLog('Started advertising');
    } catch (e) {
      _addLog('Failed to start advertising: $e');
    }
  }

  Future<void> _stopAdvertising() async {
    try {
      await BlePeripheral.stopAdvertising();
      setState(() {
        isAdvertising = false;
        statusMessage = 'Advertising stopped';
      });
      _addLog('Stopped advertising');
      heartbeatDevice.cleanup();
    } catch (e) {
      _addLog('Failed to stop advertising: $e');
    }
  }

  @override
  void dispose() {
    heartbeatDevice.cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Peripheral Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(statusMessage),
                    const SizedBox(height: 8),
                    Text(
                      'Connected Devices: ${heartbeatDevice.connectedDevices.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isAdvertising ? null : _startAdvertising,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Advertising'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isAdvertising ? _stopAdvertising : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Advertising'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Activity Log',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: logs.isEmpty
                    ? const Center(
                        child: Text('No activity yet'),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 4.0,
                            ),
                            child: Text(
                              logs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple heartbeat BLE peripheral device
class SimpleHeartbeatDevice {
  // Service and Characteristic UUIDs
  static const String serviceUuid =
      "0000180D-0000-1000-8000-00805F9B34FB"; // Heart Rate Service
  static const String characteristicUuid =
      "00002A37-0000-1000-8000-00805F9B34FB"; // Heart Rate Measurement

  // Track connected devices and their subscriptions
  final Set<String> connectedDevices = {};
  Timer? heartbeatTimer;
  int heartbeatCounter = 0;

  Future<void> initialize() async {
    await BlePeripheral.initialize();

    // Set up callbacks
    BlePeripheral.setBleStateChangeCallback((isOn) {
      print("BLE State Changed: ${isOn ? 'ON' : 'OFF'}");
    });

    BlePeripheral.setAdvertisingStatusUpdateCallback((advertising, error) {
      if (error != null) {
        print("Advertising Error: $error");
      } else {
        print("Advertising: ${advertising ? 'Started' : 'Stopped'}");
      }
    });

    BlePeripheral.setCharacteristicSubscriptionChangeCallback((
      String deviceId,
      String characteristic,
      bool isSubscribed,
      String? deviceName,
    ) {
      print("Device $deviceId (${deviceName ?? 'Unknown'}) "
          "${isSubscribed ? 'subscribed to' : 'unsubscribed from'} "
          "$characteristic");

      if (isSubscribed) {
        connectedDevices.add(deviceId);
        if (heartbeatTimer == null) {
          _startHeartbeat();
        }
      } else {
        connectedDevices.remove(deviceId);
        if (connectedDevices.isEmpty) {
          _stopHeartbeat();
        }
      }
    });
  }

  Future<void> startAdvertising() async {
    // Add the heart rate service
    await BlePeripheral.addService(
      BleService(
        uuid: serviceUuid,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: characteristicUuid,
            properties: [
              CharacteristicProperties.read.index,
              CharacteristicProperties.notify.index,
            ],
            value: null,
            permissions: [AttributePermissions.readable.index],
          ),
        ],
      ),
    );

    // Start advertising
    if (Platform.isAndroid) {
      await BlePeripheral.startAdvertising(
        services: [serviceUuid],
        localName: "HeartRate Monitor",
      );
    } else {
      await BlePeripheral.startAdvertising(
        services: [serviceUuid],
        localName: "HeartRate Monitor",
        manufacturerData: ManufacturerData(
          manufacturerId: 1234,
          data: Uint8List.fromList([0x01, 0x02]),
        ),
      );
    }
  }

  void _startHeartbeat() {
    print("Starting heartbeat timer");
    heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (connectedDevices.isNotEmpty) {
        heartbeatCounter++;
        // Simulate heart rate between 60-100 bpm
        int heartRate = 60 + (heartbeatCounter % 40);

        // Heart Rate Measurement format: flags byte + heart rate value
        Uint8List heartRateData = Uint8List.fromList([
          0x00, // Flags: Heart Rate Value Format is UINT8
          heartRate, // Heart rate value
        ]);

        try {
          await BlePeripheral.updateCharacteristic(
            characteristicId: characteristicUuid,
            value: heartRateData,
            deviceId: null, // null sends to all connected devices
          );
          print(
              "Sent heartbeat $heartbeatCounter: ${heartRate}bpm to ${connectedDevices.length} device(s)");
        } catch (e) {
          print("Error sending heartbeat: $e");
        }
      }
    });
  }

  void _stopHeartbeat() {
    print("Stopping heartbeat timer");
    heartbeatTimer?.cancel();
    heartbeatTimer = null;
    heartbeatCounter = 0;
  }

  void cleanup() {
    _stopHeartbeat();
    connectedDevices.clear();
  }
}
