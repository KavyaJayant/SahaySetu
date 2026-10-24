import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'SAHAYSETU_API_BASE_URL',
  );
  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000'
      : 'http://127.0.0.1:8000';

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

  static Future<Map<String, dynamic>> getCurrentUser({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw ApiException(
        response.statusCode,
        detail?.toString() ?? 'Unable to validate login',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('User response is invalid');
    }
    return decoded;
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

  static Future<List<Map<String, dynamic>>> getMyComplaints({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/complaints/my'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw ApiException(
        response.statusCode,
        detail?.toString() ?? 'Unable to load complaints',
      );
    }
    if (decoded is! List) {
      throw const FormatException('Complaint history response is not a list');
    }

    return decoded
        .map((record) {
          if (record is! Map<String, dynamic>) {
            throw const FormatException(
              'Complaint history contains an invalid record',
            );
          }
          return record;
        })
        .toList(growable: false);
  }

  static Future<Map<String, dynamic>> getComplaint({
    required String token,
    required String complaintId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/complaints/${Uri.encodeComponent(complaintId)}',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw ApiException(response.statusCode, detail ?? 'Unable to load complaint details');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Complaint detail response is invalid');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> submitCitizenVerification({
    required String token,
    required String complaintId,
    required String result,
    String? feedback,
    Uint8List? photoBytes,
    String? photoFileName,
    String? photoContentType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/complaints/${Uri.encodeComponent(complaintId)}/verification',
      ),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['result'] = result;
    if (feedback != null && feedback.trim().isNotEmpty) {
      request.fields['feedback'] = feedback.trim();
    }
    if (photoBytes != null) {
      if (photoContentType == null || photoFileName == null) {
        throw const FormatException('Selected photo type is not supported');
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'evidence',
          photoBytes,
          filename: photoFileName,
          contentType: MediaType.parse(photoContentType),
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw ApiException(
        response.statusCode,
        detail ?? 'Unable to save your verification response',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Verification response is invalid');
    }
    return decoded;
  }

  static Uri citizenVerificationEvidenceUri(String complaintId) => Uri.parse(
    '$baseUrl/complaints/${Uri.encodeComponent(complaintId)}/verification/evidence',
  );

  static Future<List<Map<String, dynamic>>> getWorkerComplaints({
    required String token,
  }) => _getList(
    '/worker/complaints',
    token: token,
    fallbackError: 'Unable to load assigned tasks',
  );

  static Future<Map<String, dynamic>> updateWorkerComplaintStatus({
    required String token,
    required String complaintId,
    required String status,
  }) => _put(
    '/worker/complaints/${Uri.encodeComponent(complaintId)}/status',
    token: token,
    body: {'status': status},
    fallbackError: 'Unable to update task status',
  );

  static Future<List<Map<String, dynamic>>> _getList(
    String path, {
    required String token,
    required String fallbackError,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw ApiException(response.statusCode, detail ?? fallbackError);
    }
    if (decoded is! List) {
      throw const FormatException('Server response is not a list');
    }
    return decoded
        .map((record) {
          if (record is! Map<String, dynamic>) {
            throw const FormatException(
              'Server response contains an invalid record',
            );
          }
          return record;
        })
        .toList(growable: false);
  }

  static Future<Map<String, dynamic>> _put(
    String path, {
    required String token,
    required Map<String, dynamic> body,
    required String fallbackError,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw ApiException(response.statusCode, detail ?? fallbackError);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Server response is invalid');
    }
    return decoded;
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

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw ApiException(
        response.statusCode,
        detail?.toString() ?? fallbackError,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Server response is invalid');
    }
    return decoded;
  }
}
