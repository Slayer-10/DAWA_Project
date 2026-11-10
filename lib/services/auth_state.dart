import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String role; // 'patient' or 'pharmacy_admin'
  final String? phone;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      phone: json['phone'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'created_at': createdAt,
      };
}

class PharmacyModel {
  final int id;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? openingHours;
  final bool isOpen;

  PharmacyModel({
    required this.id,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.phone,
    this.openingHours,
    this.isOpen = true,
  });

  factory PharmacyModel.fromJson(Map<String, dynamic> json) {
    return PharmacyModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      openingHours: json['opening_hours'] as String?,
      isOpen: json['is_open'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'phone': phone,
        'opening_hours': openingHours,
        'is_open': isOpen,
      };
}

class AuthState extends ChangeNotifier {
  AuthState._();
  static final AuthState instance = AuthState._();

  UserModel? _user;
  PharmacyModel? _pharmacy;
  String? _token;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  UserModel? get user => _user;
  PharmacyModel? get pharmacy => _pharmacy;
  String? get token => _token;
  String get role => _user?.role ?? 'patient';
  bool get isPharmacyAdmin => role == 'pharmacy_admin';
  bool get loading => _loading;
  String? get error => _error;
  bool get initialized => _initialized;
  bool get isAuthenticated => _token != null && _user != null;

  static const String _prefTokenKey = 'dawa_auth_token';
  static const String _prefUserKey = 'dawa_auth_user';
  static const String _prefPharmacyKey = 'dawa_auth_pharmacy';

  void Function()? onAuthRequired;

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_prefTokenKey);

      if (_token != null && _token!.isNotEmpty) {
        ApiService.instance.authToken = _token;
        ApiService.instance.onUnauthorized = logout;

        final cachedUser = prefs.getString(_prefUserKey);
        if (cachedUser != null) {
          try {
            _user = UserModel.fromJson(jsonDecode(cachedUser));
          } catch (_) {}
        }
        final cachedPh = prefs.getString(_prefPharmacyKey);
        if (cachedPh != null) {
          try {
            _pharmacy = PharmacyModel.fromJson(jsonDecode(cachedPh));
          } catch (_) {}
        }

        // Validate token against backend /auth/me
        final meData = await ApiService.instance.getMe();
        if (meData != null && meData['user'] != null) {
          _user = UserModel.fromJson(meData['user']);
          if (meData['pharmacy'] != null) {
            _pharmacy = PharmacyModel.fromJson(meData['pharmacy']);
          }
          await _saveToPrefs(prefs);
        } else {
          // Token is invalid/expired
          await logout();
        }
      }
    } catch (e) {
      debugPrint('AuthState init error: $e');
    } finally {
      _loading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs(SharedPreferences prefs) async {
    if (_token != null) await prefs.setString(_prefTokenKey, _token!);
    if (_user != null) await prefs.setString(_prefUserKey, jsonEncode(_user!.toJson()));
    if (_pharmacy != null) {
      await prefs.setString(_prefPharmacyKey, jsonEncode(_pharmacy!.toJson()));
    } else {
      await prefs.remove(_prefPharmacyKey);
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.instance.login(email.trim(), password);
      if (res['success'] == true) {
        _token = res['token'];
        _user = UserModel.fromJson(res['user']);
        if (res['pharmacy'] != null) {
          _pharmacy = PharmacyModel.fromJson(res['pharmacy']);
        } else {
          _pharmacy = null;
        }

        ApiService.instance.authToken = _token;
        ApiService.instance.onUnauthorized = logout;

        final prefs = await SharedPreferences.getInstance();
        await _saveToPrefs(prefs);

        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['error'] ?? 'Invalid credentials';
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login error: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    Map<String, dynamic>? pharmacy,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.instance.register(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        password: password,
        role: role,
        phone: phone?.trim(),
        pharmacy: pharmacy,
      );

      if (res['success'] == true) {
        _token = res['token'];
        _user = UserModel.fromJson(res['user']);
        if (res['pharmacy'] != null) {
          _pharmacy = PharmacyModel.fromJson(res['pharmacy']);
        } else {
          _pharmacy = null;
        }

        ApiService.instance.authToken = _token;
        ApiService.instance.onUnauthorized = logout;

        final prefs = await SharedPreferences.getInstance();
        await _saveToPrefs(prefs);

        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['error'] ?? 'Registration failed';
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Registration error: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _pharmacy = null;
    _error = null;
    ApiService.instance.authToken = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
      await prefs.remove(_prefUserKey);
      await prefs.remove(_prefPharmacyKey);
    } catch (_) {}

    notifyListeners();
    onAuthRequired?.call();
  }
}

