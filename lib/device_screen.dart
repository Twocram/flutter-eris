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
  String stateText = 'Подключение';
  String connectButtonText = 'Отключиться';
  String deviceRemoteId = '';
  String deviceCharUuid = '';
  String serviceUuid = '';
  bool isConnected = false;
  bool isCharGetted = false;

  final utf8Decoder = utf8.decoder;
  List<String> decodedValues = [];
  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;

  StreamSubscription<BluetoothDeviceState>? _stateListener;

  @override
  void initState() {
    _stateListener = widget.device.state.listen((event) {
      // debugPrint('event: $event');
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
        if (c.properties.read) {
          deviceCharUuid = c.uuid.toString();
          deviceRemoteId = c.serviceUuid.toString();
          List<int> value = await c.read();
          if (value.isNotEmpty) {
            try {
              final String decodedBytes = utf8Decoder.convert(value);
              decodedValues.add(decodedBytes);
            } catch (e) {
              // print("ERROR DECODING ${e}");
            }
          } else {
            print("NO DATA");
          }
        }
      }
    }
    isCharGetted = true;
    // print("ДЕКОДИРОВАННЫЕ ДАННЫЕ: ${decodedValues}");
    // print("CHARACTERISTIC_UUID-устройства: ${deviceCharUuid}");
    // print("REMOTE_ID-устройства: ${deviceRemoteId}");
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
        isConnected = false;
        break;

      case BluetoothDeviceState.disconnecting:
        stateText = "Отключение";
        break;

      case BluetoothDeviceState.connected:
        stateText = "Подключен";
        connectButtonText = "Отключиться";
        isConnected = true;
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

  Widget renderBtn(bool isConnected) {
    return isConnected
        ? OutlinedButton(
            onPressed: getDeviceInfo, child: Text("Узнать информацию"))
        : Text('');
  }

  Widget displayChars(bool charGetted) {
    return charGetted
        ? SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: decodedValues.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text('${decodedValues[index]}'));
              },
            ),
          )
        : Text('');
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
            renderBtn(isConnected),
            Container(
              padding: EdgeInsets.all(30),
              child: Column(
                children: [
                  displayChars(isCharGetted),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
