import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  Future<bool> checkAuth() async {
    final token = await _apiService.getToken();
    if (token == null || token.isEmpty) {
      _user = null;
      notifyListeners();
      return false;
    }

    try {
      _user = await _apiService.getMe().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Keep going if network is briefly slow
    }
    notifyListeners();
    return _user != null;
  }

  Future<AuthResponse> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final result = await _apiService.login(email, password);
    if (result.success) {
      _user = await _apiService.getMe();
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<AuthResponse> register(String email, String password, String name) async {
    _isLoading = true;
    notifyListeners();

    final result = await _apiService.register(email, password, name);

    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    notifyListeners();
  }
}
