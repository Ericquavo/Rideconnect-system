import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/transport_order_model.dart';
import '../../../core/network/api_endpoints.dart';

// Basic state
class TransportOrderState {
  final TransportOrder? activeOrder;
  final bool isLoading;
  final String? error;

  TransportOrderState({
    this.activeOrder,
    this.isLoading = false,
    this.error,
  });

  TransportOrderState copyWith({
    TransportOrder? activeOrder,
    bool? isLoading,
    String? error,
  }) {
    return TransportOrderState(
      activeOrder: activeOrder ?? this.activeOrder,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class TransportOrderController extends StateNotifier<TransportOrderState> {
  TransportOrderController() : super(TransportOrderState());

  Future<void> createOrder(TransportOrder order) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Simulate API call to POST /transport-orders
      await Future.delayed(const Duration(seconds: 1));
      
      final createdOrder = order.copyWith(
        id: 'to_${DateTime.now().millisecondsSinceEpoch}',
        status: 'searching',
      );
      
      state = state.copyWith(
        activeOrder: createdOrder,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> getOrder(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Simulate API call to GET /transport-orders/{id}
      await Future.delayed(const Duration(seconds: 1));
      
      state = state.copyWith(
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> startOrder(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Simulate API call to POST /transport-orders/{id}/start
      await Future.delayed(const Duration(seconds: 1));
      
      if (state.activeOrder != null) {
        state = state.copyWith(
          activeOrder: state.activeOrder!.copyWith(status: 'active'),
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> completeOrder(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Simulate API call to POST /transport-orders/{id}/complete
      await Future.delayed(const Duration(seconds: 1));
      
      if (state.activeOrder != null) {
        state = state.copyWith(
          activeOrder: state.activeOrder!.copyWith(status: 'completed'),
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final transportOrderControllerProvider = StateNotifierProvider<TransportOrderController, TransportOrderState>((ref) {
  return TransportOrderController();
});
