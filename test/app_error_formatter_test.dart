import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/shared/utils/app_error_formatter.dart';

void main() {
  test('formats 429 errors using Retry-After header', () {
    final requestOptions = RequestOptions(path: '/api/v1/auth/login');
    final response = Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: 429,
      headers: Headers.fromMap({
        'retry-after': ['45'],
      }),
      data: {
        'code': 'RATE_LIMIT_EXCEEDED',
        'message': 'Demasiados intentos en autenticacion.',
      },
    );
    final error = DioException(
      requestOptions: requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );

    expect(
      AppErrorFormatter.readable(error, (key, {params}) => key),
      'Demasiados intentos. Espera 45s e intenta nuevamente.',
    );
  });

  test('formats Firebase no-app errors with guidance', () {
    final error = Exception(
      '[core/no-app] No Firebase App \'[DEFAULT]\' has been created - call Firebase.initializeApp()',
    );

    expect(
      AppErrorFormatter.readable(error, (key, {params}) => key),
      'Firebase no se inicializo en esta app. Revisa las variables FIREBASE_* y vuelve a ejecutar el build.',
    );
  });
}
