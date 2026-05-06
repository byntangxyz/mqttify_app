import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const SmartLampApp());
}

class SmartLampApp extends StatelessWidget {
  const SmartLampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Lamp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const LampControlPage(),
    );
  }
}

class LampControlPage extends StatefulWidget {
  const LampControlPage({super.key});

  @override
  State<LampControlPage> createState() => _LampControlPageState();
}

class _LampControlPageState extends State<LampControlPage> {
  // MQTT Setup
  late MqttServerClient client;
  final String controlTopic = 'smartlamp/control';
  final String statusTopic = 'smartlamp/status';

  bool isConnected = false;
  bool isLampOn = false;
  String connectionStatus = 'Disconnected';

  @override
  void initState() {
    super.initState();
    client = MqttServerClient(
      '10.80.80.218',
      'smartlamp_app_client_${DateTime.now().millisecondsSinceEpoch}',
    );
    _connectMQTT();
  }

  Future<void> _connectMQTT() async {
    setState(() {
      connectionStatus = 'Connecting...';
    });

    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(
          'smartlamp_app_client_${DateTime.now().millisecondsSinceEpoch}',
        )
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('Exception connecting to MQTT: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() {
        isConnected = true;
        connectionStatus = 'Connected';
      });

      // Subscribe to the status topic
      client.subscribe(statusTopic, MqttQos.atMostOnce);

      // Listen for updates
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c != null && c.isNotEmpty) {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String payload = MqttPublishPayload.bytesToStringAsString(
            recMess.payload.message,
          );

          if (c[0].topic == statusTopic) {
            setState(() {
              isLampOn =
                  payload.toUpperCase() == 'ON' ||
                  payload == '1' ||
                  payload.toLowerCase() == 'true';
            });
          }
        }
      });
    } else {
      setState(() {
        connectionStatus = 'Failed to connect';
        isConnected = false;
      });
      client.disconnect();
    }
  }

  void onConnected() {
    debugPrint('MQTT Connected');
  }

  void onDisconnected() {
    debugPrint('MQTT Disconnected');
    setState(() {
      isConnected = false;
      connectionStatus = 'Disconnected';
      isLampOn = false;
    });
  }

  void toggleLamp() {
    if (!isConnected) return;

    final bool newState = !isLampOn;
    // We send 'ON' or 'OFF'.
    final String payload = newState ? 'ON' : 'OFF';

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    client.publishMessage(controlTopic, MqttQos.exactlyOnce, builder.payload!);

    // Optimistic UI update
    setState(() {
      isLampOn = newState;
    });
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isLampOn ? Colors.amber[50] : Colors.grey[900];
    final titleColor = isLampOn ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Smart Lamp Control', style: TextStyle(color: titleColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
                ],
              ),
            ),
            const SizedBox(height: 80),
            GestureDetector(
              onTap: toggleLamp,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLampOn ? Colors.amber : Colors.grey[800],
                  boxShadow: [
                    if (isLampOn)
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.6),
                        blurRadius: 60,
                        spreadRadius: 20,
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 120,
                    color: isLampOn ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
            Text(
              isLampOn ? 'POWER: ON' : 'POWER: OFF',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: isLampOn ? Colors.amber[900] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
