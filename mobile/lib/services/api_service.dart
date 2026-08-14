import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/medication.dart';
import '../models/health.dart';
import '../models/routine.dart';

class AuthResponse {
  final bool success;
  final String? errorMessage;
  AuthResponse({required this.success, this.errorMessage});
}

class ApiService {
  // Primary URL is localhost via ADB reverse (0ms USB speed). Fallback is Wi-Fi LAN IP.
  static String activeBaseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String usbUrl = 'http://127.0.0.1:8000/api/v1';
  static const String wifiUrl = 'http://192.168.1.6:8000/api/v1';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // Helper to execute request with automatic USB <-> Wi-Fi failover
  Future<http.Response> _requestWithFallback(
      Future<http.Response> Function(String base) requestFn) async {
    try {
      return await requestFn(activeBaseUrl).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Switch to alternative endpoint if primary failed
      final alternativeUrl = (activeBaseUrl == usbUrl) ? wifiUrl : usbUrl;
      try {
        final resp = await requestFn(alternativeUrl).timeout(const Duration(seconds: 4));
        activeBaseUrl = alternativeUrl; // Remember working endpoint
        return resp;
      } catch (e) {
        rethrow;
      }
    }
  }

  // ─── AUTH ──────────────────────────────────────────────────────────────────

  Future<AuthResponse> register(String email, String password, String name) async {
    try {
      final response = await _requestWithFallback((base) => http.post(
        Uri.parse('$base/users/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'name': name,
        }),
      ));

      if (response.statusCode == 200) {
        return AuthResponse(success: true);
      } else {
        try {
          final errorData = json.decode(response.body);
          final detail = errorData['detail'];
          if (detail is String) {
            return AuthResponse(success: false, errorMessage: detail);
          }
        } catch (_) {}
        return AuthResponse(
            success: false,
            errorMessage: 'Registration failed (${response.statusCode})');
      }
    } catch (e) {
      return AuthResponse(
          success: false,
          errorMessage:
              'Cannot reach server. Ensure backend is running.');
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _requestWithFallback((base) => http.post(
        Uri.parse('$base/login/access-token'),
        body: {
          'username': email,
          'password': password,
        },
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await setToken(data['access_token']);
        return AuthResponse(success: true);
      } else {
        try {
          final errorData = json.decode(response.body);
          final detail = errorData['detail'];
          if (detail is String) {
            return AuthResponse(success: false, errorMessage: detail);
          }
        } catch (_) {}
        return AuthResponse(
            success: false,
            errorMessage: 'Login failed (${response.statusCode})');
      }
    } catch (e) {
      return AuthResponse(
          success: false,
          errorMessage:
              'Cannot reach server. Ensure backend is running.');
    }
  }

