# MQTTify

Welcome to **MQTTify**
The sleek, modern, and simple Flutter application to communicate with your MQTT Broker and reliably trigger remote IoT devices like a Smart Lamp instantly.

## Features

- **Custom Connections:** Directly input your local/remote Mosquitto MQTT Broker IP Address manually without hardcoding.
- **Intuitive Feedback:** Includes a connection tester that securely verifies your Mosquitto handshake right on the settings page, and warns of disconnection if your phone sleeps or loses Wi-Fi!
- **Flexible Topics:** Define your dynamic MQTT custom `control` (publish) and `status` (subscribe) topics right in the app.
- **Persistent Configuration:** Automatically saves and loads your credentials and layouts locally using SharedPreferences.
- **Customizable UI:** Not a lamp? Pick from 6 dynamic interactive button templates (Lamp, Power Button, TV, AC, Router, Desktop).

---

## Download & Install (For Android)

You can grab the latest production-ready Android APK release directly provided in the `Releases` tab of this GitHub repository!

1. Download `app-release.apk` to your phone.
2. Tap the file to Install it. (You may have to initially allow "Install from Unknown Sources").
3. Connect your Android device to the corresponding Wi-Fi network hosting your MQTT Server.
4. Launch the **MQTTify** app!

## Build it Yourself

If you want to pull this code from GitHub and compile the debug / release app on your own machine:

1. Setup the standard [Flutter Environment](https://docs.flutter.dev/get-started/install).
2. Clone this repository locally.
3. Install dependencies by running `flutter pub get`.

Once you're ready, generate the Android release APK containing your fresh image!

```bash
flutter build apk --release
```
