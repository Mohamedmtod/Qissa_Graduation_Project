import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PosRemoteService {
  final Dio _dio;
  final String _posBaseUrl;

  PosRemoteService({
    required String ordersBaseUrl,
    Dio? dio,
  })  : _posBaseUrl = ordersBaseUrl
            .replaceAll('orders-worker', 'pos-worker')
            .replaceAll('orders', 'pos')
            .trim()
            .replaceFirst(RegExp(r'/$'), ''),
        _dio = dio ?? Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken() ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> openCashSession({
    required double openingCash,
    String? notes,
  }) async {
    final response = await _dio.post(
      '$_posBaseUrl/pos/cash-sessions/open',
      data: {
        'openingCash': openingCash,
        if (notes != null) 'notes': notes,
      },
      options: Options(headers: await _headers()),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentCashSession() async {
    final response = await _dio.get(
      '$_posBaseUrl/pos/cash-sessions/current',
      options: Options(headers: await _headers()),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeCashSession({
    required String sessionId,
    required double actualCash,
    String? notes,
  }) async {
    final response = await _dio.post(
      '$_posBaseUrl/pos/cash-sessions/$sessionId/close',
      data: {
        'actualCash': actualCash,
        if (notes != null) 'notes': notes,
      },
      options: Options(headers: await _headers()),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchPosProducts() async {
    final response = await _dio.get(
      '$_posBaseUrl/pos/products/search',
      options: Options(headers: await _headers()),
    );
    final list = response.data as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createPosSale(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '$_posBaseUrl/pos/sales',
      data: payload,
      options: Options(headers: await _headers()),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRecipe(String productId) async {
    final response = await _dio.get(
      '$_posBaseUrl/pos/recipes/$productId',
      options: Options(headers: await _headers()),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final response = await _dio.get(
      '$_posBaseUrl/pos/sales',
      options: Options(headers: await _headers()),
    );
    final list = response.data as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getSaleDetails(String saleId) async {
    final response = await _dio.get(
      '$_posBaseUrl/pos/sales/$saleId',
      options: Options(headers: await _headers()),
    );
    return response.data as Map<String, dynamic>;
  }
}
