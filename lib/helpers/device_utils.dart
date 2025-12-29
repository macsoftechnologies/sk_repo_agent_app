// import 'dart:io';
// import 'package:device_info_plus/device_info_plus.dart';
//
// class DeviceUtils {
//   static Future<String> getDeviceId() async {
//     DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//
//     if (Platform.isAndroid) {
//       AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//       return androidInfo.id ?? androidInfo.serialNumber ?? "unknown";
//     } else if (Platform.isIOS) {
//       IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//       return iosInfo.identifierForVendor ?? "unknown";
//     } else {
//       return "unknown";
//     }
//   }
// }
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceUtils {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const Uuid _uuid = Uuid();

  static const String _windowsDeviceKey = "windows_device_id";

  static Future<String> getDeviceId() async {
    try {
      // ANDROID
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      }

      // IOS
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "ios_unknown";
      }

      // WINDOWS ✅
      if (Platform.isWindows) {
        final prefs = await SharedPreferences.getInstance();

        String? storedId = prefs.getString(_windowsDeviceKey);
        if (storedId != null && storedId.isNotEmpty) {
          return storedId;
        }

        // Generate & save UUID once
        final newId = _uuid.v4();
        await prefs.setString(_windowsDeviceKey, newId);
        return newId;
      }

      return "unknown";
    } catch (e) {
      return "unknown";
    }
  }
}

