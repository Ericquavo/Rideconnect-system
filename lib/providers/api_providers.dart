import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/dio_config.dart';
import '../services/driver_matching_service.dart';
import '../services/trip_service.dart';

final dioProvider = Provider<Dio>((ref) {
  return DioConfig.createDioClient();
});

final driverMatchingServiceProvider = Provider<DriverMatchingService>((ref) {
  return DriverMatchingService(dio: ref.watch(dioProvider));
});

final tripServiceProvider = Provider<TripService>((ref) {
  return TripService(dio: ref.watch(dioProvider));
});
