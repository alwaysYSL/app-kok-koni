import 'package:flutter/foundation.dart';

@immutable
final class SicaborLoginData {
  const SicaborLoginData({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    required this.type,
  });

  final String id;
  final String username;
  final String name;
  final String? email;
  final String type;

  factory SicaborLoginData.fromJson(Map<String, dynamic> json) {
    return SicaborLoginData(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email'] as String?,
      type: json['type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'email': email,
    'type': type,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborLoginData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          name == other.name &&
          email == other.email &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, username, name, email, type);
}

@immutable
final class SicaborLoginResponse {
  const SicaborLoginResponse({
    required this.status,
    required this.message,
    this.data,
    this.token,
  });

  final bool status;
  final String message;
  final SicaborLoginData? data;
  final String? token;

  factory SicaborLoginResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return SicaborLoginResponse(
      status: json['status'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      data: rawData is Map<String, dynamic>
          ? SicaborLoginData.fromJson(rawData)
          : null,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'data': data?.toJson(),
    'token': token,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborLoginResponse &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          message == other.message &&
          data == other.data &&
          token == other.token;

  @override
  int get hashCode => Object.hash(status, message, data, token);
}
