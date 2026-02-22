import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'payment_models.dart';

class PaymentApi {
  const PaymentApi(this._client);

  final ApiClient _client;

  Future<CheckoutPaymentSession> checkoutOrder({
    required String currency,
    required List<CheckoutOrderItem> items,
  }) async {
    final response = await _client.post(
      Endpoints.checkoutOrder,
      authRequired: true,
      body: <String, dynamic>{
        'currency': currency,
        'items': items.map((e) => e.toJson()).toList(growable: false),
      },
    );
    return CheckoutPaymentSession.fromApi(response);
  }

  Future<String> verifyPayment({
    required String orderUuid,
    required String md5,
  }) async {
    final response = await _client.post(
      Endpoints.verifyPayment,
      authRequired: true,
      body: <String, dynamic>{
        'order_uuid': orderUuid,
        'md5': md5,
      },
    );
    final message = response['message'];
    return message is String && message.trim().isNotEmpty
        ? message.trim()
        : 'Payment verified successfully.';
  }
}
