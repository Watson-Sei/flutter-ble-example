import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';

class Scan extends StatefulWidget {
  @override
  _ScanState createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> devices = [];
  String message = '';
  bool _scanStarted = false;
  bool _connected = false;
  late StreamSubscription<$DiscoveredDevice> _scanStream;
  final Uuid serviceUuid = Uuid.parse('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  final Uuid TxcharacteristicUuid = Uuid.parse('6e400003-b5a3-f393-e0a9-e50e24dcca9e');
  final Uuid RxcharacteristicUuid = Uuid.parse('6e400002-b5a3-f393-e0a9-e50e24dcca9e');

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  _scan() async {
    if (_scanStarted) {
      await _scanStream.cancel();
    }
    setState(() {
      _scanStarted = true;
    });
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        return;
      }
    }
    _scanStream = flutterReactiveBle.scanForDevices(withServices: [serviceUuid], scanMode: ScanMode.lowLatency).listen((device) {
      if (!devices.any((existingDevice) => existingDevice.id == device.id)) {
            devices.add(device);
            setState(() {
              message = 'デバイス発見';
            });
          }
    });
  }

  _connectToDevice(DiscoveredDevice device) async {
    // final connection = flutterReactiveBle.connectToAdvertisingDevice(
    //     id: device.id,
    //     withServices: [],
    //     prescanDuration: Duration(seconds: 10),
    // );
    if (_scanStarted) {
      await _scanStream.cancel();
      _scanStarted = false;
    }
    final connection = flutterReactiveBle.connectToDevice(
        id: device.id,
    );
    connection.listen((connectionState) {
      setState(() {
        message = 'Connection state: ${connectionState}';
      });
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        setState(() {
          message = '接続しました';
        });
        final mtu = flutterReactiveBle.requestMtu(deviceId: device.id, mtu: 250);
        setState(() {
          message = mtu.toString();
        });
        _readCharacteristic(
          device
        );
      }
    }, onError: (e) {
      setState(() {
        message = e.toString();
      });
    });
  }

  _readCharacteristic(DiscoveredDevice device) async {
    setState(() {
      message = 'メッセージを開始しました';
    });
    final TxCharacteristic = QualifiedCharacteristic(
      characteristicId: TxcharacteristicUuid,
      serviceId: serviceUuid,
      deviceId: device.id
    );
    final RxCharacteristic = QualifiedCharacteristic(
        characteristicId: RxcharacteristicUuid,
        serviceId: serviceUuid,
        deviceId: device.id,
    );
    final subs = flutterReactiveBle.subscribeToCharacteristic(TxCharacteristic).listen((data) {
      // Process the received data as needed.
      setState(() {
        message = '${DateTime.now()}: ${String.fromCharCodes(data)}';
      });
    }, onError: (dynamic error) {
      print('Failed to subscribe: ${error}');
      setState(() {
        message = 'Failed to subscribe: ${error}';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('BLE Scanner'),
          ),
          body: Column(
            children: [
              IconButton(
                onPressed: () {
                  _scan();
                },
                icon: Icon(Icons.play_arrow),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(devices[index].name),
                      subtitle: Text(devices[index].id),
                      trailing: ElevatedButton(
                        child: Text("Connect"),
                        onPressed: (){
                          _connectToDevice(devices[index]);
                        },
                      ),
                    );
                  },
                ),
              ),
              Text(message),
            ],
          )
      ),
    );
  }
}

