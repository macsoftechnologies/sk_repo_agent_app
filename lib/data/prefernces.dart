import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static SharedPreferences? _prefs;

  static const String authCode = 'authCode';
  static const String userID = 'userID'; // fixed from int to String
  static const String name = 'name';
  static const String email = 'email';
  static const String phone = 'phone';
  static const String aadhar = 'aadhar';
  static const String location = 'location';
  static const String distance = 'distance';
  static const String status = 'status';
  static const String roleID = 'roleID';
  static const String refLink = 'refLink';
  static const String userDetails = 'user';

  static const String _selectedLanguageKey = 'selected_language';

  /// Initialize shared preferences
  static Future<void> initSharedPreference() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure _prefs is initialized before use
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
  //sk device id
  static Future<void> setDeviceId(String deviceId) async {

    final prefs = await _getPrefs();
    await prefs.setString("device_id", deviceId);
    print("device id set");
  }

  static Future<String?> getDeviceId() async {
    final prefs = await _getPrefs();
    return prefs.getString("device_id");
  }

  static Future<void> setSelectedLanguage(String language) async {
    final prefs = await _getPrefs();
    await prefs.setString(_selectedLanguageKey, language);
  }

  static Future<String?> getSelectedLanguage() async {
    final prefs = await _getPrefs();
    return prefs.getString(_selectedLanguageKey);
  }

  //sk end device id

  /// Clear all preferences
  static Future<void> clearPreference() async {
    const String _windowsDeviceKey = "windows_device_id";

    final prefs = await _getPrefs();
    // 1. Save the items you want to keep
    String? deviceId = prefs.getString("device_id");
    String? language = prefs.getString(_selectedLanguageKey);
    String? storedId = prefs.getString(_windowsDeviceKey);


    await prefs.clear();
    // stored id like device id

    if (storedId != null && storedId.isNotEmpty) {
      await prefs.setString(_windowsDeviceKey, storedId);
    }

    // 3. Restore the items you kept
    if (deviceId != null) {
      await prefs.setString("device_id", deviceId);
    }
    if (language != null) {
      await prefs.setString(_selectedLanguageKey, language);
    }

    print("Preferences cleared, but Device ID and Language preserved.");
  }

  /// User Details
  static Future<void> setUserDetails(String user) async {
    final prefs = await _getPrefs();
    await prefs.setString(userDetails, user);
  }

  static Future<String?> getUserDetails() async {
    final prefs = await _getPrefs();
    return prefs.getString(userDetails);
  }

  /// Auth Code
  static Future<void> setAuthCode(String authCodeNew) async {
    final prefs = await _getPrefs();
    await prefs.setString(authCode, authCodeNew);
  }

  static Future<String?> getAuthCode() async {
    final prefs = await _getPrefs();
    return prefs.getString(authCode);
  }

  /// User ID
  static Future<void> setUserID(String userIDNew) async {
    final prefs = await _getPrefs();
    await prefs.setString(userID, userIDNew);
  }

  static Future<String?> getUserID() async {
    final prefs = await _getPrefs();
    return prefs.getString(userID);
  }

  /// Name
  static Future<void> setName(String nameNew) async {
    final prefs = await _getPrefs();
    await prefs.setString(name, nameNew);
  }

  static Future<String?> getName() async {
    final prefs = await _getPrefs();
    return prefs.getString(name);
  }

  /// Email
  static Future<void> setEmail(String emailNew) async {
    final prefs = await _getPrefs();
    await prefs.setString(email, emailNew);
  }

  static Future<String?> getEmail() async {
    final prefs = await _getPrefs();
    return prefs.getString(email);
  }

  /// Phone
  static Future<void> setPhone(String phoneNew) async {
    final prefs = await _getPrefs();
    await prefs.setString(phone, phoneNew);
  }

  static Future<String?> getPhone() async {
    final prefs = await _getPrefs();
    return prefs.getString(phone);
  }

  /// Aadhar
  static Future<void> setAadhar(String aadharNew) async {
    final prefs = await _getPrefs();
    await prefs.setString(aadhar, aadharNew);
  }

  static Future<String?> getAadhar() async {
    final prefs = await _getPrefs();
    return prefs.getString(aadhar);
  }

  /// Location
  static Future<void> setLocation(String locationNew) async {
    final prefs = await _getPrefs();
    await prefs.setString(location, locationNew);
  }

  static Future<String?> getLocation() async {
    final prefs = await _getPrefs();
    return prefs.getString(location);
  }

  ///
}