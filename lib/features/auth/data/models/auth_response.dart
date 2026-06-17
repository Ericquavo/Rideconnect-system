import 'package:json_annotation/json_annotation.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class AuthResponse {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'data')
  final AuthData? data;

  @JsonKey(name: 'message')
  final String? message;

  @JsonKey(name: 'errors')
  final Map<String, List<String>>? errors;

  AuthResponse({
    required this.success,
    this.data,
    this.message,
    this.errors,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class AuthData {
  @JsonKey(name: 'token')
  final String token;

  @JsonKey(name: 'user')
  final User user;

  AuthData({
    required this.token,
    required this.user,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) =>
      _$AuthDataFromJson(json);

  Map<String, dynamic> toJson() => _$AuthDataToJson(this);
}

@JsonSerializable()
class User {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'phone')
  final String phone;

  @JsonKey(name: 'role')
  final String role;

  @JsonKey(name: 'email')
  final String? email;

  @JsonKey(name: 'avatar')
  final String? avatar;

  @JsonKey(name: 'rating')
  final double? rating;

  User({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.avatar,
    this.rating,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  bool get isPassenger => role == 'PASSENGER';
  bool get isDriver => role == 'DRIVER';
}

@JsonSerializable()
class LoginRequest {
  @JsonKey(name: 'phone')
  final String phone;

  @JsonKey(name: 'password')
  final String password;

  @JsonKey(name: 'device_name')
  final String deviceName;

  @JsonKey(name: 'fcm_token')
  final String fcmToken;

  LoginRequest({
    required this.phone,
    required this.password,
    required this.deviceName,
    required this.fcmToken,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class ErrorResponse {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'message')
  final String message;

  @JsonKey(name: 'errors')
  final Map<String, List<String>> errors;

  ErrorResponse({
    required this.success,
    required this.message,
    required this.errors,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);

  /// Get comma-separated error messages
  String get errorMessages {
    final allErrors = errors.values.expand((list) => list).toList();
    return allErrors.join(', ');
  }

  /// Get errors for specific field
  List<String> getFieldErrors(String fieldName) =>
      errors[fieldName] ?? [];
}
