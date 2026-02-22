import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'order_models.dart';

class OrderApi {
  const OrderApi(this._client);

  final ApiClient _client;

  Future<OrdersListResponse> getOrders({
    int? perPage,
    int? page,
    String? status,
    String? paymentStatus,
    String? search,
  }) async {
    final response = await _client.get(
      Endpoints.meOrders,
      authRequired: true,
      query: <String, dynamic>{
        if (perPage != null) 'per_page': perPage,
        if (page != null) 'page': page,
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (paymentStatus != null && paymentStatus.trim().isNotEmpty)
          'payment_status': paymentStatus.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return OrdersListResponse.fromApi(response);
  }

  Future<OrderModel> getOrderDetail(String uuid) async {
    final response = await _client.get(
      Endpoints.meOrderByUuid(uuid),
      authRequired: true,
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return OrderModel.fromJson(data);
    }
    if (data is Map) {
      return OrderModel.fromJson(Map<String, dynamic>.from(data));
    }
    return const OrderModel(
      id: 0,
      uuid: '',
      orderNo: '',
      status: '',
      paymentStatus: '',
      totalAmount: 0,
      createdAt: null,
      items: <OrderItemSummary>[],
    );
  }
}
