# book_store 📚

A new Flutter project.


## structure project book store 📚

```lib/
  main.dart
  app.dart
  core/
    config/
      env.dart
      theme.dart
    network/
      api_client.dart
      endpoints.dart
      api_exception.dart
    storage/
      token_storage.dart
  features/
    auth/
      data/
        auth_api.dart
        auth_repository.dart
        auth_models.dart
      presentation/
        pages/
          login_page.dart
          otp_page.dart
          forgot_password_email_page.dart
          forgot_password_otp_page.dart
          register_page.dart
          reset_password_page.dart
          splash_page.dart
        widgets/
          auth_textfield.dart
      state/
        auth_provider.dart
    products/
      data/
        product_api.dart
        product_repository.dart
        product_models.dart
      presentation/
        pages/
          product_list_page.dart
          product_detail_page.dart
        widgets/
          product_card.dart
      state/
        product_provider.dart
    profile/
      presentation/
        pages/
          profile_page.dart
          edit_profile_page.dart
  shared/
    widgets/
      app_button.dart
      app_text.dart
      loading_view.dart

test/
  auth_provider_test.dart
