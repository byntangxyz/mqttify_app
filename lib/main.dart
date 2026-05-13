import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(SmartDeviceApp(prefs: prefs));
}

class SmartDeviceApp extends StatelessWidget {
  final SharedPreferences prefs;
  const SmartDeviceApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    bool hasSettings = prefs.getString('mqtt_ip') != null;
    return MaterialApp(
      title: 'MQTTify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: hasSettings
          ? DeviceControlPage(prefs: prefs)
          : SettingsPage(prefs: prefs),
    );
  }
}

// ---------------------------------------------------------
// SCREENS
// ---------------------------------------------------------

class SettingsPage extends StatefulWidget {
  final SharedPreferences prefs;
  const SettingsPage({super.key, required this.prefs});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ipController = TextEditingController();
  final _controlTopicController = TextEditingController();
  final _statusTopicController = TextEditingController();

  bool _testingConnection = false;
  bool _connectionSuccess = false;
  int _selectedIconIndex = 0;

  final List<IconData> _deviceIcons = [
    Icons.lightbulb_outline,
    Icons.power,
    Icons.tv,
    Icons.ac_unit,
    Icons.router,
    Icons.desktop_windows,
  ];

  @override
  void initState() {
    super.initState();
    _ipController.text = widget.prefs.getString('mqtt_ip') ?? '';
    _controlTopicController.text =
        widget.prefs.getString('control_topic') ?? 'smartlamp/control';
    _statusTopicController.text =
        widget.prefs.getString('status_topic') ?? 'smartlamp/status';
    _selectedIconIndex = widget.prefs.getInt('device_icon') ?? 0;
    if (_ipController.text.isNotEmpty) {
      _connectionSuccess = true;
    }
  }

  Future<void> _testConnection() async {
    if (_ipController.text.isEmpty) return;

    setState(() {
      _testingConnection = true;
      _connectionSuccess = false;
    });

    final client = MqttServerClient(
      _ipController.text,
      'test_client_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 10;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(
          'test_client_${DateTime.now().millisecondsSinceEpoch}',
        )
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      await client.connect().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Connection failed: $e');
      client.disconnect();
    }

