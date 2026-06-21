import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class AdminApi {
  AdminApi._();

  static final AdminApi instance = AdminApi._();
  final ApiClient _api = ApiClient();

  /// Fetch demand notifications for the admin dashboard map
  Future<List<Map<String, dynamic>>> getDemandNotifications({int limit = 50}) async {
    try {
      final response = await _api.get(
        ApiEndpoints.adminDemandNotifications,
        queryParameters: {'limit': limit},
      );
      
      final data = response.data;
      if (data != null && data['success'] == true) {
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      // Re-throw or handle based on app's standard
      rethrow;
    }
  }
}
