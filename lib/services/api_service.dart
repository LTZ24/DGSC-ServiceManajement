import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _sessionCookie;
  static String? _csrfToken;

  /// Get stored session cookie
  static Future<String?> getSessionCookie() async {
    if (_sessionCookie != null) return _sessionCookie;
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('session_cookie');
    return _sessionCookie;
  }

  /// Save session cookie
  static Future<void> setSessionCookie(String cookie) async {
    _sessionCookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', cookie);
  }

  /// Clear session
  static Future<void> clearSession() async {
    _sessionCookie = null;
    _csrfToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    await prefs.remove('csrf_token');
    await prefs.remove('user_data');
  }

  /// Extract and save session cookie from response headers
  static void _extractCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      // Extract PHPSESSID
      final match = RegExp(r'PHPSESSID=([^;]+)').firstMatch(setCookie);
      if (match != null) {
        setSessionCookie('PHPSESSID=${match.group(1)}');
      }
    }
  }

  /// Build headers with session cookie and CSRF token
  static Future<Map<String, String>> _buildHeaders({
    bool isJson = true,
    bool includeCsrf = false,
  }) async {
    final headers = <String, String>{};

    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    headers['Accept'] = 'application/json';

    final cookie = await getSessionCookie();
    if (cookie != null) {
      headers['Cookie'] = cookie;
    }

    if (includeCsrf && _csrfToken != null) {
      headers['X-CSRF-Token'] = _csrfToken!;
    }

    return headers;
  }

  /// GET request
  static Future<ApiResponse> get(String url,
      {Map<String, String>? queryParams}) async {
    try {
      Uri uri = Uri.parse(url);
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final headers = await _buildHeaders();
      final response = await http.get(uri, headers: headers);
      _extractCookie(response);

      // Try to extract CSRF token from response
      final body = _parseBody(response);
      if (body is Map && body.containsKey('csrf_token')) {
        _csrfToken = body['csrf_token'];
      }

      return ApiResponse(
        statusCode: response.statusCode,
        data: body,
        success: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        data: {'error': e.toString()},
        success: false,
      );
    }
  }

  /// POST request
  static Future<ApiResponse> post(String url,
      {Map<String, dynamic>? body}) async {
    try {
      final headers = await _buildHeaders(includeCsrf: true);
      final bodyWithCsrf = body ?? {};
      if (_csrfToken != null) {
        bodyWithCsrf['csrf_token'] = _csrfToken;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(bodyWithCsrf),
      );
      _extractCookie(response);

      final responseBody = _parseBody(response);
      return ApiResponse(
        statusCode: response.statusCode,
        data: responseBody,
        success: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        data: {'error': e.toString()},
        success: false,
      );
    }
  }

  /// PUT request
  static Future<ApiResponse> put(String url,
      {Map<String, dynamic>? body}) async {
    try {
      final headers = await _buildHeaders(includeCsrf: true);
      final bodyWithCsrf = body ?? {};
      if (_csrfToken != null) {
        bodyWithCsrf['csrf_token'] = _csrfToken;
      }

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(bodyWithCsrf),
      );
      _extractCookie(response);

      final responseBody = _parseBody(response);
      return ApiResponse(
        statusCode: response.statusCode,
        data: responseBody,
        success: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        data: {'error': e.toString()},
        success: false,
      );
    }
  }

  /// DELETE request
  static Future<ApiResponse> delete(String url,
      {Map<String, dynamic>? body}) async {
    try {
      final headers = await _buildHeaders(includeCsrf: true);
      final bodyWithCsrf = body ?? {};
      if (_csrfToken != null) {
        bodyWithCsrf['csrf_token'] = _csrfToken;
      }

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(bodyWithCsrf),
      );
      _extractCookie(response);

      final responseBody = _parseBody(response);
      return ApiResponse(
        statusCode: response.statusCode,
        data: responseBody,
        success: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        data: {'error': e.toString()},
        success: false,
      );
    }
  }

  /// Multipart POST (for file upload)
  static Future<ApiResponse> uploadFile(
    String url,
    String filePath, {
    String fieldName = 'receipt',
    Map<String, String>? fields,
  }) async {
    try {
      final cookie = await getSessionCookie();
      final request = http.MultipartRequest('POST', Uri.parse(url));

      if (cookie != null) {
        request.headers['Cookie'] = cookie;
      }
      if (_csrfToken != null) {
        request.fields['csrf_token'] = _csrfToken!;
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }

      request.files
          .add(await http.MultipartFile.fromPath(fieldName, filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _extractCookie(response);

      return ApiResponse(
        statusCode: response.statusCode,
        data: _parseBody(response),
        success:
            response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        data: {'error': e.toString()},
        success: false,
      );
    }
  }

  /// Parse response body
  static dynamic _parseBody(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'raw': response.body};
    }
  }
}

class ApiResponse {
  final int statusCode;
  final dynamic data;
  final bool success;

  ApiResponse({
    required this.statusCode,
    required this.data,
    required this.success,
  });

  String get message {
    if (data is Map) {
      return data['message'] ?? data['error'] ?? 'Unknown error';
    }
    return 'Unknown error';
  }

  List<dynamic> get dataList {
    if (data is Map && data['data'] is List) {
      return data['data'];
    }
    if (data is List) return data;
    return [];
  }

  Map<String, dynamic> get dataMap {
    if (data is Map) {
      if (data['data'] is Map) return Map<String, dynamic>.from(data['data']);
      return Map<String, dynamic>.from(data);
    }
    return {};
  }
}