    setState(() {
      _testingConnection = false;
      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        _connectionSuccess = true;
        client.disconnect();
        Fluttertoast.showToast(
          msg: 'Connection Successful!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        _connectionSuccess = false;
        Fluttertoast.showToast(
          msg: 'Connection Failed. Please check IP.',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    });
  }

  void _saveSettings() async {
    if (!_connectionSuccess) {
      Fluttertoast.showToast(
        msg: 'Please test connection successfully first.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    if (_controlTopicController.text.isEmpty ||
        _statusTopicController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Topics cannot be empty.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    await widget.prefs.setString('mqtt_ip', _ipController.text);
    await widget.prefs.setString('control_topic', _controlTopicController.text);
    await widget.prefs.setString('status_topic', _statusTopicController.text);
    await widget.prefs.setInt('device_icon', _selectedIconIndex);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DeviceControlPage(prefs: widget.prefs),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _controlTopicController.dispose();
    _statusTopicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Settings'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MQTT Setup',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'MQTT Broker IP Address',
                hintText: 'e.g. 10.80.80.218',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.wifi),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                setState(() {
                  _connectionSuccess = false;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _testingConnection || _ipController.text.isEmpty
                    ? null
                    : _testConnection,
                icon: _testingConnection
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _connectionSuccess
                            ? Icons.check_circle
                            : Icons.network_ping,
                      ),
                label: Text(
                  _connectionSuccess
                      ? 'Connection Verified'
                      : 'Test Connection',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _connectionSuccess
                      ? Colors.green
                      : Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            AnimatedOpacity(
              opacity: _connectionSuccess ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_connectionSuccess,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Device Configuration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controlTopicController,
                      decoration: InputDecoration(
                        labelText: 'Control Topic',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.send),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _statusTopicController,
                      decoration: InputDecoration(
                        labelText: 'Status Topic',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.mark_email_read),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Select Device Icon',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _deviceIcons.length,
                        itemBuilder: (context, index) {
                          final isSelected = index == _selectedIconIndex;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedIconIndex = index),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blueAccent.withOpacity(0.2)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blueAccent
                                      : Colors.grey[700]!,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _deviceIcons[index],
                                color: isSelected
                                    ? Colors.blueAccent
                                    : Colors.grey,
                                size: 32,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton(
                        onPressed: _saveSettings,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save & Continue',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceControlPage extends StatefulWidget {
  final SharedPreferences prefs;
  const DeviceControlPage({super.key, required this.prefs});

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  late MqttServerClient client;
  late String ipAddress;
  late String controlTopic;
  late String statusTopic;
  late IconData deviceIcon;

  bool isConnected = false;
  bool isDeviceOn = false;
  String connectionStatus = 'Connecting...';

  final List<IconData> _deviceIcons = [
    Icons.lightbulb_outline,
    Icons.power,
    Icons.tv,
    Icons.ac_unit,
    Icons.router,
    Icons.desktop_windows,
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _connectMQTT();
  }

  void _loadSettings() {
    ipAddress = widget.prefs.getString('mqtt_ip') ?? '';
    controlTopic =
        widget.prefs.getString('control_topic') ?? 'smartlamp/control';
    statusTopic = widget.prefs.getString('status_topic') ?? 'smartlamp/status';
    int iconIdx = widget.prefs.getInt('device_icon') ?? 0;

    if (iconIdx < 0 || iconIdx >= _deviceIcons.length) iconIdx = 0;
    deviceIcon = _deviceIcons[iconIdx];
  }

  Future<void> _connectMQTT() async {
    if (ipAddress.isEmpty) return;

    setState(() {
      connectionStatus = 'Connecting...';
    });

    client = MqttServerClient(
      ipAddress,
      'app_client_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(
          'app_client_${DateTime.now().millisecondsSinceEpoch}',
        )
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      await client.connect().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      setState(() {
        isConnected = true;
        connectionStatus = 'Connected';
      });

      client.subscribe(statusTopic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c != null && c.isNotEmpty) {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String payload = MqttPublishPayload.bytesToStringAsString(
            recMess.payload.message,
          );

          if (c[0].topic == statusTopic) {
            setState(() {
              isDeviceOn =
                  payload.toUpperCase() == 'ON' ||
                  payload == '1' ||
                  payload.toLowerCase() == 'true';
            });
          }
        }
      });
    } else {
      setState(() {
        connectionStatus = 'Disconnected';
        isConnected = false;
      });
    }
  }

  void onConnected() {
    debugPrint('Connected');
  }

  void onDisconnected() {
    debugPrint('Disconnected');
    setState(() {
      isConnected = false;
      connectionStatus = 'Disconnected';
      isDeviceOn = false;
    });
  }

  void toggleDevice() {
    if (!isConnected) {
      Fluttertoast.showToast(
        msg: 'Not connected to MQTT Broker. Please reconnect.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final bool newState = !isDeviceOn;
    final String payload = newState ? 'ON' : 'OFF';

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage(controlTopic, MqttQos.exactlyOnce, builder.payload!);

    setState(() {
      isDeviceOn = newState;
    });
  }

  void _openSettings() {
    client.disconnect();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SettingsPage(prefs: widget.prefs),
      ),
    );
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Colors.blueAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Control'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: isConnected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connectionStatus,
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isConnected && connectionStatus != 'Connecting...') ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _connectMQTT,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 80),
            GestureDetector(
              onTap: toggleDevice,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDeviceOn ? activeColor : const Color(0xFF2C2C2E),
                  boxShadow: [
                    if (isDeviceOn)
                      BoxShadow(
                        color: activeColor.withOpacity(0.6),
                        blurRadius: 50,
                        spreadRadius: 15,
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      deviceIcon,
                      key: ValueKey<bool>(isDeviceOn),
                      size: 100,
                      color: isDeviceOn ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
            Text(
              isDeviceOn ? 'DEVICE ON' : 'DEVICE OFF',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: isDeviceOn ? activeColor : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
