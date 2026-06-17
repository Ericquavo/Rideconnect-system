import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// User model for storing user information
@JsonSerializable()
class User extends Equatable {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String userType; // 'passenger' or 'driver'
  final String? profilePictureUrl;
  final double? rating;
  final int? totalTrips;
  final bool? isAvailable; // For drivers
  final String? currentTripId; // For drivers
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.userType,
    this.profilePictureUrl,
    this.rating,
    this.totalTrips,
    this.isAvailable,
    this.currentTripId,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? userType,
    String? profilePictureUrl,
    double? rating,
    int? totalTrips,
    bool? isAvailable,
    String? currentTripId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      isAvailable: isAvailable ?? this.isAvailable,
      currentTripId: currentTripId ?? this.currentTripId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    userType,
    profilePictureUrl,
    rating,
    totalTrips,
    isAvailable,
    currentTripId,
    createdAt,
    updatedAt,
  ];
}

/// Authentication request model
@JsonSerializable()
class LoginRequest extends Equatable {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);

  @override
  List<Object?> get props => [email, password];
}

/// Authentication response model
@JsonSerializable()
class AuthResponse extends Equatable {
  final bool success;
  final User user;
  final String token;
  final String refreshToken;
  final String message;

  const AuthResponse({
    required this.success,
    required this.user,
    required this.token,
    required this.refreshToken,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  @override
  List<Object?> get props => [success, user, token, refreshToken, message];
}

/// Register request model
@JsonSerializable()
class RegisterRequest extends Equatable {
  final String name;
  final String email;
  final String phone;
  final String password;
  final String passwordConfirmation;
  final String userType; // 'passenger' or 'driver'

  const RegisterRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.userType,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);

  @override
  List<Object?> get props => [
    name,
    email,
    phone,
    password,
    passwordConfirmation,
    userType,
  ];
}

/// Token refresh request
@JsonSerializable()
class TokenRefreshRequest extends Equatable {
  final String refreshToken;

  const TokenRefreshRequest({required this.refreshToken});

  factory TokenRefreshRequest.fromJson(Map<String, dynamic> json) =>
      _$TokenRefreshRequestFromJson(json);
  Map<String, dynamic> toJson() => _$TokenRefreshRequestToJson(this);

  @override
  List<Object?> get props => [refreshToken];
}

/// Token refresh response
@JsonSerializable()
class TokenRefreshResponse extends Equatable {
  final bool success;
  final String token;
  final String refreshToken;

  const TokenRefreshResponse({
    required this.success,
    required this.token,
    required this.refreshToken,
  });

  factory TokenRefreshResponse.fromJson(Map<String, dynamic> json) =>
      _$TokenRefreshResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TokenRefreshResponseToJson(this);

  @override
  List<Object?> get props => [success, token, refreshToken];
}
