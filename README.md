# BookStore (Flutter)

Flutter mobile app for a bookstore feature module (auth, products, categories, wishlist, cart, orders, profile, payment QR flow).

## Requirements

- Flutter SDK (compatible with Dart `^3.10.3`)
- Android Studio or VS Code
- Android emulator / physical device (or other Flutter-supported platform)

## Project Setup

1. Clone the project
2. Open the project root (the folder that contains `pubspec.yaml`)
3. Install dependencies:

```bash
flutter pub get
```

## Run the Project

Default run (uses the default API base URL from `lib/core/config/env.dart`):

```bash
flutter run
```

Run with custom API base URL (recommended for local/staging backend):

```bash
flutter run --dart-define=API_BASE_URL=https://your-api-domain.com/api
```

## API Base URL Configuration

The app reads API base URL from:

- `lib/core/config/env.dart`

It uses:

- `API_BASE_URL` via `--dart-define`
- fallback default:
  - `https://bookstoreapi.sainnovationresearchlab.com/api`

## Useful Commands

Get dependencies:

```bash
flutter pub get
```

Clean project:

```bash
flutter clean
```

Run on a specific device:

```bash
flutter devices
flutter run -d <device_id>
```

Build APK (release):

```bash
flutter build apk --release
```

## Main Features (Current)

- Authentication (login/register/OTP/forgot password/reset password)
- Profile, edit profile, account settings (change email/password)
- Product list, category list, product detail
- Wishlist (local persistence)
- Cart (local persistence)
- Orders (user order history)
- QR payment flow (checkout + verify)

## Notes

- The app uses `ChangeNotifier`-based state management (custom provider classes).
- Some features depend on backend API availability and valid routes.
- If you add a new package and get plugin/channel errors, stop the app and run:

```bash
flutter clean
flutter pub get
flutter run
```
