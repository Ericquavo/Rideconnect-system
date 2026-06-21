import 'package:flutter_test/flutter_test.dart';
import 'package:rideconnect_app/features/transport_order/domain/models/transport_order_model.dart';
import 'package:rideconnect_app/features/transport_order/presentation/controllers/transport_order_controller.dart';

void main() {
  group('TransportOrder Lifecycle Transitions', () {
    test('Initial creation sets status to searching', () async {
      final controller = TransportOrderController();
      
      final initialOrder = TransportOrder(
        id: '',
        status: 'created',
        transportType: 'MOTORCYCLE',
        pickup: Location(latitude: 0, longitude: 0),
        dropoff: Location(latitude: 1, longitude: 1),
        fare: 10.0,
      );

      await controller.createOrder(initialOrder);
      
      expect(controller.state.activeOrder, isNotNull);
      expect(controller.state.activeOrder!.status, 'searching');
      expect(controller.state.isLoading, isFalse);
    });

    test('Start order transitions status to active', () async {
      final controller = TransportOrderController();
      
      final initialOrder = TransportOrder(
        id: '',
        status: 'created',
        transportType: 'MOTORCYCLE',
        pickup: Location(latitude: 0, longitude: 0),
        dropoff: Location(latitude: 1, longitude: 1),
        fare: 10.0,
      );

      await controller.createOrder(initialOrder);
      final orderId = controller.state.activeOrder!.id;
      
      await controller.startOrder(orderId);
      
      expect(controller.state.activeOrder!.status, 'active');
    });

    test('Complete order transitions status to completed', () async {
      final controller = TransportOrderController();
      
      final initialOrder = TransportOrder(
        id: '',
        status: 'created',
        transportType: 'MOTORCYCLE',
        pickup: Location(latitude: 0, longitude: 0),
        dropoff: Location(latitude: 1, longitude: 1),
        fare: 10.0,
      );

      await controller.createOrder(initialOrder);
      final orderId = controller.state.activeOrder!.id;
      
      await controller.completeOrder(orderId);
      
      expect(controller.state.activeOrder!.status, 'completed');
    });
  });
}
