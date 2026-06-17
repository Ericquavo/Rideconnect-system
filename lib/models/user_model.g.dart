// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      userType: json['userType'] as String,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      totalTrips: (json['totalTrips'] as num?)?.toInt(),
      isAvailable: json['isAvailable'] as bool?,
      currentTripId: json['currentTripId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'userType': instance.userType,
      'profilePictureUrl': instance.profilePictureUrl,
      'rating': instance.rating,
      'totalTrips': instance.totalTrips,
      'isAvailable': instance.isAvailable,
      'currentTripId': instance.currentTripId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
      email: json['email'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
    };

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
      success: json['success'] as bool,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'user': instance.user,
      'token': instance.token,
      'refreshToken': instance.refreshToken,
      'message': instance.message,
    };

RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    RegisterRequest(
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      password: json['password'] as String,
      passwordConfirmation: json['passwordConfirmation'] as String,
      userType: json['userType'] as String,
    );

Map<String, dynamic> _$RegisterRequestToJson(RegisterRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'password': instance.password,
      'passwordConfirmation': instance.passwordConfirmation,
      'userType': instance.userType,
    };

TokenRefreshRequest _$TokenRefreshRequestFromJson(Map<String, dynamic> json) =>
    TokenRefreshRequest(
      refreshToken: json['refreshToken'] as String,
    );

Map<String, dynamic> _$TokenRefreshRequestToJson(
        TokenRefreshRequest instance) =>
    <String, dynamic>{
      'refreshToken': instance.refreshToken,
    };

TokenRefreshResponse _$TokenRefreshResponseFromJson(
        Map<String, dynamic> json) =>
    TokenRefreshResponse(
      success: json['success'] as bool,
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
    );

Map<String, dynamic> _$TokenRefreshResponseToJson(
        TokenRefreshResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'token': instance.token,
      'refreshToken': instance.refreshToken,
    };
