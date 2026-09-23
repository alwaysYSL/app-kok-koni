import 'package:dio/dio.dart';

import 'api_exceptions.dart';

void requireJsonContentType(Headers headers) {
  final contentType = headers.value(Headers.contentTypeHeader)?.toLowerCase();
  if (contentType == null ||
      !(contentType.contains('application/json') ||
          contentType.contains('+json'))) {
    throw const ApiConfigurationException();
  }
}

bool isJsonContentType(Headers headers) {
  final contentType = headers.value(Headers.contentTypeHeader)?.toLowerCase();
  return contentType != null &&
      (contentType.contains('application/json') ||
          contentType.contains('+json'));
}