  Future<User?> getMe() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      ));

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await _requestWithFallback((base) => http.put(
        Uri.parse('$base/users/me'),
        headers: _authHeaders(token),
        body: json.encode(data),
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── MEDICATIONS ───────────────────────────────────────────────────────────

  Future<List<Medication>> getMedications() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/medications/'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        Iterable l = json.decode(response.body);
        return List<Medication>.from(l.map((model) => Medication.fromJson(model)));
      }
    } catch (_) {}
    return [];
  }

  Future<bool> addMedication(String name, String dosage, String frequency,
      String startDate, String endDate, List<String> schedules) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await _requestWithFallback((base) => http.post(
        Uri.parse('$base/medications/'),
        headers: _authHeaders(token),
        body: json.encode({
          'name': name,
          'dosage': dosage,
          'frequency': frequency,
          'start_date': startDate,
          'end_date': endDate,
          'schedules': schedules,
        }),
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateMedication(int id, String name, String dosage,
      String frequency, String startDate, String endDate,
      List<String> schedules) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await _requestWithFallback((base) => http.put(
        Uri.parse('$base/medications/$id'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'name': name,
          'dosage': dosage,
          'frequency': frequency,
          'start_date': startDate,
          'end_date': endDate,
          'schedules': schedules,
        }),
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMedication(int id) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await _requestWithFallback((base) => http.delete(
        Uri.parse('$base/medications/$id'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getMedicationAdherence() async {
    final token = await getToken();
    if (token == null) return {'adherence_percentage': 0.0, 'total_scheduled': 0, 'taken': 0, 'missed': 0};
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/medications/adherence'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return {'adherence_percentage': 0.0, 'total_scheduled': 0, 'taken': 0, 'missed': 0};
  }

  Future<Map<String, dynamic>> getTodayMedications() async {
    final token = await getToken();
    if (token == null) return {'medications': [], 'total_scheduled': 0, 'completed': 0};
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/medications/today'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return {'medications': [], 'total_scheduled': 0, 'completed': 0};
  }

  Future<bool> recordMedicationEvent(
      int medicationId, String scheduledTime, String status) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await _requestWithFallback((base) => http.post(
        Uri.parse('$base/medications/record'),
        headers: _authHeaders(token),
        body: json.encode({
          'medication_id': medicationId,
          'scheduled_time': scheduledTime,
          'status': status,
        }),
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── HEALTH ────────────────────────────────────────────────────────────────

  Future<List<HealthMeasurement>> getHealthMeasurements() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/health/'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        Iterable l = json.decode(response.body);
        return List<HealthMeasurement>.from(
            l.map((model) => HealthMeasurement.fromJson(model)));
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> getHealthSummary() async {
    final token = await getToken();
    if (token == null) return {'status': 'No Data', 'metrics': {}};
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/health/summary'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return {'status': 'No Data', 'metrics': {}};
  }

  Future<Map<String, dynamic>> getHealthTrends({int days = 7}) async {
    final token = await getToken();
    if (token == null) return {'trends': {}};
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/health/trends?days=$days'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return {'trends': {}};
  }

  Future<Map<String, dynamic>> getHealthAnalytics({int days = 7}) async {
    final token = await getToken();
    if (token == null) return {'analytics': {}, 'anomalies': []};
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/health/analytics?days=$days'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return {'analytics': {}, 'anomalies': []};
  }

  Future<List<HealthMeasurement>> getHealthHistory({
    String? type,
    int? days,
    int limit = 50,
  }) async {
    final token = await getToken();
    if (token == null) return [];
    String urlParam = '/health/history?limit=$limit';
    if (type != null) urlParam += '&type=$type';
    if (days != null) urlParam += '&days=$days';

    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base$urlParam'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        Iterable l = json.decode(response.body);
        return List<HealthMeasurement>.from(
            l.map((model) => HealthMeasurement.fromJson(model)));
      }
    } catch (_) {}
    return [];
  }

  Future<bool> addHealthMeasurement(
      String type, double value, String unit, String source,
      {double? secondaryValue}) async {
    final token = await getToken();
    if (token == null) return false;
    final body = <String, dynamic>{
      'type': type,
      'value': value,
      'unit': unit,
      'source': source,
    };
    if (secondaryValue != null) {
      body['secondary_value'] = secondaryValue;
    }
    try {
      final response = await _requestWithFallback((base) => http.post(
        Uri.parse('$base/health/'),
        headers: _authHeaders(token),
        body: json.encode(body),
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── ALERTS ────────────────────────────────────────────────────────────────

  Future<List<AIAlert>> getAlerts() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/health/alerts'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        Iterable l = json.decode(response.body);
        return List<AIAlert>.from(l.map((model) => AIAlert.fromJson(model)));
      }
    } catch (_) {}
    return [];
  }

  // ─── AI ────────────────────────────────────────────────────────────────────

  Future<String> chatWithAI(String message) async {
    final token = await getToken();
    if (token == null) return "Please log in to chat with AI.";
    try {
      final response = await _requestWithFallback((base) => http.post(
        Uri.parse('$base/ai/chat'),
        headers: _authHeaders(token),
        body: json.encode({'message': message}),
      ));
      if (response.statusCode == 200) {
        return json.decode(response.body)['response'];
      }
    } catch (_) {}
    return "I'm having trouble connecting right now. Try again later!";
  }

  Future<Map<String, dynamic>> getAIInsights() async {
    final token = await getToken();
    if (token == null) {
      return {
        'summary': 'Please log in to view insights.',
        'insights': [],
        'recommendations': [],
        'severity': 'normal',
        'disclaimer': 'This is informational only.',
      };
    }
    try {
      final response = await _requestWithFallback((base) => http.post(
        Uri.parse('$base/ai/insights'),
        headers: _authHeaders(token),
      ));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return {
      'summary': 'Unable to generate insights at this time.',
      'insights': [],
      'recommendations': [],
      'severity': 'normal',
      'disclaimer': 'This is informational only.',
    };
  }

  // ─── ROUTINES ──────────────────────────────────────────────────────────────

  Future<Routine?> getRoutine() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final response = await _requestWithFallback((base) => http.get(
        Uri.parse('$base/routines/'),
        headers: {'Authorization': 'Bearer $token'},
      ));
      if (response.statusCode == 200) {
        return Routine.fromJson(json.decode(response.body));
      }
    } catch (_) {}
    return null;
  }

  Future<bool> saveRoutine(Map<String, String> routineData) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await _requestWithFallback((base) => http.post(
        Uri.parse('$base/routines/'),
        headers: _authHeaders(token),
        body: json.encode(routineData),
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
