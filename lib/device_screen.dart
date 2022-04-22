import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_ble/main.dart';
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
  bool isServicesGetted = false;

  final utf8Decoder = utf8.decoder;
  final List<String> decodedValues = <String>[];
  List<String> deviceServices = [];

  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;

  StreamSubscription<BluetoothDeviceState>? _stateListener;

  @override
  void initState() {
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _stateListener = widget.device.state.listen((event) {
        // debugPrint('event: $event');
        if (deviceState == event) {
          return;
        }
        setBleConnectionState(event);
      });

      connect();
    });
  }

  openWriteDialog(String uuid) {
    inputDialog(context, uuid);
  }

  writeDataInDevice(String userValue, String deviceUuid) async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (final BluetoothService s in services) {
      print("SERVICE --------------- ${s.uuid}");
      var chars = s.characteristics;
      for (final BluetoothCharacteristic c in chars) {
        if (c.uuid.toString() == deviceUuid) {
          try {
            await c.write(utf8.encode(userValue));
            setState(() {
              decodedValues.add(userValue);
            });
            print(decodedValues);
          } catch (e) {
            print("Не удалось добавить данные");
          }
        }
        // if (c.properties.write == true) {
        //   try {
        //     await c.write(utf8.encode(userValue), withoutResponse: true);
        //     decodedValues.add(userValue);
        //     print("ДАННЫЕ УСПЕШНО ДОБАВЛЕНЫ");
        //   } catch (e) {
        //     print("Не удалось добавить данные: ${e}");
        //   }
        // }
      }
    }
  }

  getDeviceServices() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (final BluetoothService s in services) {
      var chars = s.characteristics;
      for (final BluetoothCharacteristic c in chars) {
        if (c.properties.write) {
          deviceServices.add(c.uuid.toString());
        }
      }
    }
    setState(() {
      isServicesGetted = true;
    });
  }

  // getCharItem(String uuid) async {
  //   List<BluetoothService> services = await widget.device.discoverServices();
  //   for (final BluetoothService s in services) {
  //     var chars = s.characteristics;
  //     for (final BluetoothCharacteristic c in chars) {
  //       if (c.uuid.toString() == uuid) {
  //         serviceItemChars.add(c.uuid.toString());
  //       }
  //     }
  //   }
  // }

  getDeviceInfo() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (final BluetoothService service in services) {
      print("SERVICE -------- ${service}");
      var characteristics = service.characteristics;
      for (final BluetoothCharacteristic c in characteristics) {
        if (c.properties.read) {
          List<int> value = await c.read();
          if (value.isNotEmpty) {
            try {
              final String decodedBytes = utf8Decoder.convert(value);
              setState(() {
                decodedValues.add(decodedBytes);
              });
            } catch (e) {
              // print("ERROR DECODING ${e}");
            }
          } else {
            print("НЕТ ДАННЫХ");
          }
        }
      }
    }
    setState(() {
      isCharGetted = true;
    });
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
        setState(() {
          isCharGetted = false;
          isServicesGetted = false;
        });
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

  Future inputDialog(BuildContext context, String uuid) async {
    String customValue = "";
    Future.delayed(Duration.zero, () async {
      return showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Добавить данные"),
              content: new Row(
                children: <Widget>[
                  new Expanded(
                      child: new TextField(
                    autofocus: true,
                    decoration: new InputDecoration(
                        labelText: "Название", hintText: 'Новое значение'),
                    onChanged: (value) {
                      customValue = value;
                    },
                  ))
                ],
              ),
              actions: <Widget>[
                FlatButton(
                    onPressed: () => {Navigator.of(context).pop()},
                    child: Text("Назад")),
                FlatButton(
                    onPressed: () {
                      writeDataInDevice(customValue, uuid);
                      Navigator.of(context).pop();
                    },
                    child: Text("Добавить"))
              ],
            );
          });
    });
  }

  Future<bool> connect() async {
    Future<bool>? returnValue;

    setState(() {
      stateText = "Подключение";
    });

    await widget.device
        .connect(autoConnect: false)
        .timeout(Duration(milliseconds: 20000), onTimeout: () {
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

  Widget getDeviceInfoBtn(bool isConnected) {
    return isConnected
        ? OutlinedButton(
            onPressed: getDeviceInfo, child: Text("Узнать информацию"))
        : Text('');
  }

  Widget getDeviceServicesBtn(bool isConnected) {
    return isConnected
        ? OutlinedButton(
            onPressed: () => getDeviceServices(),
            child: Text("Узнать services uuid"))
        : Text('');
  }

  // Widget writeDataInDeviceBtn(bool isConnected) {
  //   return isConnected
  //       ? OutlinedButton(
  //           onPressed: openWriteDialog, child: Text("Добавить характеристики"))
  //       : Text('');
  // }

  // Widget displayServiceChars() {
  //   return SizedBox(
  //     child: ListView.builder(
  //         itemCount: serviceItemChars.length,
  //         itemBuilder: (context, index) {
  //           return ListTile(
  //             title: Text(serviceItemChars[index]),
  //           );
  //         }),
  //   );
  // }

  Widget displayServices(bool isServicesGetted) {
    return isServicesGetted
        ? SizedBox(
            height: 600,
            child: ListView.builder(
                itemCount: deviceServices.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      "${deviceServices[index]}",
                      style: TextStyle(fontSize: 14),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                            onPressed: () {
                              openWriteDialog(deviceServices[index].toString());
                            },
                            icon: Icon(Icons.more_vert))
                      ],
                    ),
                  );
                }))
        : Text('');
  }

  Widget displayChars(bool charGetted) {
    return charGetted
        ? SizedBox(
            height: 600,
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
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: IconButton(
            iconSize: 36,
            icon: Icon(Icons.arrow_back),
            onPressed: () => {
              disconnect(),
              Navigator.pop(context),
            },
          ),
          title: Text(widget.device.name),
        ),
        body: ListView(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$stateText'),
                  OutlinedButton(
                      onPressed: () {
                        if (deviceState == BluetoothDeviceState.connected) {
                          disconnect();
                        } else if (deviceState ==
                            BluetoothDeviceState.disconnected) {
                          connect();
                        } else {}
                      },
                      child: Text(connectButtonText)),
                  getDeviceInfoBtn(isConnected),
                  getDeviceServicesBtn(isConnected),
                  // writeDataInDeviceBtn(isConnected),
                  Container(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        displayChars(isCharGetted),
                      ],
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.fromLTRB(20, 10, 20, 30),
                    // padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        displayServices(isServicesGetted),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ));
  }
}
