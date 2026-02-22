class Endpoints {
  const Endpoints._();

  static const String login = '/v1/auth/login';
  static const String register = '/v1/auth/register';
  static const String forgotPassword = '/v1/auth/forgot-password';
  static const String resetPassword = '/v1/auth/reset-password';
  static const String otpSend = '/v1/auth/otp/send';
  static const String otpResend = '/v1/auth/otp/resend';
  static const String otpVerify = '/v1/auth/otp/verify';
  static const String updateProfile = '/v1/me';
  static const String changeEmail = '/v1/me/change-email';
  static const String changePassword = '/v1/me/change-password';
  static const String logout = '/v1/auth/logout';
  static const String checkoutOrder = '/v1/order/checkout';
  static const String verifyPayment = '/v1/payments/verify';
  static const String orders = '/v1/orders';
  static const String meOrders = '/v1/me/orders';

  static const String products = '/v1/products';
  static const String bestSellerProducts = '/v1/products/best-sellers';
  static const String popularProducts = '/v1/products/popular';
  static const String categories = '/v1/categories';

  static String productByUuid(String uuid) => '/v1/products/$uuid';
  static String meOrderByUuid(String uuid) => '/v1/me/orders/$uuid';
}
