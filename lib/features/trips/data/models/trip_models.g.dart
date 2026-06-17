// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateTripRequest _$CreateTripRequestFromJson(Map<String, dynamic> json) =>
    CreateTripRequest(
      originLat: (json['origin_lat'] as num).toDouble(),
      originLng: (json['origin_lng'] as num).toDouble(),
      originAddress: json['origin_address'] as String,
      destinationLat: (json['destination_lat'] as num).toDouble(),
      destinationLng: (json['destination_lng'] as num).toDouble(),
      destinationAddress: json['destination_address'] as String,
      transportType: json['transport_type'] as String,
      estimatedFare: (json['estimated_fare'] as num).toInt(),
      passengerId: (json['passenger_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CreateTripRequestToJson(CreateTripRequest instance) =>
    <String, dynamic>{
      'origin_lat': instance.originLat,
      'origin_lng': instance.originLng,
      'origin_address': instance.originAddress,
      'destination_lat': instance.destinationLat,
      'destination_lng': instance.destinationLng,
      'destination_address': instance.destinationAddress,
      'transport_type': instance.transportType,
      'estimated_fare': instance.estimatedFare,
      'passenger_id': instance.passengerId,
    };

RouteComputeRequest _$RouteComputeRequestFromJson(Map<String, dynamic> json) =>
    RouteComputeRequest(
      originLat: (json['origin_lat'] as num).toDouble(),
      originLng: (json['origin_lng'] as num).toDouble(),
      destinationLat: (json['destination_lat'] as num).toDouble(),
      destinationLng: (json['destination_lng'] as num).toDouble(),
      transportType: json['transport_type'] as String,
    );

Map<String, dynamic> _$RouteComputeRequestToJson(
        RouteComputeRequest instance) =>
    <String, dynamic>{
      'origin_lat': instance.originLat,
      'origin_lng': instance.originLng,
      'destination_lat': instance.destinationLat,
      'destination_lng': instance.destinationLng,
      'transport_type': instance.transportType,
    };

RatingRequest _$RatingRequestFromJson(Map<String, dynamic> json) =>
    RatingRequest(
      rating: (json['rating'] as num).toInt(),
      review: json['review'] as String?,
      tip: (json['tip'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RatingRequestToJson(RatingRequest instance) =>
    <String, dynamic>{
      'rating': instance.rating,
      'review': instance.review,
      'tip': instance.tip,
    };

RouteComputeResponse _$RouteComputeResponseFromJson(
        Map<String, dynamic> json) =>
    RouteComputeResponse(
      success: json['success'] as bool,
      data: json['data'] == null
          ? null
          : RouteData.fromJson(json['data'] as Map<String, dynamic>),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$RouteComputeResponseToJson(
        RouteComputeResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'message': instance.message,
    };

RouteData _$RouteDataFromJson(Map<String, dynamic> json) => RouteData(
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toInt(),
      estimatedFare: (json['estimated_fare'] as num).toInt(),
      polyline: json['polyline'] as String?,
      waypoints: (json['waypoints'] as List<dynamic>?)
          ?.map((e) => WayPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RouteDataToJson(RouteData instance) => <String, dynamic>{
      'distance': instance.distance,
      'duration': instance.duration,
      'estimated_fare': instance.estimatedFare,
      'polyline': instance.polyline,
      'waypoints': instance.waypoints,
    };

WayPoint _$WayPointFromJson(Map<String, dynamic> json) => WayPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );

Map<String, dynamic> _$WayPointToJson(WayPoint instance) => <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
    };

CreateTripResponse _$CreateTripResponseFromJson(Map<String, dynamic> json) =>
    CreateTripResponse(
      success: json['success'] as bool,
      data: json['data'] == null
          ? null
          : TripData.fromJson(json['data'] as Map<String, dynamic>),
      message: json['message'] as String?,
      errors: (json['errors'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
    );

Map<String, dynamic> _$CreateTripResponseToJson(CreateTripResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'message': instance.message,
      'errors': instance.errors,
    };

TripData _$TripDataFromJson(Map<String, dynamic> json) => TripData(
      tripId: (json['trip_id'] as num).toInt(),
      passengerId: (json['passenger_id'] as num).toInt(),
      driverId: (json['driver_id'] as num?)?.toInt(),
      status: json['status'] as String,
      originLat: (json['origin_lat'] as num).toDouble(),
      originLng: (json['origin_lng'] as num).toDouble(),
      originAddress: json['origin_address'] as String,
      destinationLat: (json['destination_lat'] as num).toDouble(),
      destinationLng: (json['destination_lng'] as num).toDouble(),
      destinationAddress: json['destination_address'] as String,
      transportType: json['transport_type'] as String,
      estimatedFare: (json['estimated_fare'] as num).toInt(),
      actualFare: (json['actual_fare'] as num?)?.toInt(),
      distance: (json['distance'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toInt(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      completedAt: json['completed_at'] as String?,
      driver: json['driver'] == null
          ? null
          : DriverData.fromJson(json['driver'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TripDataToJson(TripData instance) => <String, dynamic>{
      'trip_id': instance.tripId,
      'passenger_id': instance.passengerId,
      'driver_id': instance.driverId,
      'status': instance.status,
      'origin_lat': instance.originLat,
      'origin_lng': instance.originLng,
      'origin_address': instance.originAddress,
      'destination_lat': instance.destinationLat,
      'destination_lng': instance.destinationLng,
      'destination_address': instance.destinationAddress,
      'transport_type': instance.transportType,
      'estimated_fare': instance.estimatedFare,
      'actual_fare': instance.actualFare,
      'distance': instance.distance,
      'duration': instance.duration,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'completed_at': instance.completedAt,
      'driver': instance.driver,
    };

DriverData _$DriverDataFromJson(Map<String, dynamic> json) => DriverData(
      driverId: (json['driver_id'] as num).toInt(),
      name: json['name'] as String,
      phone: json['phone'] as String,
      rating: (json['rating'] as num).toDouble(),
      avatar: json['avatar'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
    );

Map<String, dynamic> _$DriverDataToJson(DriverData instance) =>
    <String, dynamic>{
      'driver_id': instance.driverId,
      'name': instance.name,
      'phone': instance.phone,
      'rating': instance.rating,
      'avatar': instance.avatar,
      'vehicle_model': instance.vehicleModel,
      'vehicle_plate': instance.vehiclePlate,
    };

TripsListResponse _$TripsListResponseFromJson(Map<String, dynamic> json) =>
    TripsListResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => TripData.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$TripsListResponseToJson(TripsListResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'message': instance.message,
    };
