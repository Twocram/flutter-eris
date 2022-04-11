import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class DeviceScreen extends StatefulWidget {
  DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;
  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothCharacteristic> deviceChars = [];
  String stateText = 'Подключение';
  String connectButtonText = 'Отключиться';
  final utf8Decoder = utf8.decoder;
  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;

  StreamSubscription<BluetoothDeviceState>? _stateListener;

  @override
  void initState() {
    _stateListener = widget.device.state.listen((event) {
      debugPrint('event: $event');
      if (deviceState == event) {
        return;
      }

      setBleConnectionState(event);
    });

    connect();
  }

  getDeviceInfo() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (final BluetoothService service in services) {
      var characteristics = service.characteristics;
      for (final BluetoothCharacteristic c in characteristics) {
        print("ХАРАКТЕРИСТИКА: ${c}");
        if (c.properties.read) {
          List<int> value = await c.read();
          if (value.isNotEmpty) {
            // decoded = utf8.decoder.convert(value);
            // print("ДЕКОДИРОВАННЫЕ ДАННЫЕ: ${decoded}");
            // TODO: need code for convert
            try {
              final String decoded = utf8Decoder.convert(value);
              print("ДЕКОДИРОВАННЫЕ ДАННЫЕ: ${decoded}");
            } catch (e) {
              print(e);
            }
          } else {
            print("НЕТ ДАННЫХ");
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _stateListener?.cancel();
    disconnect();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  setBleConnectionState(BluetoothDeviceState event) {
    switch (event) {
      case BluetoothDeviceState.disconnected:
        stateText = 'Отключен';
        connectButtonText = 'Подключиться';
        break;

      case BluetoothDeviceState.disconnecting:
        stateText = "Отключение";
        break;

      case BluetoothDeviceState.connected:
        stateText = "Подключен";
        connectButtonText = "Отключиться";
        // getDeviceInfo();
        break;

      case BluetoothDeviceState.connecting:
        stateText = 'Подключение';
        break;
    }

    deviceState = event;
    setState(() {});
  }

  Future<bool> connect() async {
    Future<bool>? returnValue;

    setState(() {
      stateText = "Подключение";
    });

    await widget.device
        .connect(autoConnect: false)
        .timeout(Duration(milliseconds: 10000), onTimeout: () {
      returnValue = Future.value(false);
      debugPrint("Время подключения истекло");

      setBleConnectionState(BluetoothDeviceState.disconnected);
    }).then((data) {
      if (returnValue == null) {
        debugPrint('Успешное подключение');
        returnValue = Future.value(true);
      }
    });

    return returnValue ?? Future.value(false);
  }

  void disconnect() {
    try {
      setState(() {
        stateText = "Отключение";
      });
      widget.device.disconnect();
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$stateText'),
            OutlinedButton(
                onPressed: () {
                  if (deviceState == BluetoothDeviceState.connected) {
                    disconnect();
                  } else if (deviceState == BluetoothDeviceState.disconnected) {
                    connect();
                  } else {}
                },
                child: Text(connectButtonText)),
            OutlinedButton(
                onPressed: getDeviceInfo, child: Text("Узнать информацию")),
          ],
        ),
      ),
    );
  }
}
