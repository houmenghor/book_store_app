class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bookstoreapi.sainnovationresearchlab.com/api',
  );
}
