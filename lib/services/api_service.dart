import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // Android emulator uses 10.0.2.2, Web/Desktop/iOS uses 127.0.0.1
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  String baseUrl = defaultBaseUrl;

  String? authToken;
  VoidCallback? onUnauthorized;

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (authToken != null && authToken!.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

  void _checkStatus(int statusCode) {
    if (statusCode == 401) {
      onUnauthorized?.call();
    }
  }

  Uri _uri(String endpoint, [Map<String, String>? queryParams]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$baseUrl$cleanEndpoint';
    return Uri.parse(fullUrl).replace(queryParameters: queryParams);
  }

  // Auth Methods
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        _uri('/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 12));

      _checkStatus(res.statusCode);
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        return {
          'success': true,
          'token': body['token'],
          'user': body['user'],
          'pharmacy': body['pharmacy'],
        };
      }
      return {'success': false, 'error': body['detail'] ?? 'Invalid credentials'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    Map<String, dynamic>? pharmacy,
  }) async {
    try {
      final payload = {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (pharmacy != null) 'pharmacy': pharmacy,
      };
      final res = await http.post(
        _uri('/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 12));

      _checkStatus(res.statusCode);
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        return {
          'success': true,
          'token': body['token'],
          'user': body['user'],
          'pharmacy': body['pharmacy'],
        };
      }
      return {'success': false, 'error': body['detail'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final res = await http.get(
        _uri('/auth/me'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 10));

      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Stock Management (Admin)
  Future<List<Map<String, dynamic>>> getAdminStock() async {
    try {
      final res = await http.get(_uri('/admin/stock'), headers: authHeaders);
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> createAdminStock({
    required String medicineName,
    String? strength,
    String? form,
    required double price,
    required int quantity,
  }) async {
    try {
      final res = await http.post(
        _uri('/admin/stock'),
        headers: authHeaders,
        body: jsonEncode({
          'medicine_name': medicineName,
          'strength': strength,
          'form': form,
          'price': price,
          'quantity': quantity,
        }),
      );
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateAdminStock(
    int id, {
    String? medicineName,
    String? strength,
    String? form,
    double? price,
    int? quantity,
  }) async {
    try {
      final res = await http.put(
        _uri('/admin/stock/$id'),
        headers: authHeaders,
        body: jsonEncode({
          if (medicineName != null) 'medicine_name': medicineName,
          if (strength != null) 'strength': strength,
          if (form != null) 'form': form,
          if (price != null) 'price': price,
          if (quantity != null) 'quantity': quantity,
        }),
      );
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteAdminStock(int id) async {
    try {
      final res = await http.delete(_uri('/admin/stock/$id'), headers: authHeaders);
      _checkStatus(res.statusCode);
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Admin Orders
  Future<List<Map<String, dynamic>>> getAdminOrders({String? status, String? statusFilter}) async {
    try {
      final st = status ?? statusFilter;
      final q = st != null ? {'status': st} : null;
      final res = await http.get(_uri('/admin/orders', q), headers: authHeaders).timeout(const Duration(seconds: 10));
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching admin orders: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> updateAdminOrderStatus(
    int orderId,
    String newStatus, {
    String? reason,
    String? notes,
  }) async {
    try {
      final res = await http.patch(
        _uri('/admin/orders/$orderId/status'),
        headers: authHeaders,
        body: jsonEncode({
          'status': newStatus,
          if (reason != null) 'reason': reason,
          if (notes != null) 'notes': notes,
        }),
      );
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updatePharmacyProfile({
    String? name,
    String? address,
    double? lat,
    double? lng,
    String? phone,
    String? openingHours,
    bool? isOpen,
  }) async {
    try {
      final res = await http.put(
        _uri('/admin/pharmacy'),
        headers: authHeaders,
        body: jsonEncode({
          if (name != null) 'name': name,
          if (address != null) 'address': address,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (phone != null) 'phone': phone,
          if (openingHours != null) 'opening_hours': openingHours,
          if (isOpen != null) 'is_open': isOpen,
        }),
      );
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Patient Orders
  Future<Map<String, dynamic>?> createPatientOrder({
    required int pharmacyId,
    required List<Map<String, dynamic>> items,
    String? prescriptionRef,
    String fulfillmentType = 'pickup',
    String? deliveryAddress,
  }) async {
    try {
      final res = await http.post(
        _uri('/orders'),
        headers: authHeaders,
        body: jsonEncode({
          'pharmacy_id': pharmacyId,
          'items': items,
          if (prescriptionRef != null) 'prescription_ref': prescriptionRef,
          'fulfillment_type': fulfillmentType,
          if (deliveryAddress != null) 'delivery_address': deliveryAddress,
        }),
      );
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMyOrders() async {
    try {
      final res = await http.get(_uri('/orders/mine'), headers: authHeaders);
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> cancelPatientOrder(int orderId) async {
    try {
      final res = await http.patch(_uri('/orders/$orderId/cancel'), headers: authHeaders);
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Registered Nearby & Live Medicines
  Future<List<Map<String, dynamic>>> getRegisteredNearbyPharmacies(
      double lat, double lng, {int radius = 5000}) async {
    try {
      final res = await http.get(_uri('/pharmacies/registered/nearby', {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
      }));
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMedicinesNearby({
    required double lat,
    required double lng,
    int radius = 5000,
    String? q,
  }) async {
    try {
      final params = {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
        if (q != null && q.isNotEmpty) 'q': q,
      };
      final res = await http.get(_uri('/medicines/nearby', params));
      _checkStatus(res.statusCode);
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 1. Location & Nearby Pharmacies
  Future<List<Map<String, dynamic>>> getRealNearbyPharmacies(
      double lat, double lng, {int radius = 5000}) async {
    try {
      final res = await http.get(_uri('/pharmacies/nearby', {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
      })).timeout(const Duration(seconds: 14));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting real nearby pharmacies: $e');
      return [];
    }
  }

  // Geocoding Proxy
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    try {
      final res = await http.get(_uri('/geocode/search', {
        'q': query,
      })).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching places: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> reverseGeocode(double lat, double lng) async {
    try {
      final res = await http.get(_uri('/geocode/reverse', {
        'lat': lat.toString(),
        'lng': lng.toString(),
      })).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyPharmacies(
      double lat, double lon) async {
    try {
      final res = await http.get(_uri('/location/nearby-pharmacies', {
        'lat': lat.toString(),
        'lon': lon.toString(),
      })).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Server returned ${res.statusCode}: ${res.body}');
    } catch (e) {
      debugPrint('Error getting nearby pharmacies: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllPharmacies() async {
    try {
      final res = await http
          .get(_uri('/location/pharmacies'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Server returned ${res.statusCode}');
    } catch (e) {
      debugPrint('Error fetching pharmacies: $e');
      rethrow;
    }
  }

  // 2. Medicines Catalog
  Future<List<Map<String, dynamic>>> searchMedicines(
      {String? query, String? category}) async {
    try {
      final params = <String, String>{};
      if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
      if (category != null && category.trim().isNotEmpty) {
        params['category'] = category.trim();
      }

      final res = await http
          .get(_uri('/medicines', params.isNotEmpty ? params : null))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Server returned ${res.statusCode}');
    } catch (e) {
      debugPrint('Error searching medicines: $e');
      rethrow;
    }
  }

  // 3. Prescription OCR Upload
  Future<Map<String, dynamic>> uploadPrescription(
      Uint8List imageBytes, String filename,
      {int patientId = 1}) async {
    try {
      final uri = _uri('/ocr/upload-prescription');
      final request = http.MultipartRequest('POST', uri)
        ..fields['patient_id'] = patientId.toString()
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
        ));

      final streamedRes =
          await request.send().timeout(const Duration(seconds: 120));
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      
      try {
        final errJson = jsonDecode(utf8.decode(res.bodyBytes));
        if (errJson is Map && errJson.containsKey('detail')) {
          throw Exception(errJson['detail']);
        }
      } catch (e) {
        if (e is! FormatException) rethrow;
      }
      throw Exception('Upload failed (${res.statusCode}): ${res.body}');
    } catch (e) {
      debugPrint('Error uploading prescription: $e');
      rethrow;
    }
  }

  // 4. Confirm Medicine Review & Match Pharmacies
  Future<Map<String, dynamic>> confirmPrescriptionAndMatch({
    required int prescriptionId,
    required List<Map<String, dynamic>> items,
    int patientId = 1,
    double? lat,
    double? lon,
  }) async {
    try {
      final body = jsonEncode({
        'prescription_id': prescriptionId,
        'patient_id': patientId,
        'items': items,
        'patient_latitude': lat,
        'patient_longitude': lon,
      });

      final res = await http
          .post(
            _uri('/prescriptions/confirm-and-match'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Confirmation failed: ${res.body}');
    } catch (e) {
      debugPrint('Error confirming prescription: $e');
      rethrow;
    }
  }

  // 5. Generate Invoice
  Future<Map<String, dynamic>> generateInvoice({
    required int prescriptionId,
    required int pharmacyId,
    bool delivery = false,
  }) async {
    try {
      final uri = _uri('/invoices/generate', {
        'prescription_id': prescriptionId.toString(),
        'pharmacy_id': pharmacyId.toString(),
        'delivery': delivery.toString(),
      });

      final res = await http.post(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Invoice generation failed: ${res.body}');
    } catch (e) {
      debugPrint('Error generating invoice: $e');
      rethrow;
    }
  }

  // 6. Invoice Decision (Approve / Reject)
  Future<Map<String, dynamic>> submitInvoiceDecision(
    int invoiceId, {
    required bool approved,
    String? reason,
  }) async {
    try {
      final body = jsonEncode({
        'approved': approved,
        'rejection_reason': reason,
      });

      final res = await http
          .post(
            _uri('/invoices/$invoiceId/decision'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Decision failed: ${res.body}');
    } catch (e) {
      debugPrint('Error submitting invoice decision: $e');
      rethrow;
    }
  }

  // 7. Create Order (Pickup or Delivery)
  Future<Map<String, dynamic>> createOrder({
    required int invoiceId,
    required String fulfillmentType,
    int patientId = 1,
    String? deliveryAddress,
    double? lat,
    double? lon,
    String? paymentMethod,
  }) async {
    try {
      final body = jsonEncode({
        'invoice_id': invoiceId,
        'patient_id': patientId,
        'fulfillment_type': fulfillmentType,
        'delivery_address': deliveryAddress,
        'delivery_latitude': lat,
        'delivery_longitude': lon,
        'payment_method': paymentMethod ??
            'Pay at Pickup / Cash on Delivery',
      });

      final res = await http
          .post(
            _uri('/orders/create'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Order creation failed: ${res.body}');
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  // 8. Order Tracking & History
  Future<List<Map<String, dynamic>>> getOrders() async {
    try {
      final res = await http
          .get(_uri('/orders'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Failed to fetch orders: ${res.statusCode}');
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOrderDetails(int orderId) async {
    try {
      final res = await http
          .get(_uri('/orders/$orderId'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Order details error: ${res.statusCode}');
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      rethrow;
    }
  }

  // 9. Pharmacist Admin API
  // (getAdminOrders is declared above with authHeaders support)

  Future<Map<String, dynamic>> verifyOrder(
    int orderId, {
    required String action, // "VERIFY" or "REJECT"
    String? notes,
    String? rejectionReason,
  }) async {
    try {
      final body = jsonEncode({
        'action': action,
        'notes': notes,
        'rejection_reason': rejectionReason,
      });

      final res = await http
          .post(
            _uri('/admin/orders/$orderId/verify'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Verification failed: ${res.body}');
    } catch (e) {
      debugPrint('Error verifying order: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    int orderId, {
    required String status,
    String? notes,
  }) async {
    try {
      final body = jsonEncode({
        'status': status,
        'notes': notes,
      });

      final res = await http
          .post(
            _uri('/admin/orders/$orderId/update-status'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw Exception('Status update failed: ${res.body}');
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }
}
