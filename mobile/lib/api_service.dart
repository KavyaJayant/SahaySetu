import 'dart:convert';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // For Android phone testing, replace this with your laptop's
  // IPv4 address, e.g. http://192.168.1.5:8000
  static const String baseUrl = 'http://192.168.1.35:8000';

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
      fallbackError: 'Registration failed',
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _post(
      '/auth/login',
      body: {'email': email, 'password': password},
      fallbackError: 'Login failed',
    );
  }

  // ---------------------------------------------------------------------------
  // Complaints
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createComplaint({
    required String token,
    required String description,
    required String category,
    required String severity,
    required double latitude,
    required double longitude,
    String? photoUrl,
    String? audioUrl,
  }) {
    return _post(
      '/complaints',
      token: token,
      body: {
        'description': description,
        'category': category,
        'severity': severity,
        'latitude': latitude,
        'longitude': longitude,
        'photo_url': photoUrl,
        'audio_url': audioUrl,
      },
      fallbackError: 'Complaint submission failed',
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helper
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    required String fallbackError,
    String? token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['detail'] ?? fallbackError);
    }

    return data;
  }
}
