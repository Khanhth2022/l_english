import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Tạo client dùng chung cho toàn app: base URL, timeout, interceptor JWT.
Dio createApiClient(TokenStore tokenStore) {
  final options = BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    // Chỉ 2xx là thành công; các mã khác đi vào onError để map sang ApiException.
    validateStatus: (status) =>
        status != null && status >= 200 && status < 300,
  );

  final dio = Dio(options);

  // Client riêng cho lời gọi làm mới token: không gắn interceptor để tránh
  // vòng lặp refresh lồng nhau.
  final refreshClient = Dio(options);

  dio.interceptors.add(
    AuthInterceptor(
      client: dio,
      refreshClient: refreshClient,
      tokenStore: tokenStore,
    ),
  );

  return dio;
}

/// Chuyển lỗi của Dio thành [ApiException] — tầng giao diện chỉ cần xử lý
/// một loại lỗi duy nhất.
ApiException mapDioException(DioException error) {
  final statusCode = error.response?.statusCode;
  if (statusCode != null) {
    return ApiException.fromStatus(statusCode, error.response?.data);
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ApiException.network(
        'Máy chủ phản hồi quá chậm. Kiểm tra backend rồi thử lại.',
      );
    case DioExceptionType.cancel:
      return ApiException.network('Yêu cầu đã bị huỷ.');
    case DioExceptionType.badCertificate:
    case DioExceptionType.connectionError:
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      return ApiException.network();
  }
}
