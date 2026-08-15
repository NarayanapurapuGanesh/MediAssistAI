import 'package:flutter/foundation.dart';

class AppConfig {
  // Production URL
  static const String _prodBaseUrl = 'https://mediassistai-backend.onrender.com/api/v1';
  
  // Local Development URLs
  // 10.0.2.2 is the special alias for Android Emulator to access host localhost
  static const String _devUsbUrl = 'http://10.0.2.2:8000/api/v1';
  static const String _devWifiUrl = 'http://192.168.1.6:8000/api/v1';

  static String get baseUrl => kReleaseMode ? _prodBaseUrl : _devUsbUrl;
  
  static String get fallbackUrl => kReleaseMode ? _prodBaseUrl : _devWifiUrl;

  static bool get isProduction => kReleaseMode;
}
