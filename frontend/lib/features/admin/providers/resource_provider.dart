import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fims_frontend/core/network/api_endpoints.dart';
import 'package:fims_frontend/core/network/dio_client.dart';
import '../models/resource_config.dart';
import '../utils/json_helpers.dart';

typedef JsonMap = Map<String, dynamic>;

/// Dashboard
final dashboardDataProvider = FutureProvider.autoDispose
    .family<JsonMap, String?>((ref, financialYearId) async {
  final response = await DioClient().get(
    ApiEndpoints.dashboardStats,
    queryParameters: {
      if (financialYearId != null) 'financialYearId': financialYearId,
    },
  );

  if (response.statusCode == 200 && response.data['success'] == true) {
    return asMap(response.data['data']);
  }

  throw Exception(
    response.data['message'] ?? 'Unable to load dashboard',
  );
});

/// Financial Years
final financialYearsProvider =
    FutureProvider.autoDispose<List<JsonMap>>((ref) async {
  final response = await DioClient().get(
    ApiEndpoints.financialYears,
    queryParameters: {
      'page': 1,
      'limit': 100,
    },
  );

  return extractRows(response.data['data']);
});

/// Batches
final batchesProvider = FutureProvider.autoDispose<List<JsonMap>>((ref) async {
  final response = await DioClient().get(
    ApiEndpoints.batches,
    queryParameters: {
      'page': 1,
      'limit': 100,
    },
  );

  return extractRows(response.data['data']);
});

/// Farmer Search
final farmerSearchProvider =
    FutureProvider.family.autoDispose<List<JsonMap>, String>(
  (ref, search) async {
    if (search.trim().isEmpty) {
      return [];
    }

    final response = await DioClient().get(
      ApiEndpoints.farmers,
      queryParameters: {
        'search': search,
        'page': 1,
        'limit': 20,
      },
    );

    return extractRows(response.data['data']);
  },
);

/// Generic Resource Provider
final resourceProvider =
    FutureProvider.autoDispose.family<List<JsonMap>, ResourceConfig>(
  (ref, config) async {
    final response = await DioClient().get(
      config.endpoint,
      queryParameters: {
        'page': 1,
        'limit': 50,
      },
    );

    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(
        response.data['message'] ?? 'Unable to load ${config.title}',
      );
    }

    return extractRows(response.data['data']);
  },
);
