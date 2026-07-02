import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class DioClient {
  late final Dio _dio;

  DioClient({Ref? ref, String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.defaultBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 500,
      ),
    );

    if (kIsWeb) {
      (_dio.httpClientAdapter as dynamic).withCredentials = true;
    }

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> uploadFile(
    String path, {
    String? filePath,
    Uint8List? bytes,
    String? fileName,
    String fileFieldName = 'file',
    Map<String, dynamic>? extraFields,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    final multipartFile = bytes != null
        ? MultipartFile.fromBytes(bytes, filename: fileName)
        : filePath != null
            ? await MultipartFile.fromFile(filePath, filename: fileName)
            : throw ArgumentError('Either filePath or bytes must be provided');

    final formData = FormData.fromMap({
      fileFieldName: multipartFile,
      if (extraFields != null) ...extraFields,
    });

    return _dio.post(
      path,
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }

  // Download file
  Future<Response> downloadFile(
    String url,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return _dio.download(
      url,
      savePath,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

// Auth interceptor - sends browser session cookies with API requests.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Enable credentials (cookies) for all requests
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If 401 Unauthorized, redirect to login
    if (err.response?.statusCode == 401) {
      // TODO: Trigger session expiry redirect
      // Use a global event bus or provider to handle session expiry
    }
    handler.next(err);
  }
}

// Logging interceptor
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // debugPrint('--> ${options.method} ${options.path}');
    // debugPrint('Headers: ${options.headers}');
    // if (options.data != null) {
    //   debugPrint('Body: ${options.data}');
    // }
    // debugPrint('<-- END ${options.method}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    // debugPrint('<-- ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    // debugPrint('ERROR: ${err.message}');
    handler.next(err);
  }
}

// Error interceptor
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        err = DioException(
          requestOptions: err.requestOptions,
          message:
              'Connection timed out. Please check your internet connection.',
          type: err.type,
          error: err.error,
        );
        break;
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final message =
            err.response?.data?['message'] ?? _getErrorMessage(statusCode);
        err = DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          message: message,
          type: err.type,
          error: err.error,
        );
        break;
      case DioExceptionType.cancel:
        // Request cancelled - no need to show error
        break;
      default:
        err = DioException(
          requestOptions: err.requestOptions,
          message: 'Network error occurred. Please try again.',
          type: err.type,
          error: err.error,
        );
    }
    handler.next(err);
  }

  String _getErrorMessage(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request. Please check your input.';
      case 401:
        return 'Session expired. Please login again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'Conflict. The resource already exists.';
      case 422:
        return 'Validation failed. Please check your input.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}

// Provider for DioClient
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(ref: ref);
});

