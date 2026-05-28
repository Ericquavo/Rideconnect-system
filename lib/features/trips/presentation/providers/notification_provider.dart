import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/fcm_service.dart';

final notificationRegistrationProvider =
    AsyncNotifierProvider<NotificationRegistrationNotifier, String?>(
      NotificationRegistrationNotifier.new,
    );

class NotificationRegistrationNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    return FcmService.instance.currentToken();
  }

  Future<void> register() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => FcmService.instance.registerDevice());
  }

  Future<void> unregister() async {
    final token = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (token != null && token.isNotEmpty) {
        await FcmService.instance.unregisterDevice(token);
      }
      return null;
    });
  }
}
